import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/access_control.dart';
import '../config/api.dart';
import 'comm_notifier.dart';
import 'offline_sync.dart';
import 'offline_store.dart';

/// Flow (same as the web app):
///   login → pick project → POST /project/enter/{code} → project-scoped token
///   every module call sends `projectCode` + the project token.
class ApiService extends ChangeNotifier {
  ApiService._() {
    Outbox.instance.sender = (item) async {
      try {
        await _send(item.method, item.path, body: item.body, token: _projectToken ?? _loginToken);
      } on ApiException catch (e) {
        if (e.code == 0 || e.code == 408) throw const OfflineException();
        rethrow;
      }
    };
  }
  static final instance = ApiService._();

  static const _timeout = Duration(seconds: 30);

  String? _loginToken;   // from /auth/login (has the role claim)
  String? _projectToken; // from /project/enter (has project permissions)
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _project;

  Map<String, dynamic>? get currentUser => _user;
  Map<String, dynamic>? get currentProject => _project;
  String? get projectCode => _project?['projectCode']?.toString();
  String get userName => (_user?['username'] ?? 'User').toString();
  String get userRole => (_user?['role'] ?? Roles.user).toString();

  /// Logged-in user's profile photo, served through the API (needs [imageHeaders]).
  /// null when the user has no photo.
  String? get profilePhotoUrl {
    final id = _user?['id'];
    final stored = _user?['profilePicture'];
    if (id == null || stored == null || '$stored'.isEmpty) return null;
    return '${ApiConfig.baseUrl}${ApiConfig.userFile}/$id/profile?v=${Uri.encodeComponent('$stored')}';
  }

  /// Auth header for loading protected images (Image.network headers).
  Map<String, String> get imageHeaders =>
      {if ((_projectToken ?? _loginToken) != null) 'Authorization': 'Bearer ${_projectToken ?? _loginToken}'};

  /// Reload the user's profile info (photo) from /auth/me. Never throws.
  Future<void> refreshMe() async {
    if (_loginToken == null || _user == null) return;
    try {
      final data = await _send('GET', ApiConfig.me, token: _loginToken);
      final me = data is List && data.isNotEmpty ? data.first : data;
      if (me is! Map) return;
      final pic = me['profilePicture'];
      if (pic == _user!['profilePicture']) return;
      _user = {..._user!, 'profilePicture': pic};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(_user));
      notifyListeners();
    } catch (_) {
      // keep the initials avatar
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    _loginToken = prefs.getString('token');
    _projectToken = prefs.getString('projectToken');
    final u = prefs.getString('user');
    final p = prefs.getString('project');
    final perms = prefs.getString('permissions');
    if (u != null) _user = jsonDecode(u);
    if (p != null) _project = jsonDecode(p);
    if (perms != null) AccessControl.serverPermissions = Map<String, dynamic>.from(jsonDecode(perms));
    AccessControl.role = userRole;
    unawaited(refreshMe());
    return _loginToken != null;
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
          headers: _headers(null),
          body: jsonEncode({'loginUserName': username, 'password': password}),
        )
        .timeout(_timeout);
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('Server error (${res.statusCode}). Please try again later.', res.statusCode);
    }
    final list = body['data'];
    final user = list is List && list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
    if (res.statusCode != 200 || user?['token'] == null) {
      return {'message': body['message'] ?? 'Invalid credentials'};
    }
    _loginToken = user!['token'];
    _projectToken = null;
    _project = null;
    _user = Map<String, dynamic>.from(user)..remove('token');
    AccessControl.role = userRole;
    AccessControl.serverPermissions = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _loginToken!);
    await prefs.setString('user', jsonEncode(_user));
    await prefs.remove('projectToken');
    await prefs.remove('project');
    await prefs.remove('permissions');
    notifyListeners();
    unawaited(refreshMe());
    return {'token': _loginToken, 'user': _user};
  }

  Future<void> logout() async {
    // stop notifications first — unregistering the push token needs the login token
    await CommNotifier.instance.stop();
    await CommNotifier.clearSeen();
    _loginToken = null;
    _projectToken = null;
    _user = null;
    _project = null;
    AccessControl.serverPermissions = {};
    AccessControl.role = '';
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['token', 'projectToken', 'user', 'project', 'permissions', OfflineSync.lastSyncKey]) {
      await prefs.remove(k);
    }
    await OfflineStore.instance.clear();
    await Outbox.instance.clear();
    notifyListeners();
  }

  // ── Projects ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> projects() async {
    final data = await _cached('GET ${ApiConfig.projectList}',
        () => _send('GET', ApiConfig.projectList, token: _loginToken, allow404: true));
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> enterProject(Map<String, dynamic> project) async {
    final code = project['projectCode'];
    final data = await _send('POST', '${ApiConfig.enterProject}/$code',
        token: _loginToken, body: {'projectCode': code});
    final first = data is List && data.isNotEmpty ? data.first : data;
    final token = first is Map ? first['token'] : null;
    if (token == null) throw ApiException('Could not open project $code', 400);
    _projectToken = token;
    _project = project;
    final perms = first['permissions'];
    AccessControl.serverPermissions = perms is Map ? Map<String, dynamic>.from(perms) : {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('projectToken', token);
    await prefs.setString('project', jsonEncode(project));
    await prefs.setString('permissions', jsonEncode(AccessControl.serverPermissions));
    notifyListeners();
  }

  // ── Generic GET used by every module ──────────────────────────────────────

  /// Saved copies are used when offline. [onCached] is told when the answer
  /// came from the saved copy (and how old it is).
  Future<dynamic> get(String path,
      {Map<String, String>? params, bool projectScoped = true, void Function(DateTime savedAt)? onCached}) {
    final q = <String, String>{...?params};
    if (projectScoped && projectCode != null) q['projectCode'] = projectCode!;
    // The backend answers "no records" with 404 + empty data, so treat it as empty.
    Future<dynamic> fetch() => _send('GET', path, params: q, token: _projectToken ?? _loginToken, allow404: true);
    if (!_cacheable(path)) return fetch();
    final keys = q.keys.toList()..sort();
    final key = 'GET $path?${[for (final k in keys) '$k=${q[k]}'].join('&')}';
    return _cached(key, fetch, onCached: onCached);
  }

  /// Live-only endpoints (call signalling, counters) are never saved.
  static bool _cacheable(String path) =>
      !path.contains('/calls') && !path.contains('/messages/new') && !path.contains('unread-count') &&
      !path.contains('/turn-credentials');

  /// Run [fetch]; save the answer. If the server can't be reached, return the saved copy.
  Future<dynamic> _cached(String key, Future<dynamic> Function() fetch,
      {void Function(DateTime savedAt)? onCached}) async {
    final userKey = 'u${_user?['id']}|$key';
    try {
      final data = await fetch();
      unawaited(OfflineStore.instance.put(userKey, data));
      return data;
    } on ApiException catch (e) {
      if (e.code != 0 && e.code != 408) rethrow;
      final saved = await OfflineStore.instance.get(userKey);
      if (saved == null) {
        throw ApiException('You are offline and this page is not saved on the phone yet. '
            'Open it once with internet, or use "Sync for offline" in Profile.', e.code);
      }
      onCached?.call(saved.savedAt);
      return saved.data;
    }
  }

  /// Generic POST (JSON) with the project token if there is one.
  /// With [queueOffline], a POST made without internet is saved and sent
  /// automatically later; it then returns `{'queued': true}`.
  Future<dynamic> post(String path, {Object? body, bool queueOffline = false, String label = '', String? tag}) async {
    try {
      return await _send('POST', path, body: body, token: _projectToken ?? _loginToken);
    } on ApiException catch (e) {
      if (!queueOffline || (e.code != 0 && e.code != 408)) rethrow;
      await Outbox.instance.add('POST', path, Map<String, dynamic>.from(body as Map? ?? {}), label: label, tag: tag);
      return {'queued': true};
    }
  }

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body, token: _projectToken ?? _loginToken);

  /// multipart/form-data POST (photo uploads). [files] are (field name, file path).
  /// Throws [ApiException] with code 0 / 408 when the server can't be reached.
  Future<dynamic> uploadFiles(String path,
      {Map<String, String> fields = const {}, List<(String, String)> files = const [],
      Duration timeout = const Duration(minutes: 2)}) async {
    final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'));
    final token = _projectToken ?? _loginToken;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields.addAll(fields);
    for (final (field, filePath) in files) {
      req.files.add(await http.MultipartFile.fromPath(field, filePath));
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(timeout));
    } on TimeoutException {
      NetworkStatus.instance.markOffline();
      throw ApiException('Upload is taking too long. Check your connection.', 408);
    } catch (_) {
      NetworkStatus.instance.markOffline();
      throw ApiException('Could not reach the server. Check your internet.', 0);
    }
    NetworkStatus.instance.markOnline();
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }
    final msg = decoded is Map ? (decoded['message'] ?? decoded['msg'])?.toString() : null;
    if (res.statusCode == 401 || res.statusCode == 422) throw ApiException('Session expired. Please log in again.', 401);
    if (res.statusCode >= 400) throw ApiException(msg ?? 'Upload failed (${res.statusCode})', res.statusCode);
    return decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
  }

  /// Generic PATCH / DELETE (JSON), used by group management.
  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body, token: _projectToken ?? _loginToken);
  Future<dynamic> delete(String path) => _send('DELETE', path, token: _projectToken ?? _loginToken);

  /// Logged-in user's id (null before login).
  int? get userId {
    final id = _user?['id'];
    return id is int ? id : int.tryParse('$id');
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? params, Object? body, String? token, bool allow404 = false}) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (params != null && params.isNotEmpty) uri = uri.replace(queryParameters: params);
    final http.Response res;
    try {
      final h = _headers(token);
      final b = jsonEncode(body ?? {});
      res = await switch (method) {
        'POST' => http.post(uri, headers: h, body: b),
        'PATCH' => http.patch(uri, headers: h, body: b),
        'PUT' => http.put(uri, headers: h, body: b),
        'DELETE' => http.delete(uri, headers: h),
        _ => http.get(uri, headers: h),
      }
          .timeout(_timeout);
    } on TimeoutException {
      NetworkStatus.instance.markOffline();
      throw ApiException('Server is taking too long. Check your connection.', 408);
    } catch (_) {
      NetworkStatus.instance.markOffline();
      throw ApiException('Could not reach the server. Check your internet.', 0);
    }
    NetworkStatus.instance.markOnline();
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }
    final msg = decoded is Map ? (decoded['message'] ?? decoded['msg'])?.toString() : null;
    if (res.statusCode == 401 || res.statusCode == 422) {
      throw ApiException('Session expired. Please log in again.', 401);
    }
    if (res.statusCode == 404 && allow404) return <dynamic>[];
    if (res.statusCode == 403) throw ApiException(msg ?? 'You don\'t have access to this module.', 403);
    if (res.statusCode >= 400) throw ApiException(msg ?? 'Request failed (${res.statusCode})', res.statusCode);
    if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
    return decoded;
  }
}

class ApiException implements Exception {
  final String message;
  final int code;
  ApiException(this.message, this.code);
  @override
  String toString() => message;
}

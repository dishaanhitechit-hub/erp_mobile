import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved server response.
class CachedEntry {
  final DateTime savedAt;
  final dynamic data;
  CachedEntry(this.savedAt, this.data);
}

/// On-device copy of every GET response, so screens open without internet.
/// One small JSON file per request (path + query), under the app's private
/// support folder. Cleared on logout.
class OfflineStore {
  OfflineStore._();
  static final instance = OfflineStore._();

  Directory? _dir;
  final _mem = <String, CachedEntry>{}; // recently used, avoids disk reads

  Future<Directory?> _folder() async {
    if (_dir != null) return _dir;
    if (kIsWeb) return null;
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}/offline');
      await _dir!.create(recursive: true);
    } catch (_) {
      _dir = null;
    }
    return _dir;
  }

  /// FNV-1a hash → safe, short file name.
  static String _name(String key) {
    var h = 0xcbf29ce484222325;
    for (final c in utf8.encode(key)) {
      h ^= c;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${h.toRadixString(16)}.json';
  }

  Future<void> put(String key, dynamic data) async {
    final entry = CachedEntry(DateTime.now(), data);
    _mem[key] = entry;
    if (_mem.length > 200) _mem.remove(_mem.keys.first);
    final dir = await _folder();
    if (dir == null) return;
    try {
      final tmp = File('${dir.path}/${_name(key)}.tmp');
      await tmp.writeAsString(jsonEncode({'k': key, 't': entry.savedAt.millisecondsSinceEpoch, 'd': data}), flush: true);
      await tmp.rename('${dir.path}/${_name(key)}');
    } catch (_) {}
  }

  Future<CachedEntry?> get(String key) async {
    final m = _mem[key];
    if (m != null) return m;
    final dir = await _folder();
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/${_name(key)}');
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map || j['k'] != key) return null;
      final e = CachedEntry(DateTime.fromMillisecondsSinceEpoch(j['t'] as int), j['d']);
      _mem[key] = e;
      return e;
    } catch (_) {
      return null;
    }
  }

  /// Number of saved responses and their size on disk.
  Future<(int, int)> stats() async {
    final dir = await _folder();
    if (dir == null) return (0, 0);
    var n = 0, bytes = 0;
    try {
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.json')) {
          n++;
          bytes += await f.length();
        }
      }
    } catch (_) {}
    return (n, bytes);
  }

  Future<void> clear() async {
    _mem.clear();
    final dir = await _folder();
    try {
      if (dir != null && await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    _dir = null;
  }
}

/// Something the user did offline (chat message, ping) waiting to be sent.
class OutboxItem {
  final String id, method, path, label;
  final Map<String, dynamic> body;

  /// Groups items for a screen, e.g. `chat:12` → pending bubbles in that chat.
  final String? tag;
  final DateTime createdAt;

  OutboxItem({
    required this.id,
    required this.method,
    required this.path,
    required this.label,
    required this.body,
    this.tag,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'method': method, 'path': path, 'label': label, 'body': body, 'tag': tag,
        't': createdAt.millisecondsSinceEpoch,
      };

  static OutboxItem fromJson(Map j) => OutboxItem(
        id: '${j['id']}',
        method: '${j['method']}',
        path: '${j['path']}',
        label: '${j['label'] ?? ''}',
        body: Map<String, dynamic>.from(j['body'] as Map? ?? {}),
        tag: j['tag'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['t'] as num?)?.toInt() ?? 0),
      );
}

/// Queue of writes made offline. Sent in order as soon as the phone is back
/// online (see [NetworkStatus]).
class Outbox extends ChangeNotifier {
  Outbox._();
  static final instance = Outbox._();
  static const _key = 'outbox_v1';

  final List<OutboxItem> items = [];
  bool _loaded = false;
  bool flushing = false;

  /// Sends one item; returns normally on success. Set by ApiService.
  Future<void> Function(OutboxItem item)? sender;

  /// Called after items were delivered (screens reload).
  final delivered = ValueNotifier<int>(0);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) items.addAll((jsonDecode(raw) as List).whereType<Map>().map(OutboxItem.fromJson));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final i in items) i.toJson()]));
  }

  Future<OutboxItem> add(String method, String path, Map<String, dynamic> body, {required String label, String? tag}) async {
    await load();
    final item = OutboxItem(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      method: method, path: path, body: body, label: label, tag: tag, createdAt: DateTime.now(),
    );
    items.add(item);
    await _save();
    notifyListeners();
    return item;
  }

  List<OutboxItem> withTag(String tag) => items.where((i) => i.tag == tag).toList();

  /// Send everything queued, oldest first. Stops at the first network error
  /// (still offline); drops items the server rejects (e.g. chat deleted).
  Future<void> flush() async {
    await load();
    if (flushing || items.isEmpty || sender == null) return;
    flushing = true;
    notifyListeners();
    var sent = 0;
    try {
      while (items.isNotEmpty) {
        final item = items.first;
        try {
          await sender!(item);
        } on OfflineException {
          break;
        } catch (_) {
          // rejected by the server — don't retry forever
        }
        items.removeAt(0);
        sent++;
        await _save();
        notifyListeners();
      }
    } finally {
      flushing = false;
      notifyListeners();
      if (sent > 0) delivered.value++;
    }
  }

  Future<void> clear() async {
    items.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}

/// Thrown by the sender when the server can't be reached.
class OfflineException implements Exception {
  const OfflineException();
}

/// Online / offline state for the banner and auto-refresh.
/// Starts from the phone's connectivity and is corrected by real requests
/// (a request that fails with "no connection" flips it offline; any success flips it online).
class NetworkStatus extends ValueNotifier<bool> {
  NetworkStatus._() : super(true);
  static final instance = NetworkStatus._();

  StreamSubscription? _sub;
  bool _hasNetwork = true;

  /// Bumped every time we come back online — screens listen and reload.
  final backOnline = ValueNotifier<int>(0);

  bool get online => value;

  Future<void> start() async {
    if (_sub != null || kIsWeb) return;
    try {
      final c = Connectivity();
      _onConnectivity(await c.checkConnectivity());
      _sub = c.onConnectivityChanged.listen(_onConnectivity);
    } catch (_) {}
  }

  void _onConnectivity(List<ConnectivityResult> r) {
    _hasNetwork = r.any((x) => x != ConnectivityResult.none);
    if (!_hasNetwork) {
      markOffline();
    } else if (!value) {
      // Network is back; confirm with a real request (the outbox flush does one).
      markOnline();
    }
  }

  Future<bool> isWifi() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  void markOffline() {
    if (value) value = false;
  }

  void markOnline() {
    if (value) return;
    value = true;
    backOnline.value++;
    unawaited(Outbox.instance.flush());
  }
}

/// "just now", "5 min ago", "3 h ago", "2 days ago".
String savedAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';

class ApiService {
  ApiService._();
  static final instance = ApiService._();

  String? _token;
  Map<String, dynamic>? _user;

  Map<String, dynamic>? get currentUser => _user;

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) _user = jsonDecode(userJson);
    return _token != null;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      _token = data['token'] ?? data['access_token'];
      _user = data['user'] ?? data['data'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      if (_user != null) await prefs.setString('user', jsonEncode(_user));
    }
    return data;
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  Future<dynamic> get(String path, {Map<String, String>? params}) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (params != null) uri = uri.replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 401) throw ApiException('Session expired', 401);
    if (res.statusCode >= 400) throw ApiException('Request failed', res.statusCode);
    final body = jsonDecode(res.body);
    return body['data'] ?? body;
  }
}

class ApiException implements Exception {
  final String message;
  final int code;
  ApiException(this.message, this.code);
  @override String toString() => message;
}

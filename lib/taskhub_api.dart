import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String _configuredApiUrl = String.fromEnvironment('TASKHUB_API_URL');

bool get pagesDemoWithoutApi =>
    kIsWeb && Uri.base.host.endsWith('.github.io') && _configuredApiUrl.isEmpty;

String get taskHubApiUrl => _configuredApiUrl.isNotEmpty
    ? _configuredApiUrl.replaceFirst(RegExp(r'/$'), '')
    : kIsWeb
    ? Uri.base.origin
    : 'http://10.0.2.2:8000';

class ApiError implements Exception {
  const ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

class TaskHubApi extends ChangeNotifier {
  static final shared = TaskHubApi();
  int? userId;
  int? deletedAccount;
  static const _storage = FlutterSecureStorage();
  String? token;

  Future<void> restore() async {
    final session = await _storage.read(key: 'taskhub_session');
    if (session != null) {
      final saved = jsonDecode(session) as Map<String, dynamic>;
      token = saved['token'] as String;
      userId = saved['userId'] as int;
    } else {
      token = await _storage.read(key: 'taskhub_token');
      if (token != null) {
        final me = await call('GET', '/api/v1/auth/me');
        userId = me['id'] as int;
      }
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> call(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    if (kReleaseMode && !kIsWeb && !taskHubApiUrl.startsWith('https://')) {
      throw const ApiError('This release requires a configured HTTPS server.');
    }
    final requestToken = token;
    final request = http.Request(method, Uri.parse('$taskHubApiUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (data != null) request.body = jsonEncode(data);
    final streamed = await request.send().timeout(const Duration(seconds: 12));
    final body = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 12));
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError(
        'Server returned an invalid response (${body.statusCode})',
      );
    }
    if (body.statusCode >= 400) {
      if (body.statusCode == 401 &&
          token == requestToken &&
          decoded['error'] == 'unauthorized') {
        token = null;
        userId = null;
        notifyListeners();
        await _storage.delete(key: 'taskhub_token');
        await _storage.delete(key: 'taskhub_session');
      }
      throw ApiError(
        '${decoded['error'] ?? 'Request failed'} (${body.statusCode})',
      );
    }
    return decoded;
  }

  Future<void> authenticate(
    String email,
    String password,
    bool register,
  ) async {
    final result = await call(
      'POST',
      '/api/v1/auth/${register ? 'register' : 'login'}',
      {'email': email, 'password': password},
    );
    token = result['token'] as String;
    userId = (result['user'] as Map)['id'] as int;
    await _storage.write(
      key: 'taskhub_session',
      value: jsonEncode({'token': token, 'userId': userId}),
    );
    await _storage.delete(key: 'taskhub_token');
    notifyListeners();
  }

  Future<void> clearSession({bool deleted = false}) async {
    if (deleted) deletedAccount = userId;
    token = null;
    userId = null;
    await _storage.delete(key: 'taskhub_token');
    await _storage.delete(key: 'taskhub_session');
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await call('POST', '/api/v1/auth/logout');
    } finally {
      token = null;
      userId = null;
      notifyListeners();
      await _storage.delete(key: 'taskhub_token');
      await _storage.delete(key: 'taskhub_session');
    }
  }
}

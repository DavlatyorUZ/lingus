import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiFailure implements Exception {
  final String message;
  final int status;
  const ApiFailure(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

typedef ApiTransport = Future<Map<String, dynamic>> Function(
  String path,
  String method,
  Map<String, dynamic>? body,
);

class AccountApi extends ChangeNotifier {
  AccountApi({this.transport});
  final ApiTransport? transport;
  Future<void> _authTail = Future<void>.value();
  Future<T> _sessionRequest<T>(Future<T> Function() action) {
    final result = _authTail.then((_) => action());
    _authTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  static const origin = String.fromEnvironment(
    'LINGOY_ORIGIN',
    defaultValue: 'https://lingoy.uz',
  );
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final _storage = const FlutterSecureStorage();
  final Map<String, String> _cookies = {};
  Map<String, dynamic>? user;
  String? _access, _csrf;
  Future<void>? _refreshing;
  Future<void> Function(String?)? onAccount;
  bool get signedIn => user != null;
  Future<Map<String, dynamic>> _send(
    String path,
    String method,
    Map<String, dynamic>? body,
  ) {
    if (path.startsWith('/auth/') && method != 'GET') {
      return _sessionRequest(() => _exchange(path, method, body));
    }
    return _exchange(path, method, body);
  }

  Future<Map<String, dynamic>> _exchange(
    String path,
    String method,
    Map<String, dynamic>? body,
  ) async {
    final custom = transport;
    if (custom != null) return custom(path, method, body);
    try {
      final base = Uri.parse(origin);
      if (base.scheme != 'https' ||
          base.userInfo.isNotEmpty ||
          base.hasQuery ||
          base.hasFragment) {
        throw const ApiFailure('HTTPS server manzili kerak.');
      }
      final req = await _http
          .openUrl(method, base.resolve('/api/v1$path'))
          .timeout(const Duration(seconds: 10));
      req.followRedirects = false;
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Accept', 'application/json');
      if (_access != null) req.headers.set('Authorization', 'Bearer $_access');
      if (_csrf != null) req.headers.set('X-CSRF-Token', _csrf!);
      if (_cookies.isNotEmpty) {
        req.headers.set(
          'Cookie',
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
        );
      }
      if (body != null) req.write(jsonEncode(body));
      final r = await req.close().timeout(const Duration(seconds: 65));
      for (final c in r.cookies) {
        _cookies[c.name] = c.value;
      }
      final bytes = <int>[];
      await for (final chunk in r.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 4 * 1024 * 1024) {
          throw const ApiFailure('Server javobi juda katta.');
        }
      }
      final data = (jsonDecode(utf8.decode(bytes)) as Map)
          .cast<String, dynamic>();
      if (r.statusCode >= 400) {
        throw ApiFailure(
          data['message'] as String? ?? 'So‘rov bajarilmadi.',
          r.statusCode,
        );
      }
      return data;
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(
        'Internetga ulanishni tekshiring va qayta urinib ko‘ring.',
      );
    }
  }

  Future<void> csrf() async {
    _csrf = (await _send('/auth/csrf', 'GET', null))['csrfToken'] as String;
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    final expected = user?['id'];
    await csrf();
    final result = await _send('/auth/refresh', 'POST', {});
    if (expected != null && result['user']?['id'] != expected) {
      throw const ApiFailure('Akkaunt o‘zgardi. Qayta kiring.', 401);
    }
    await accept(result);
  }

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final expected = user?['id'];
    void checkAccount() {
      if (expected != null &&
          !path.startsWith('/auth/') &&
          user?['id'] != expected) {
        throw const ApiFailure(
          'Akkaunt o‘zgardi. So‘rovni qayta boshlang.',
          401,
        );
      }
    }

    if (method != 'GET' && _csrf == null) await csrf();
    checkAccount();
    try {
      return await _send(path, method, body);
    } on ApiFailure catch (e) {
      checkAccount();
      if (e.status == 401 && signedIn && !path.startsWith('/auth/')) {
        await refresh();
        checkAccount();
        return _send(path, method, body);
      }
      if (e.status == 403 && method != 'GET') {
        await csrf();
        checkAccount();
        return _send(path, method, body);
      }
      rethrow;
    }
  }

  Future<void> accept(Map<String, dynamic>? data) async {
    final next = (data?['user'] as Map?)?.cast<String, dynamic>();
    if (user?['id'] != next?['id']) {
      await onAccount?.call(next?['id'] as String?);
    }
    user = next;
    _access = data?['accessToken'] as String?;
    if (data == null) {
      _cookies.clear();
      _csrf = null;
      await _storage.delete(key: 'lingoy-session');
    } else {
      await _storage.write(
        key: 'lingoy-session',
        value: jsonEncode({'user': user, 'cookies': _cookies}),
      );
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    final s = await _storage.read(key: 'lingoy-session');
    if (s != null) {
      final p = jsonDecode(s) as Map;
      user = (p['user'] as Map?)?.cast<String, dynamic>();
      _cookies.addAll((p['cookies'] as Map).cast<String, String>());
      await onAccount?.call(user?['id'] as String?);
      try {
        await refresh();
      } on ApiFailure catch (e) {
        if (e.status == 401) await accept(null);
      }
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async => accept(
    await request(
      '/auth/login',
      method: 'POST',
      body: {'email': email, 'password': password},
    ),
  );
  Future<void> verify(String email, String code) async => accept(
    await request(
      '/auth/verify',
      method: 'POST',
      body: {'email': email, 'code': code},
    ),
  );
  Future<void> logout() async {
    await request('/auth/logout', method: 'POST', body: {});
    await accept(null);
  }

  String verifier() => base64Url
      .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  Future<Map<String, dynamic>> googleStart(String v) => request(
    '/auth/mobile/start',
    method: 'POST',
    body: {
      'challenge': base64Url
          .encode(sha256.convert(utf8.encode(v)).bytes)
          .replaceAll('=', ''),
    },
  );
  Future<bool> googlePoll(String ticket, String v) async {
    final p = await request(
      '/auth/mobile/poll',
      method: 'POST',
      body: {'ticket': ticket, 'verifier': v},
    );
    if (p['pending'] == true) return false;
    await accept(p);
    return true;
  }
}

final accountApi = AccountApi();

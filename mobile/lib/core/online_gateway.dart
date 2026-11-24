import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Disabled in ordinary builds. No key, paid provider or default server URL.
class OnlineConfig {
  final Uri? base;
  final bool enabled;
  const OnlineConfig._(this.base, this.enabled);
  factory OnlineConfig({String url = '', bool enabled = false}) {
    if (url.isEmpty) return const OnlineConfig._(null, false);
    final base = Uri.tryParse(url.endsWith('/') ? url : '$url/');
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw ArgumentError('Onlayn xizmat uchun to‘g‘ri HTTPS manzil kerak.');
    }
    return OnlineConfig._(base, enabled);
  }
  factory OnlineConfig.environment() => OnlineConfig(
    url: const String.fromEnvironment('LINGOY_API_BASE_URL'),
    enabled: const bool.fromEnvironment('LINGOY_ONLINE_ENABLED'),
  );
  bool get available => enabled && base != null;
}

class GatewayFailure implements Exception {
  final String code, message;
  const GatewayFailure(this.code, this.message);
  @override
  String toString() => message;
}

class GatewayResponse {
  final int status;
  final Map<String, dynamic> data;
  const GatewayResponse(this.status, this.data);
}

abstract interface class GatewayTransport {
  Future<GatewayResponse> send(Uri url, {Map<String, Object?>? body});
  void close();
}

class HttpGatewayTransport implements GatewayTransport {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);
  @override
  Future<GatewayResponse> send(Uri url, {Map<String, Object?>? body}) async {
    try {
      final request =
          await (body == null ? _client.getUrl(url) : _client.postUrl(url))
              .timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.isRedirect) {
        request.abort();
        throw const GatewayFailure('redirect', 'Server manzili o‘zgargan.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final bytes in response.timeout(const Duration(seconds: 12))) {
        if (builder.length + bytes.length > 1024 * 1024) {
          throw const GatewayFailure(
            'response_size',
            'Server javobi juda katta.',
          );
        }
        builder.add(bytes);
      }
      final data = jsonDecode(utf8.decode(builder.takeBytes()));
      if (data is! Map<String, dynamic>) {
        throw const GatewayFailure('protocol', 'Server javobi noto‘g‘ri.');
      }
      return GatewayResponse(response.statusCode, data);
    } on GatewayFailure {
      rethrow;
    } catch (_) {
      throw const GatewayFailure(
        'unavailable',
        'Onlayn xizmatga ulanib bo‘lmadi.',
      );
    }
  }

  @override
  void close() => _client.close(force: true);
}

class OnlineGateway {
  final OnlineConfig config;
  final GatewayTransport transport;
  OnlineGateway(this.config, {GatewayTransport? transport})
    : transport = transport ?? HttpGatewayTransport();
  void _requireConfiguration() {
    if (!config.available) {
      throw const GatewayFailure(
        'not_configured',
        'Onlayn xizmat hali ulanmagan.',
      );
    }
  }

  Future<Map<String, bool>> capabilities() async {
    _requireConfiguration();
    final r = await transport.send(config.base!.resolve('v1/health'));
    if (r.status != 200 ||
        r.data['api_version'] != '1' ||
        r.data['capabilities'] is! Map) {
      throw const GatewayFailure('protocol', 'Server versiyasi mos kelmadi.');
    }
    final c = r.data['capabilities'] as Map;
    return {
      for (final key in ['translation', 'grammar', 'image_translation'])
        key: c[key] == true,
    };
  }

  Future<Map<String, dynamic>> textRequest(
    String feature,
    String text, {
    required bool consent,
  }) async {
    _requireConfiguration();
    if (!consent) {
      throw const GatewayFailure('consent', 'Matnni yuborishga rozilik kerak.');
    }
    if (!['translation', 'grammar'].contains(feature) ||
        text.trim().isEmpty ||
        text.length > 4000) {
      throw const GatewayFailure(
        'input',
        '1–4 000 belgidan iborat matn kerak.',
      );
    }
    final available = await capabilities();
    if (available[feature] != true) {
      throw const GatewayFailure(
        'feature_disabled',
        'Bu onlayn xizmat hali ishga tushirilmagan.',
      );
    }
    final r = await transport.send(
      config.base!.resolve(
        feature == 'grammar' ? 'v1/grammar' : 'v1/translate',
      ),
      body: {'text': text, 'source_language': 'en', 'target_language': 'uz'},
    );
    if (r.status != 200 || r.data['result'] is! Map) {
      throw const GatewayFailure('server', 'Server natijani qaytara olmadi.');
    }
    return (r.data['result'] as Map).cast<String, dynamic>();
  }

  void close() => transport.close();
}

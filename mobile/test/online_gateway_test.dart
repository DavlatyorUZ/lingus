import 'package:flutter_test/flutter_test.dart';
import 'package:lingoy/core/online_gateway.dart';

class FakeTransport implements GatewayTransport {
  final bool allow;
  final List<Uri> urls = [];
  final List<Map<String, Object?>?> bodies = [];
  FakeTransport({this.allow = false});
  @override
  Future<GatewayResponse> send(Uri url, {Map<String, Object?>? body}) async {
    urls.add(url);
    bodies.add(body);
    return url.path.endsWith('health')
        ? GatewayResponse(200, {
            'api_version': '1',
            'capabilities': {
              'translation': allow,
              'grammar': allow,
              'image_translation': false,
            },
          })
        : const GatewayResponse(503, {
            'error': {'code': 'feature_disabled'},
          });
  }

  @override
  void close() {}
}

void main() {
  test('Ordinary builds and missing consent never send traffic', () async {
    final t = FakeTransport();
    final off = OnlineGateway(OnlineConfig(), transport: t);
    await expectLater(off.capabilities(), throwsA(isA<GatewayFailure>()));
    expect(t.urls, isEmpty);
    final on = OnlineGateway(
      OnlineConfig(url: 'https://example.test/api', enabled: true),
      transport: t,
    );
    await expectLater(
      on.textRequest('translation', 'private text', consent: false),
      throwsA(isA<GatewayFailure>()),
    );
    expect(t.urls, isEmpty);
  });
  test(
    'A disabled capability only sends metadata health GET, never the text',
    () async {
      final t = FakeTransport();
      final g = OnlineGateway(
        OnlineConfig(url: 'https://example.test/api/', enabled: true),
        transport: t,
      );
      await expectLater(
        g.textRequest('grammar', 'private text', consent: true),
        throwsA(isA<GatewayFailure>()),
      );
      expect(t.urls.single.toString(), 'https://example.test/api/v1/health');
      expect(t.bodies.single, isNull);
    },
  );
  test('HTTPS and input boundaries are enforced before traffic', () async {
    for (final url in [
      'http://example.test',
      'https://user:secret@example.test',
      'https://example.test/?key=bad',
    ]) {
      expect(() => OnlineConfig(url: url, enabled: true), throwsArgumentError);
    }
    final t = FakeTransport();
    final g = OnlineGateway(
      OnlineConfig(url: 'https://example.test', enabled: true),
      transport: t,
    );
    await expectLater(
      g.textRequest('grammar', 'x' * 4001, consent: true),
      throwsA(isA<GatewayFailure>()),
    );
    expect(t.urls, isEmpty);
  });
  test(
    'Unavailable server results are never displayed as successful AI answers',
    () async {
      final t = FakeTransport(allow: true);
      final g = OnlineGateway(
        OnlineConfig(url: 'https://example.test/api/', enabled: true),
        transport: t,
      );
      await expectLater(
        g.textRequest('translation', 'Hello', consent: true),
        throwsA(isA<GatewayFailure>()),
      );
      expect(t.bodies.last, {
        'text': 'Hello',
        'source_language': 'en',
        'target_language': 'uz',
      });
    },
  );
}

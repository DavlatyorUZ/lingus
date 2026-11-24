import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoy/core/voice_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(VoiceSearch.channel, null));
  test(
    'Voice result is trimmed and requests the selected dictionary language',
    () async {
      final languages = <String>[];
      messenger.setMockMethodCallHandler(VoiceSearch.channel, (call) async {
        languages.add(call.arguments['language'] as String);
        return '  fresh start  ';
      });
      expect(await VoiceSearch.recognize(reverse: false), 'fresh start');
      expect(await VoiceSearch.recognize(reverse: true), 'fresh start');
      expect(languages, ['en-US', 'uz-UZ']);
    },
  );
  test('Cancel returns nothing and unavailable recognizers give actionable Uzbek feedback', () async {
    messenger.setMockMethodCallHandler(VoiceSearch.channel, (_) async => null);
    expect(await VoiceSearch.recognize(reverse: false), isNull);
    messenger.setMockMethodCallHandler(
      VoiceSearch.channel,
      (_) async => throw PlatformException(code: 'speech_unavailable'),
    );
    await expectLater(
      VoiceSearch.recognize(reverse: false),
      throwsA(isA<VoiceSearchFailure>()),
    );
    messenger.setMockMethodCallHandler(
      VoiceSearch.channel,
      (_) async => 'x' * 161,
    );
    await expectLater(
      VoiceSearch.recognize(reverse: false),
      throwsA(isA<VoiceSearchFailure>()),
    );
  });
}

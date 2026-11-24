import 'package:flutter/services.dart';

class VoiceSearchFailure implements Exception {
  final String message;
  const VoiceSearchFailure(this.message);
  @override
  String toString() => message;
}

class VoiceSearch {
  static const channel = MethodChannel('uz.lingoy/voice');
  static Future<String?> recognize({required bool reverse}) async {
    try {
      final value = (await channel.invokeMethod<String>('recognize', {
        'language': reverse ? 'uz-UZ' : 'en-US',
      }))?.trim();
      if (value == null || value.isEmpty) return null;
      if (value.length > 160) {
        throw const VoiceSearchFailure('Qisqaroq so‘z yoki ibora ayting.');
      }
      return value;
    } on MissingPluginException {
      throw const VoiceSearchFailure(
        'Bu qurilmada ovozli qidiruv mavjud emas. Matn bilan qidiring.',
      );
    } on PlatformException {
      throw const VoiceSearchFailure(
        'Ovoz aniqlanmadi. Nutqni aniqlash xizmati va internetni tekshiring.',
      );
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

XFile? recoveredPhoto;
String? recoveredPhotoError;
Future<void>? _recovery;

// Android may recreate the activity while the system camera is open.
Future<void> recoverPhotoAtStartup() => _recovery ??= () async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final response = await ImagePicker().retrieveLostData();
    if (response.files?.isNotEmpty == true) {
      recoveredPhoto = response.files!.first;
    } else if (response.exception != null) {
      recoveredPhotoError = photoError(response.exception!);
    }
  } on PlatformException catch (e) {
    recoveredPhotoError = photoError(e);
  } catch (_) {
    recoveredPhotoError = 'Oldingi surat tiklanmadi. Qayta suratga oling.';
  }
}();

String photoError(Object error) {
  if (error is PlatformException) {
    if ([
      'camera_access_denied',
      'camera_access_restricted',
      'photo_access_denied',
      'photo_access_restricted',
    ].contains(error.code)) {
      return 'Kamera yoki rasmlarga ruxsat berilmagan. Qurilma sozlamalaridan Lingoy uchun ruxsatni yoqing.';
    }
    if (error.code == 'no_available_camera') {
      return 'Kamera topilmadi. Galereyadan rasm tanlashingiz mumkin.';
    }
    if (error.code == 'already_active') {
      return 'Rasm tanlash oynasi ochiq. Avval uni yoping.';
    }
  }
  return 'Rasm ochilmadi. Qayta urinib ko‘ring yoki boshqa rasm tanlang.';
}

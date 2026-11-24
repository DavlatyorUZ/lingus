import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/core/photo_input.dart';
import 'package:lingoy/screens/online_tools.dart';
import 'package:lingoy/screens/account.dart';
import 'package:lingoy/ui/design.dart';

class TestPicker extends ImagePicker {
  final sources = <ImageSource>[];
  Object? error;
  XFile? photo;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    expect(preferredCameraDevice, CameraDevice.rear);
    expect(requestFullMetadata, false);
    expect(maxWidth, lessThanOrEqualTo(1600));
    if (error != null) throw error!;
    return photo;
  }
}

void main() {
  test('A large photo is resized and metadata is cleared before upload', () {
    final source = img.Image(width: 2400, height: 1200);
    source.exif.imageIfd['Make'] = 'Private camera metadata';
    final compressed = compressImage(Uint8List.fromList(img.encodeJpg(source)));
    final decoded = img.decodeJpg(compressed)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(compressed.length, lessThan(3 * 1024 * 1024));
    expect(decoded.exif.imageIfd['Make'], isNull);
    expect(
      () => compressImage(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });
  testWidgets(
    'Camera and gallery use distinct sources; cancellation keeps the view usable',
    (t) async {
      final picker = TestPicker();
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(false),
          home: OnlineToolScreen(mode: 2, picker: picker),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('take-photo')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('pick-photo')));
      await t.pumpAndSettle();
      expect(picker.sources, [ImageSource.camera, ImageSource.gallery]);
      expect(find.byType(Image), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Denied camera access has Uzbek guidance and gallery stays available',
    (t) async {
      final picker = TestPicker()
        ..error = PlatformException(
          code: 'camera_access_denied',
          message: 'private system details',
        );
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          home: OnlineToolScreen(mode: 2, picker: picker),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('take-photo')));
      await t.pumpAndSettle();
      expect(find.textContaining('ruxsat berilmagan'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('pick-photo')))
            .onPressed,
        isNotNull,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Login layout remains readable at 320px and 200 percent text', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme(true),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: AccountScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    final forgot = find.byKey(const ValueKey('forgot-password'));
    await t.scrollUntilVisible(
      forgot,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(
      t.getTopLeft(forgot).dy,
      greaterThan(t.getBottomLeft(fields.last).dy - 1),
    );
    await t.scrollUntilVisible(
      find.text('Google bilan kirish'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await t.scrollUntilVisible(
      find.text('Yangi akkaunt yaratish'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Yangi akkaunt yaratish'), findsOneWidget);
    expect(find.textContaining('Kirish /'), findsNothing);
    expect(t.takeException(), isNull);
  });
  test('No-camera and permission errors do not expose platform details', () {
    expect(
      photoError(PlatformException(code: 'no_available_camera')),
      contains('Galereyadan'),
    );
    expect(photoError(Exception('private')), isNot(contains('private')));
  });
}

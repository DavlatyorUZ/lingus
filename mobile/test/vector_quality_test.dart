import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;
import 'package:lingoy/core/illustrations.dart';
import 'package:lingoy/ui/design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPictureCatalog);
  test('Every illustrated entry resolves to a decoded vector or high-resolution photo', () async {
    final paths = pictureWords.map((p) => p.asset).toSet();
    expect(pictureWords.length, 10000);
    expect(pictureWords.where((p) => !p.word.contains(' ')).length, 7651);
    expect(paths.length, greaterThan(4200));
    for (final path in paths) {
      if (path.endsWith('.webp')) {
        final bytes = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: 32,
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0), reason: path);
        frame.image.dispose();
        codec.dispose();
        continue;
      }
      final info = await vg.vg.loadPicture(vg.AssetBytesLoader(path), null);
      expect(info.size.width, greaterThan(0), reason: path);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..scale(32 / info.size.width, 32 / info.size.height);
      canvas.drawPicture(info.picture);
      final scaled = recorder.endRecording();
      final image = await scaled.toImage(32, 32);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull, reason: path);
      final raw = bytes!.buffer.asUint8List();
      var visible = false;
      for (var i = 0; i < raw.length; i += 4) {
        if (raw[i + 3] > 10 &&
            (raw[i] < 245 || raw[i + 1] < 245 || raw[i + 2] < 245)) {
          visible = true;
          break;
        }
      }
      expect(visible, true, reason: path);
      image.dispose();
      scaled.dispose();
      info.picture.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets(
    'Same artwork comparison uses a real high-density Flutter render',
    (t) async {
      t.view.physicalSize = const Size(900, 560);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        final font = FontLoader('Manrope')
          ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
        await font.load();
      });
      final p = pictureFor('battery')!;
      final oldPath = p.asset
          .replaceFirst('/vectors/', '/symbols/')
          .replaceFirst('.svg.vec', '.webp');
      final oldImage = await t.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          await File(oldPath).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      });
      expect(oldImage, isNotNull);
      addTearDown(oldImage!.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(false),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('quality-capture'),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('1.4 · 256 px', style: display(22)),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: 400,
                            height: 400,
                            child: RawImage(
                              image: oldImage,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          Text('1.5 · Asl vektor', style: display(22)),
                          const SizedBox(height: 18),
                          WordArt(p, width: 400, height: 400),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await t.pump();
      expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('quality-capture')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('test/goldens/vector_quality.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(find.text('Rasm ochilmadi'), findsNothing);
    },
  );
}

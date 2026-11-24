import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/screens/learn.dart';

void main() {
  testWidgets(
    'Glass top edges stay continuous at fractional screen densities',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final dpr in [1.0, 2.0, 2.625, 3.0]) {
        t.view.physicalSize = Size(360 * dpr, 200 * dpr);
        t.view.devicePixelRatio = dpr;
        await t.pumpWidget(
          MaterialApp(
            theme: appTheme(true),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey('rim'),
                  child: SizedBox(
                    width: 320,
                    height: 140,
                    child: ColoredBox(
                      color: LingoyPalette.night.bg,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: LiquidSurface(
                          radius: 22,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.runAsync(() async {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('rim')),
          );
          final image = await boundary.toImage(pixelRatio: dpr);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final y = ((10 + 1.7) * dpr).round();
          var jump = 0;
          for (
            var x = ((10 + 300 * .5) * dpr).round();
            x < ((10 + 300 * .75) * dpr).round();
            x++
          ) {
            for (var channel = 0; channel < 3; channel++) {
              jump = math.max(
                jump,
                (data[(y * image.width + x) * 4 + channel] -
                        data[(y * image.width + x - 1) * 4 + channel])
                    .abs(),
              );
            }
          }
          image.dispose();
          expect(
            jump,
            lessThan(12),
            reason: 'A glass edge must not stop abruptly at DPR $dpr',
          );
        });
      }
    },
  );
  testWidgets(
    'Record actual games page with uninterrupted dark and light surfaces',
    (t) async {
      t.view.physicalSize = const Size(1023.75, 2215.5);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        for (final name in ['Manrope', 'NotoSans', 'Fraunces']) {
          final loader = FontLoader(name)
            ..addFont(rootBundle.load('assets/fonts/$name.ttf'));
          await loader.load();
        }
      });
      for (final night in [true, false]) {
        await t.pumpWidget(
          MaterialApp(
            theme: appTheme(night),
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: const ValueKey('learn-capture'),
              child: Scaffold(
                body: CanvasBg(child: SafeArea(child: LearnScreen())),
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await t.pump(const Duration(milliseconds: 80));
        }
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('learn-capture')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('test/goldens/learn_${night ? 'dark' : 'light'}_v2.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}

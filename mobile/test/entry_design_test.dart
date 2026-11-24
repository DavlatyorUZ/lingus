import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/screens/account.dart';
import 'package:lingoy/screens/online_tools.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/ui/word_journey.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets(
    'Entry artwork settles, keeps fields usable and respects reduced motion',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        for (final name in ['Manrope', 'NotoSans']) {
          final font = FontLoader(name)
            ..addFont(rootBundle.load('assets/fonts/$name.ttf'));
          await font.load();
        }
      });
      Future<void> capture(String name) async {
        await t.runAsync(() async {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('entry-capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('test/goldens/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final isDark in [false, true]) {
        await t.pumpWidget(
          MaterialApp(
            theme: appTheme(isDark),
            home: const RepaintBoundary(
              key: ValueKey('entry-capture'),
              child: AccountScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Google bilan kirish'), findsOneWidget);
        expect(find.text('Yangi akkaunt yaratish'), findsOneWidget);
        expect(t.takeException(), isNull);
        await capture(isDark ? 'login_dark_320' : 'login_light_320');
      }
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          home: RepaintBoundary(
            key: const ValueKey('entry-capture'),
            child: OnlineToolScreen(mode: 2, picker: ImagePicker()),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Suratga olish'), findsOneWidget);
      expect(find.text('Galereyadan'), findsOneWidget);
      await capture('camera_320');
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: WordJourney()),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t
            .widget<TweenAnimationBuilder<double>>(
              find.byType(TweenAnimationBuilder<double>),
            )
            .duration,
        Duration.zero,
      );
      expect(t.takeException(), isNull);
    },
  );
}

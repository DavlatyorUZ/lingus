import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/screens/home.dart';
import 'package:lingoy/screens/dictionary.dart';
import 'package:lingoy/screens/learn.dart';
import 'package:lingoy/screens/profile.dart';
import 'package:lingoy/screens/vocabulary.dart';
import 'package:lingoy/screens/collections.dart';
import 'package:lingoy/screens/games.dart';

void main() {
  testWidgets(
    'V2 checks long saved lists and all main screens across density, theme and text sizes',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp('lingoy-v2-ui-');
        await databaseFactory.setDatabasesPath(dir.path);
        SharedPreferences.setMockInitialValues({
          'name': 'Muhammadali Abdurahmonov',
          'onboarded': true,
          'motion': 'smooth',
        });
        for (final font in ['Manrope', 'NotoSans', 'Fraunces']) {
          final loader = FontLoader(font)
            ..addFont(rootBundle.load('assets/fonts/$font.ttf'));
          await loader.load();
        }
        await store.init();
        expect(store.ready, true, reason: store.error);
        final words = (await store.dict.rawQuery(
          'SELECT normalized FROM entries LIMIT 1200',
        )).map((r) => r['normalized'] as String).toList();
        await store.importVocabulary(words);
      });
      PaintingBinding.instance.imageCache.maximumSizeBytes = 24 * 1024 * 1024;
      Future<void> settle() async {
        for (var i = 0; i < 30; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await t.pump(const Duration(milliseconds: 70));
          if (i > 4 &&
              !find
                  .byType(CircularProgressIndicator)
                  .evaluate()
                  .any(
                    (e) =>
                        (e.widget as CircularProgressIndicator).value == null,
                  )) {
            break;
          }
        }
        await t.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 10),
        );
      }

      t.view.physicalSize = const Size(390, 880);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          home: const RepaintBoundary(
            key: ValueKey('vocab-v2'),
            child: VocabularyScreen(),
          ),
        ),
      );
      await settle();
      expect(store.saved.length, 1200);
      expect(find.byType(WordTile).evaluate().length, lessThan(30));
      await t.enterText(find.byType(TextField), 'zzdoesnotexist');
      await t.pumpAndSettle();
      expect(find.text('Mos so‘z topilmadi'), findsOneWidget);
      await t.tap(find.text('Qidiruvni tozalash'));
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await t.runAsync(() async {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('vocab-v2')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('test/goldens/vocabulary_v2.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      final apple = await t.runAsync(() => store.lookup('apple'));
      for (final night in [false, true]) {
        for (final size in [
          (320.0, 1.0, 2.0),
          (360.0, 2.625, 1.0),
          (390.0, 3.0, 1.0),
          (600.0, 1.5, 2.0),
        ]) {
          t.view.physicalSize = Size(size.$1 * size.$2, 880 * size.$2);
          t.view.devicePixelRatio = size.$2;
          for (final page in <Widget>[
            HomeScreen(onTab: (_) {}),
            const DictionaryScreen(initial: 'apple'),
            const LearnScreen(),
            const ProfileScreen(),
            const VocabularyScreen(),
            const StudyCollectionScreen(kind: 'speaking'),
            WordScreen(word: apple!),
            const MemoryGameScreen(),
          ]) {
            await t.pumpWidget(
              MaterialApp(
                key: UniqueKey(),
                theme: appTheme(night),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(size.$1, 880),
                    devicePixelRatio: size.$2,
                    textScaler: TextScaler.linear(size.$3),
                    disableAnimations: size.$1 == 320,
                  ),
                  child: MotionPolicy(
                    light: size.$1 == 320,
                    child: Scaffold(
                      body: CanvasBg(child: SafeArea(child: page)),
                    ),
                  ),
                ),
              ),
            );
            await settle();
            expect(
              t.takeException(),
              isNull,
              reason:
                  '${page.runtimeType} width=${size.$1} DPR=${size.$2} scale=${size.$3} dark=$night',
            );
            final scrolls = find
                .byType(Scrollable)
                .evaluate()
                .where(
                  (e) =>
                      ((e.widget as Scrollable).axisDirection ==
                      AxisDirection.down),
                )
                .toList();
            if (scrolls.isNotEmpty) {
              final scroll = find.byWidget(scrolls.first.widget);
              for (var step = 0; step < 2; step++) {
                await t.drag(scroll, const Offset(0, -550));
                await settle();
                expect(
                  t.takeException(),
                  isNull,
                  reason: 'Scrolled ${page.runtimeType}',
                );
              }
            }
          }
        }
      }
    },
  );
}

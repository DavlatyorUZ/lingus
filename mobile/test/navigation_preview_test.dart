import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/main.dart';
import 'package:lingoy/ui/design.dart';

void main() {
  testWidgets(
    'Record real tab navigation with preserved screens and vectors',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp('lingoy-preview-');
        await databaseFactory.setDatabasesPath(dir.path);
        SharedPreferences.setMockInitialValues({
          'onboarded': true,
          'name': 'Davlatyor',
          'motion': 'smooth',
        });
        for (final name in ['Manrope', 'NotoSans', 'Fraunces']) {
          final loader = FontLoader(name)
            ..addFont(rootBundle.load('assets/fonts/$name.ttf'));
          await loader.load();
        }
        await store.init();
        await Directory('test/navigation_frames').create(recursive: true);
      });
      expect(store.ready, true, reason: store.error);
      await t.pumpWidget(
        const RepaintBoundary(key: ValueKey('nav-capture'), child: LingoyApp()),
      );
      Future<void> settle() async {
        for (var i = 0; i < 12; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await t.pump(const Duration(milliseconds: 40));
        }
        await t.pumpAndSettle();
      }

      Future<void> shot(int i, {String? path}) => t.runAsync(() async {
        final b = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('nav-capture')),
        );
        final image = await b.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          path ??
              'test/navigation_frames/frame-${i.toString().padLeft(3, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await settle();
      await t.tap(find.byKey(const ValueKey('nav-1')));
      await settle();
      await shot(0, path: 'test/goldens/dictionary_design.png');
      final query = find.byKey(const ValueKey('dictionary-query'));
      final nav = find.byKey(const ValueKey('nav-1'));
      expect(t.getRect(query).bottom, lessThan(t.getRect(nav).top));
      await t.enterText(query, 'apple');
      await t.pump(const Duration(milliseconds: 250));
      await t.enterText(query, 'book');
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await t.pump(const Duration(milliseconds: 80));
      expect(
        find.byWidgetPredicate((w) => w is WordTile && w.word.lemma == 'apple'),
        findsNothing,
        reason:
            'An older query cannot reappear while the next query is debouncing',
      );
      await settle();
      expect(find.text('book'), findsWidgets);
      await t.enterText(query, List.filled(161, 'a').join());
      await settle();
      expect(
        t.widget<TextField>(query).controller!.text.length,
        lessThanOrEqualTo(160),
      );
      await t.enterText(query, 'apple');
      await settle();
      await t.tap(find.byKey(const ValueKey('search-language')));
      await settle();
      await t.enterText(query, 'olma');
      await settle();
      expect(find.text('apple'), findsWidgets);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-1')), findsNothing);
      expect(t.getRect(query).bottom, lessThanOrEqualTo(844 - 280));
      t.view.resetViewInsets();
      await settle();
      await t.tap(find.byKey(const ValueKey('search-language')));
      await settle();
      await t.enterText(query, '');
      await settle();
      await t.tap(find.byKey(const ValueKey('nav-0')));
      await settle();
      await shot(0, path: 'test/goldens/home_design.png');
      var frame = 0;
      await t.tap(find.byKey(const ValueKey('theme-dark')).first);
      await t.pump();
      for (var i = 0; i < 24; i++) {
        await t.pump(const Duration(milliseconds: 33));
        await shot(frame++);
      }
      await settle();
      expect(store.theme, 'dark');
      await shot(0, path: 'test/goldens/home_design_dark.png');

      for (final tab in [1, 2, 3, 0]) {
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 50));
          await shot(frame++);
        }
        await t.tap(find.byKey(ValueKey('nav-$tab')));
        await t.pump();
        for (var i = 0; i < 22; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await t.pump(const Duration(milliseconds: 33));
          await shot(frame++);
        }
        expect(t.takeException(), isNull);
      }
      await settle();
      final start = t.getCenter(find.byKey(const ValueKey('nav-0')));
      final end = t.getCenter(find.byKey(const ValueKey('nav-3')));
      final touch = await t.startGesture(start);
      for (var step = 0; step < 20; step++) {
        await touch.moveBy((end - start) / 20);
        await t.pump(const Duration(milliseconds: 33));
        await shot(frame++);
      }
      await touch.up();
      for (var step = 0; step < 22; step++) {
        await t.pump(const Duration(milliseconds: 33));
        await shot(frame++);
      }
      await settle();
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const ValueKey('nav-3')));
      await settle();
      expect(find.byType(ThemeToggle).hitTestable(), findsOneWidget);
      expect(find.text('Sizga mos ko‘rinish'), findsNothing);
      await shot(0, path: 'test/goldens/profile_design.png');
      await t.tap(find.byKey(const ValueKey('theme-light')).hitTestable());
      await settle();
      expect(store.theme, 'light');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme'), 'light');
      await t.pumpWidget(const SizedBox.shrink());
      await t.runAsync(() async {
        await store.dict.close();
        await store.user.close();
      });
    },
    skip: Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

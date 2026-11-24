import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/core/collections.dart';
import 'package:lingoy/screens/collections.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/ui/search_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Compact services and usable collections at 320px and double text',
    (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp(
          'lingoy-collections-',
        );
        await databaseFactory.setDatabasesPath(dir.path);
        SharedPreferences.setMockInitialValues({
          'name': 'Davlatyor',
          'onboarded': true,
        });
        for (final name in ['Manrope', 'NotoSans', 'Fraunces']) {
          final loader = FontLoader(name)
            ..addFont(rootBundle.load('assets/fonts/$name.ttf'));
          await loader.load();
        }
        await store.init();
      });
      final content = await t.runAsync(loadEssentials);
      expect(content!.where((e) => e.kind == 'daily').length, 59);
      expect(content.where((e) => e.kind == 'speaking').length, 48);
      expect(content.map((e) => e.id).toSet().length, content.length);
      expect(
        content.every(
          (e) =>
              e.meaning.isNotEmpty &&
              e.example.isNotEmpty &&
              e.translation.isNotEmpty,
        ),
        true,
      );
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(false),
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(18), child: ComingTools()),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(ComingTools)).height, lessThan(110));
      expect(find.text('Tez kunda'), findsNothing);
      Future<void> open(String kind) async {
        await t.pumpWidget(
          MaterialApp(
            theme: appTheme(false),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: StudyCollectionScreen(key: ValueKey(kind), kind: kind),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 40));
        }
        await t.pumpAndSettle();
      }

      await open('speaking');
      await t.enterText(
        find.byKey(const ValueKey('collection-query')),
        'in my opinion',
      );
      await t.pumpAndSettle();
      expect(find.text('In my opinion, …'), findsOneWidget);
      final entry = content.firstWhere((e) => e.word == 'In my opinion, …');
      final save = find.byKey(ValueKey('save-${entry.id}'));
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(save);
      await t.pumpAndSettle();
      expect(
        store.prefs.getStringList('essential-bookmarks'),
        contains(entry.id),
      );
      await open('daily');
      await t.enterText(
        find.byKey(const ValueKey('collection-query')),
        'odatda',
      );
      await t.pumpAndSettle();
      expect(find.text('usually'), findsOneWidget);
      for (final spelling in ["bo'sh", 'bo‘sh', 'BO’SH']) {
        await t.enterText(
          find.byKey(const ValueKey('collection-query')),
          spelling,
        );
        await t.pumpAndSettle();
        expect(find.text('available'), findsOneWidget);
      }

      await open('speaking');
      await t.tap(find.byTooltip('Saqlanganlarni ko‘rish'));
      await t.pumpAndSettle();
      expect(find.text('In my opinion, …'), findsOneWidget);
      expect(t.takeException(), isNull);
      t.view.physicalSize = const Size(390, 844);
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(false),
          debugShowCheckedModeBanner: false,
          home: const RepaintBoundary(
            key: ValueKey('collection-preview'),
            child: StudyCollectionScreen(
              key: ValueKey('preview'),
              kind: 'speaking',
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 40));
      }
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('collection-preview')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('test/goldens/speaking_design.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
  );
}

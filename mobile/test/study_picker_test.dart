import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/core/study_game.dart';
import 'package:lingoy/screens/study_game.dart';

Future<void> settleDb(WidgetTester t) async {
  for (var i = 0; i < 25; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 30));
  }
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Search multi-select starts with one word and keeps selection across searches',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp('lingoy-study-');
        await databaseFactory.setDatabasesPath(dir.path);
        SharedPreferences.setMockInitialValues({
          'name': 'Ali',
          'onboarded': true,
        });
        await store.init();
      });
      expect(store.ready, true, reason: store.error);
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(false),
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => openStudyGame(c, 'translate'),
                child: const Text('Ochish'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Ochish'));
      await settleDb(t);
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('study-start')))
            .onPressed,
        isNull,
      );
      await t.enterText(find.byType(TextField), 'receive');
      await t.pump(const Duration(milliseconds: 300));
      await settleDb(t);
      final tile = find.byKey(const ValueKey('study-word-108907'));
      expect(tile, findsOneWidget);
      await t.tap(find.descendant(of: tile, matching: find.byType(Checkbox)));
      await settleDb(t);
      expect(find.textContaining('1 ta tanlandi'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('study-start')))
            .onPressed,
        isNotNull,
      );
      await t.enterText(find.byType(TextField), 'big');
      await t.pump(const Duration(milliseconds: 300));
      await settleDb(t);
      expect(find.text('receive'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'zzzzzzzzz');
      await t.pump(const Duration(milliseconds: 300));
      await settleDb(t);
      expect(find.textContaining('So‘z topilmadi'), findsOneWidget);
      expect(find.textContaining('1 ta tanlandi'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('study-start')));
      await settleDb(t);
      expect(find.byType(StudyGameScreen), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const SizedBox.shrink());
      final ids = <int>[];
      await t.runAsync(() async {
        final bank = StudyBank(
          jsonDecode(File('assets/quiz_bank.json').readAsStringSync())
              as Map<String, dynamic>,
        );
        for (final entry
            in bank.entries.where((w) => w.translation.isNotEmpty).take(30)) {
          await store.ensureSaved(entry.id);
          ids.add(entry.id);
        }
      });
      t.view.physicalSize = const Size(320, 700);
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => openStudyGame(c, 'translate'),
                child: const Text('Ochish'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Ochish'));
      await settleDb(t);
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('study-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final id in ids) {
        final row = find.byKey(ValueKey('study-word-$id'));
        await t.scrollUntilVisible(
          row,
          220,
          scrollable: scrollable,
          maxScrolls: 80,
        );
        await t.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
        await settleDb(t);
      }
      // A keyboard shrinks the route after all thirty real UI selections.
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      final start = find.byKey(const ValueKey('study-start'));
      expect(start.hitTestable(), findsOneWidget);
      final rect = t.getRect(start);
      expect(rect.bottom, lessThanOrEqualTo(420));
      expect(rect.top, greaterThan(0));
      expect(t.widget<FilledButton>(start).onPressed, isNotNull);
      expect(t.takeException(), isNull);
      await t.tap(start);
      for (
        var attempt = 0;
        attempt < 200 && find.byType(StudyGameScreen).evaluate().isEmpty;
        attempt++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump(const Duration(milliseconds: 100));
        if (find.text('Boshlash').evaluate().isNotEmpty) {
          await t.tap(find.text('Boshlash'));
        }
      }
      await t.pumpAndSettle();
      expect(find.byType(StudyGameScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/screens/dictionary.dart';
import 'package:lingoy/main.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 15; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 35)),
    );
    await t.pump(const Duration(milliseconds: 60));
  }
  await t.pumpAndSettle();
}

Future<void> shot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final b = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    final image = await b.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('test/goldens/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'Meaning detail stays compact; search and navigation remain clear',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp('lingoy-entry-330-');
        await databaseFactory.setDatabasesPath(dir.path);
        SharedPreferences.setMockInitialValues({
          'name': 'Ali',
          'onboarded': true,
          'motion': 'light',
        });
        for (final f in ['Manrope', 'NotoSans', 'Fraunces']) {
          await (FontLoader(
            f,
          )..addFont(rootBundle.load('assets/fonts/$f.ttf'))).load();
        }
        await store.init();
      });
      expect(store.ready, true, reason: store.error);
      final w = (await t.runAsync(() => store.lookup('start')))!;
      final forms = (await t.runAsync(() => store.baseForms('started')))!;
      final form = forms.firstWhere(
        (f) => f.word.lemma == 'start' && f.pos == 'v',
      );
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const ValueKey('preview'),
            child: WordScreen(word: w, analysis: form),
          ),
        ),
      );
      await settle(t);
      await t.scrollUntilVisible(
        find.text('Misollar').first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(
        find
            .byWidgetPredicate(
              (x) => x.runtimeType.toString() == '_ExampleCard',
            )
            .evaluate()
            .length,
        lessThanOrEqualTo(3),
      );
      await shot(t, 'meaning_330_dark');
      expect(t.takeException(), isNull);
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const ValueKey('preview'),
            child: Shell(referenceTime: DateTime(2026, 11, 21)),
          ),
        ),
      );
      await settle(t);
      await shot(t, 'navigation_330_dark');
      expect(find.byKey(const ValueKey('nav-lens')), findsNothing);
      expect(find.byKey(const ValueKey('nav-selection')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('nav-1')));
      await settle(t);
      await t.enterText(
        find.byKey(const ValueKey('dictionary-query')),
        'start',
      );
      await t.pump(const Duration(milliseconds: 300));
      await settle(t);
      final field = t.getRect(find.byKey(const ValueKey('dictionary-query'))),
          language = t.getRect(find.byKey(const ValueKey('search-language')));
      expect((language.center.dy - field.center.dy).abs(), lessThan(8));
      expect(language.right, lessThanOrEqualTo(390));
      expect(
        t.getRect(find.byKey(const ValueKey('search-dock'))).bottom,
        lessThanOrEqualTo(t.getRect(find.byKey(const ValueKey('nav-1'))).top),
      );
      await shot(t, 'search_330_dark');
      expect(t.takeException(), isNull);
    },
  );
}

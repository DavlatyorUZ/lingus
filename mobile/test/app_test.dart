import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/main.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/screens/offline_tools.dart';
import 'package:lingoy/screens/dictionary.dart';
import 'package:lingoy/screens/learn.dart';
import 'package:lingoy/screens/profile.dart';
import 'package:lingoy/screens/home.dart';
import 'package:lingoy/screens/pictures.dart';
import 'package:lingoy/core/illustrations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Full offline database, persistent review, and mobile screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('lexora-qa-');
      await databaseFactory.setDatabasesPath(dir.path);
      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        'name': 'Davlatyor',
        'level': 'B1',
      });
      for (final font in ['Fraunces', 'Manrope', 'NotoSans']) {
        final loader = FontLoader(font);
        loader.addFont(rootBundle.load('assets/fonts/$font.ttf'));
        await loader.load();
      }
      await store.init();
      expect(store.ready, true, reason: store.error);
      final happy = await store.lookup('happy');
      expect(happy, isNotNull);
      expect(happy!.translation, isNotEmpty);
      final synonyms = await store.senses(happy.id);
      expect(synonyms, isNotEmpty);
      for (final pair in {
        'run': 57,
        'set': 45,
        'light': 47,
        'right': 36,
        'bank': 18,
        'miss': 12,
        'watch': 13,
        'book': 15,
        'mean': 16,
        'match': 19,
      }.entries) {
        final word = await store.lookup(pair.key);
        final all = await store.senses(word!.id);
        expect(all.length, pair.value, reason: pair.key);
        if ([
          'bank',
          'miss',
          'watch',
          'book',
          'mean',
          'match',
        ].contains(pair.key)) {
          expect(
            all.every((s) => (s['bilingual_examples'] as String) != '[]'),
            true,
            reason: pair.key,
          );
        }
      }
      final known = (await store.dict.query(
        'senses',
        columns: ['id'],
      )).map((s) => s['id']).toSet();
      expect(store.senseExamples.keys.every(known.contains), true);
      for (final text in [
        "'running'",
        '“Running!”',
        '(running)',
        '[running].',
      ]) {
        expect(
          (await store.baseForms(text)).any((f) => f.word.lemma == 'run'),
          true,
          reason: text,
        );
      }
      expect(await store.baseForms('read'), isEmpty);
      final unchangedRead = await store.baseForms(
        'read',
        includeUnchanged: true,
      );
      expect(
        unchangedRead.any(
          (f) => f.pos == 'v' && f.word.lemma == 'read' && f.unchanged,
        ),
        true,
      );
      expect(
        await store.baseForms('read'),
        isEmpty,
        reason: 'Cache preserves the includeUnchanged option',
      );
      final quoted = await store.analyzeText(
        "He said 'running' and \"studied\"; read yesterday.",
      );
      expect(
        quoted
            .firstWhere((a) => a.input == 'running')
            .bases
            .any((f) => f.word.lemma == 'run'),
        true,
      );
      expect(
        quoted
            .firstWhere((a) => a.input == 'read')
            .bases
            .any((f) => f.infinitive == 'to read'),
        true,
      );
      final orderedRun = await store.senses((await store.lookup('run'))!.id);
      expect(orderedRun.firstWhere((s) => s['pos'] == 'v')['id'], 'v1926311');
      expect(
        (await store.baseForms('running'))
            .firstWhere((f) => f.pos == 'v')
            .definition,
        contains('move fast'),
      );
      expect(store.sensePriority.length, 26896);
      final inflections = {
        'went': 'go',
        'gone': 'go',
        'was': 'be',
        'were': 'be',
        'seen': 'see',
        'taken': 'take',
        'had': 'have',
        'did': 'do',
        'running': 'run',
        'studied': 'study',
        'studying': 'study',
        'making': 'make',
        'lying': 'lie',
        'stopped': 'stop',
        'hoping': 'hope',
        'hopping': 'hop',
        'reading': 'read',
        'worked': 'work',
        'watches': 'watch',
        'tries': 'try',
        'children': 'child',
        'mice': 'mouse',
        'books': 'book',
        'better': 'good',
        'happier': 'happy',
        'biggest': 'big',
        "teacher's": 'teacher',
        "teachers'": 'teacher',
        'looked after': 'look after',
      };
      for (final pair in inflections.entries) {
        final forms = await store.baseForms(pair.key);
        expect(
          forms.any((f) => f.word.lemma == pair.value),
          true,
          reason: '${pair.key}: ${forms.map((f) => f.word.lemma).join(', ')}',
        );
      }
      for (final token in ['was', 'has']) {
        final bases = await store.baseForms(token);
        expect(bases.any((f) => f.pos != 'v'), false, reason: token);
      }
      expect(
        (await store.baseForms('running'))
            .firstWhere((f) => f.pos == 'v')
            .meaning,
        'yugurmoq; boshqarmoq',
      );
      expect(
        (await store.baseForms('was')).firstWhere((f) => f.pos == 'v').meaning,
        'bo‘lmoq; mavjud bo‘lmoq',
      );
      for (final key in store.baseGlosses.keys) {
        final part = key.split(':');
        expect(
          await store.dict.rawQuery(
            'SELECT 1 FROM entries e JOIN entry_senses es ON es.entry_id=e.id JOIN senses s ON s.id=es.sense_id WHERE e.normalized=? AND s.pos=? LIMIT 1',
            part,
          ),
          isNotEmpty,
          reason: key,
        );
      }
      expect((await store.baseForms('went')).any((f) => f.pos != 'v'), false);
      expect(
        (await store.baseForms('hoping')).any((f) => f.word.lemma == 'hop'),
        false,
      );
      expect(
        (await store.search('studied')).any((w) => w.lemma == 'study'),
        true,
      );
      expect(
        (await store.baseForms('saw')).any((f) => f.word.lemma == 'see'),
        true,
      );
      expect(await store.lookup('saw'), isNotNull);
      final parsed = await store.analyzeText(
        'She went home, studied, and was running.',
      );
      expect(
        parsed
            .firstWhere((a) => a.input == 'went')
            .bases
            .any((f) => f.word.lemma == 'go'),
        true,
      );
      expect(
        parsed
            .firstWhere((a) => a.input == 'running')
            .bases
            .any((f) => f.word.lemma == 'run'),
        true,
      );
      await store.ensureSaved(happy.id);
      expect(store.saved.contains(happy.id), true);
      await store.review(happy, 2);
      expect((await store.stats())['today'], 1);
      expect(await store.savedWords(due: true), isEmpty);
      final reverse = await store.search('kitob', reverse: true);
      expect(reverse.any((w) => w.lemma == 'book'), true);
      final cefr = await store.search('', lv: 'B1', limit: 5);
      expect(cefr.every((w) => w.level == 'B1'), true);
      await store.clearUserData();
      for (final p in pictureWords) {
        expect(await store.lookup(p.word), isNotNull, reason: p.word);
        await rootBundle.load(p.asset);
      }
    });
    await tester.pumpWidget(
      RepaintBoundary(
        child: LingoyApp(referenceTime: DateTime(2026, 11, 15, 14)),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Salom, Davlatyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/home.png'),
    );
    await tester.tap(find.byKey(const ValueKey('theme-dark')).first);
    await tester.pumpAndSettle();
    expect(store.theme, 'dark');
    expect(store.prefs.getString('theme'), 'dark');
    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.dark,
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/home_dark.png'),
    );
    await tester.tap(find.byKey(const ValueKey('theme-light')).first);
    await tester.pumpAndSettle();
    expect(store.prefs.getString('theme'), 'light');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(false),
        home: const PageFrame(
          title: 'Lug‘at',
          child: DictionaryScreen(initial: 'achievement'),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('achievement'), findsWidgets);
    expect(find.byType(LevelBadge), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dictionary.png'),
    );

    final teacher = await tester.runAsync(() => store.lookup('teacher'));
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('word-light'),
        debugShowCheckedModeBanner: false,
        theme: appTheme(false),
        home: WordScreen(word: teacher!),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.byType(WordArt), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/word_light.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('word-dark'),
        debugShowCheckedModeBanner: false,
        theme: appTheme(true),
        home: WordScreen(word: teacher),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/word_dark.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('pictures'),
        debugShowCheckedModeBanner: false,
        theme: appTheme(false),
        home: const PicturesScreen(),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pictures.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(false),
        home: const Scaffold(body: CanvasBg(child: ToolsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'She don’t like apples. I have went home.',
    );
    await tester.pump();
    await tester.tap(find.text('Grammatikani tekshirish'));
    await tester.pumpAndSettle();
    expect(find.text('2 ta tekshirish tavsiyasi topildi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/grammar.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(true),
        home: const Scaffold(body: CanvasBg(child: ProfileScreen())),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/profile_dark.png'),
    );
    tester.view.physicalSize = const Size(320, 740);
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('small-word'),
        debugShowCheckedModeBanner: false,
        theme: appTheme(true),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(1.2)),
          child: child!,
        ),
        home: WordScreen(word: teacher),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(false),
        home: const Scaffold(body: CanvasBg(child: LearnScreen())),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('morph-search'),
        theme: appTheme(true),
        debugShowCheckedModeBanner: false,
        home: const PageFrame(
          title: 'Lug‘at',
          child: DictionaryScreen(initial: 'studied'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('studied → to study'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('studied → to study'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/infinitive_dark.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('text-forms'),
        theme: appTheme(true),
        debugShowCheckedModeBanner: false,
        home: const TranslatorScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'She went home, was running and studied.',
    );
    await tester.tap(find.text('Tarjimasini topish'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('went → to go'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('went → to go'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('running → to run'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('running → to run'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/text_forms_dark.png'),
    );
    final bank = await tester.runAsync(() => store.lookup('bank'));
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('bank-example'),
        theme: appTheme(true),
        debugShowCheckedModeBanner: false,
        home: WordScreen(word: bank!),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ma’nolar va misollar'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final bankSenses = (await tester.runAsync(() => store.senses(bank.id)))!;
    final bankSense = bankSenses.firstWhere(
      (s) => (s['bilingual_examples'] as String).contains(
        'The bank approved his loan.',
      ),
    );
    final bankPanel = find.byKey(ValueKey('sense-${bankSense['id']}'));
    for (var i = 0; bankPanel.evaluate().isEmpty && i < 15; i++) {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('more-senses')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-senses')));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(bankPanel);
    final bankHeading = find
        .descendant(of: bankPanel, matching: find.byType(InkWell))
        .first;
    await tester.tap(bankHeading);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('The bank approved his loan.'));
    await tester.pumpAndSettle();
    expect(find.text('Bank uning kreditini ma’qulladi.'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/bank_dark.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('unchanged-read'),
        theme: appTheme(true),
        debugShowCheckedModeBanner: false,
        home: const PageFrame(
          title: 'Lug‘at',
          child: DictionaryScreen(initial: 'read'),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('to read'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Infinitiv'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/unchanged_read_dark.png'),
    );
    await tester.tap(find.text('to read'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('TANLANGAN SHAKL · QISQA MA’NO'), findsOneWidget);
    expect(find.text('o‘qimoq'), findsWidgets);
    final running = await tester.runAsync(() => store.baseForms('running'));
    final runForm = running!.firstWhere((f) => f.pos == 'v');
    final runSenses = await tester.runAsync(
      () => store.senses(runForm.word.id),
    );
    final verbSenses = runSenses!.where((s) => s['pos'] == 'v').toList();
    final nounSenses = runSenses.where((s) => s['pos'] == 'n').toList();
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('run-parts'),
        theme: appTheme(true),
        debugShowCheckedModeBanner: false,
        home: WordScreen(
          word: runForm.word,
          sourceForm: 'running',
          analysis: runForm,
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('sense-count')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Ma’noni ochib, unga tegishli misol va sinonimlarni ko‘ring.'),
      findsOneWidget,
    );
    final firstVerb = find.byKey(ValueKey('sense-${verbSenses.first['id']}'));
    final firstNoun = find.byKey(ValueKey('sense-${nounSenses.first['id']}'));
    expect(firstVerb, findsOneWidget);
    expect(
      firstNoun,
      findsNothing,
      reason: 'Only three relevant senses are mounted at first',
    );
    expect(find.byKey(const ValueKey('more-senses')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sense-pos-v')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sense-pos-v')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sense-pos-v')), findsOneWidget);
    expect(firstNoun, findsNothing);
    await tester.tap(find.byKey(const ValueKey('sense-pos-n')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sense-pos-n')), findsOneWidget);
    expect(firstVerb, findsNothing);
    await tester.tap(find.byKey(const ValueKey('sense-pos-')));
    await tester.pumpAndSettle();
    expect(
      find.text('Ma’noni ochib, unga tegishli misol va sinonimlarni ko‘ring.'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pos_filters_dark.png'),
    );
    expect(tester.takeException(), isNull);
  }, skip: Platform.isWindows);
}

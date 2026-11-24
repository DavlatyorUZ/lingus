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
import 'package:lingoy/ui/game_motion.dart';
import 'package:lingoy/core/store.dart';
import 'package:lingoy/core/game_session.dart';
import 'package:lingoy/core/illustrations.dart';
import 'package:lingoy/core/support.dart';
import 'package:lingoy/screens/games.dart';
import 'package:lingoy/screens/learn.dart';
import 'package:lingoy/screens/pictures.dart';
import 'package:lingoy/screens/profile.dart';
import 'package:lingoy/screens/home.dart';
import 'package:lingoy/screens/dictionary.dart';
import 'package:lingoy/screens/offline_tools.dart';
import 'package:lingoy/screens/vocabulary.dart';
import 'package:lingoy/screens/grammar.dart';
import 'package:lingoy/screens/account.dart';
import 'package:lingoy/screens/online_tools.dart';

Future<void> settleDb(WidgetTester t, {bool Function()? until}) async {
  for (var i = 0; i < 60; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 40));
    if (until?.call() ??
        (i >= 5 &&
            !find
                .byType(CircularProgressIndicator)
                .evaluate()
                .any(
                  (e) => (e.widget as CircularProgressIndicator).value == null,
                ))) {
      break;
    }
  }
  await t.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}

Widget host(Widget child, {double scale = 1, bool reduced = false}) =>
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: appTheme(false),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
          textScaler: scale == 1
              ? MediaQuery.textScalerOf(c)
              : TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('capture'),
        child: Scaffold(body: child),
      ),
    );
Future<void> shot(WidgetTester t, String path) async {
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  test('Retry, unique options, and single scoring', () {
    final r = RecallRound(2, [1, 2, 3, 4]);
    expect(r.choose(1), false);
    expect(r.choose(1), null);
    expect(r.choose(5), null);
    expect(r.perfect, false);
    expect(r.choose(2), true);
    expect(r.choose(2), null);
    expect(r.missed, {1});
    expect(() => RecallRound(2, [2, 2]), throwsArgumentError);
    expect(Store.validName('  Davlatyor  '), true);
    expect(Store.validName('O‘tkir'), true);
    expect(Store.validName(''), false);
    expect(Store.validName('123'), false);
    expect(Store.validName(String.fromCharCode(0x1f600)), false);
    expect(Store.cleanName('  Ali   Vali  '), 'Ali Vali');
  });
  testWidgets('Reduced motion disables answer shaking', (t) async {
    await t.pumpWidget(
      host(
        const AnswerMotion(
          trigger: 1,
          success: false,
          child: SizedBox(width: 50, height: 50),
        ),
        reduced: true,
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AnswerMotion),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
  testWidgets(
    'Name-only entry, memory play, persistent scheduling, layouts and contacts',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp('lingoy-games-');
        await databaseFactory.setDatabasesPath(dir.path);
        SharedPreferences.setMockInitialValues({'onboarded': true});
        for (final font in ['Manrope', 'NotoSans', 'Fraunces']) {
          final loader = FontLoader(font);
          loader.addFont(rootBundle.load('assets/fonts/$font.ttf'));
          await loader.load();
        }
        await store.init();
        expect(store.ready, true, reason: store.error);
      });

      expect(store.onboarded, false);
      await t.pumpWidget(host(const Onboarding()));
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await t.tap(find.text('Boshlash'));
      await t.pumpAndSettle();
      expect(find.text('Ismingizni harflar bilan kiriting.'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('name-input')),
        '  Davlatyor  ',
      );
      await t.tap(find.text('Boshlash'));
      await settleDb(t);
      expect(store.name, 'Davlatyor');
      expect(store.onboarded, true);

      expect(store.prefs.getString('name'), 'Davlatyor');
      await t.pumpWidget(host(const Onboarding()));
      await t.pumpAndSettle();
      await shot(t, 'test/goldens/onboarding.png');

      // Future reviews cannot be inflated by repeatedly playing the same word.
      await t.runAsync(() async {
        final w = (await store.lookup('apple'))!;
        await store.gameReview(w, true);
        final before = (await store.user.query(
          'saved',
          where: 'word_id=?',
          whereArgs: [w.id],
        )).single;
        await store.gameReview(w, true);
        final after = (await store.user.query(
          'saved',
          where: 'word_id=?',
          whereArgs: [w.id],
        )).single;
        expect(after['due'], before['due']);
        expect(after['reps'], before['reps']);
        await store.gameReview(w, false);
        final failed = (await store.user.query(
          'saved',
          where: 'word_id=?',
          whereArgs: [w.id],
        )).single;
        expect(failed['reps'], 0);
        expect(
          failed['due'] as int,
          lessThan(
            DateTime.now()
                .add(const Duration(minutes: 11))
                .millisecondsSinceEpoch,
          ),
        );
        await store.clearUserData();
        for (final picture in starterPictureWords.take(12)) {
          final word = await store.lookup(picture.word);
          if (word != null) await store.ensureSaved(word.id);
        }
      });

      await t.pumpWidget(host(const MemoryGameScreen()));
      await settleDb(
        t,
        until: () => find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith('option-'),
            )
            .evaluate()
            .isNotEmpty,
      );

      expect(find.text('Savol 1 / 10'), findsOneWidget);
      expect(t.takeException(), isNull);
      await settleDb(t);
      await shot(t, 'test/goldens/game.png');
      final savedWords = (await t.runAsync(() => store.savedWords()))!;
      bool matchesClue(dynamic word, int question) {
        final meanings = {word.translation, pictureFor(word.lemma)?.meaning};
        return meanings
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .any(
              (meaning) => find
                  .descendant(
                    of: find.byKey(ValueKey('question-$question')),
                    matching: find.text(meaning),
                  )
                  .evaluate()
                  .isNotEmpty,
            );
      }

      final clues = savedWords.where((w) => matchesClue(w, 0)).toList();
      expect(clues.length, 1);
      final correct = clues.single;
      final options = find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('option-'),
      );
      final wrong = options
          .evaluate()
          .map((e) => e.widget.key!)
          .firstWhere((k) => k != ValueKey('option-${correct.id}'));
      await t.ensureVisible(find.byKey(wrong));
      await t.tap(find.byKey(wrong));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Yana bir bor urinib ko‘ring.'), findsOneWidget);
      final feedback = t.widgetList<Transform>(
        find.descendant(
          of: find.byType(AnswerMotion),
          matching: find.byType(Transform),
        ),
      );
      expect(
        feedback.any((w) => w.transform.storage[12].abs() > .1),
        true,
        reason: 'Wrong answer must visibly shake',
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(ValueKey('option-${correct.id}')));
      await t.tap(find.byKey(ValueKey('option-${correct.id}')));
      await settleDb(t);
      expect(
        find.text('Topdingiz! Bu so‘zni tezroq qaytaramiz.'),
        findsOneWidget,
      );
      final events = await t.runAsync(
        () => store.user.query(
          'events',
          where: 'word_id=?',
          whereArgs: [correct.id],
        ),
      );
      expect(events!.length, 1);
      expect(events.single['grade'], 0);
      await t.drag(find.byType(ListView).first, const Offset(0, -260));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Keyingi so‘z'));
      await t.pumpAndSettle();
      await t.tap(find.text('Keyingi so‘z'));
      await t.pumpAndSettle();
      expect(find.text('Savol 2 / 10'), findsOneWidget);
      // A completed round offers the actual missed words, not unrelated random practice.
      for (var question = 2; question <= 10; question++) {
        final answer = savedWords.singleWhere(
          (w) => matchesClue(w, question - 1),
        );
        await t.ensureVisible(find.byKey(ValueKey('option-${answer.id}')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(ValueKey('option-${answer.id}')));
        await settleDb(t);
        final next = find.text(
          question == 10 ? 'Natijani ko‘rish' : 'Keyingi so‘z',
        );
        await t.ensureVisible(next);
        await t.pumpAndSettle();
        await t.tap(next);
        await t.pumpAndSettle();
      }
      expect(find.text('Qayta ko‘riladigan so‘zlar'), findsOneWidget);
      expect(find.text(correct.lemma), findsOneWidget);
      await shot(t, 'test/goldens/game_review.png');
      t.view.physicalSize = const Size(320, 740);
      t.platformDispatcher.textScaleFactorTestValue = 2;
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Shu so‘zlarni qaytarish'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      t.platformDispatcher.clearTextScaleFactorTestValue();
      t.view.physicalSize = const Size(390, 844);
      await t.pumpAndSettle();

      final beforeRetry = await t.runAsync(
        () => store.user.query(
          'saved',
          where: 'word_id=?',
          whereArgs: [correct.id],
        ),
      );
      await t.ensureVisible(find.text('Shu so‘zlarni qaytarish'));
      await t.pumpAndSettle();
      await t.tap(find.text('Shu so‘zlarni qaytarish'));
      await t.pumpAndSettle();
      expect(find.text('Savol 1 / 1'), findsOneWidget);
      await t.ensureVisible(find.byKey(ValueKey('option-${correct.id}')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('option-${correct.id}')));
      await settleDb(t);
      final afterRetry = await t.runAsync(
        () => store.user.query(
          'saved',
          where: 'word_id=?',
          whereArgs: [correct.id],
        ),
      );
      expect(
        afterRetry!.single['due'],
        beforeRetry!.single['due'],
        reason: 'Immediate retry must not inflate a future review interval',
      );

      // All eight pair cards can be reached at normal font size.
      await t.pumpWidget(host(const PairGameScreen()));
      await settleDb(
        t,
        until: () => find.byKey(const ValueKey('pair-0')).evaluate().isNotEmpty,
      );
      await shot(t, 'test/goldens/pair_game.png');
      await t.ensureVisible(find.byKey(const ValueKey('pair-0')));
      await t.tap(find.byKey(const ValueKey('pair-0')));
      await t.ensureVisible(find.byKey(const ValueKey('pair-4')));
      await t.tap(find.byKey(const ValueKey('pair-4')));
      await settleDb(t);
      expect(find.byKey(const ValueKey('matched-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('matched-4')), findsOneWidget);
      expect(t.takeException(), isNull);

      // Contacts open the exact external address; test never makes a real call.
      final launched = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              if (call.method == 'launch') {
                launched.add((call.arguments as Map)['url'] as String);
                return true;
              }
              return true;
            },
          );
      expect(await SupportContact.open(SupportContact.telegram), true);
      expect(await SupportContact.open(SupportContact.phone), true);
      expect(launched, ['https://t.me/davlatyoruz', 'tel:+998934920107']);
      await t.pumpWidget(
        host(GameFinish(correct: 8, total: 10, points: 116, replay: () {})),
      );
      await t.runAsync(
        () => Directory('test/motion_frames').create(recursive: true),
      );
      for (var i = 0; i < 24; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await shot(
          t,
          'test/motion_frames/frame-${i.toString().padLeft(2, '0')}.png',
        );
      }

      // Scroll through every main screen at 320px with 200% text, without hiding errors.
      t.view.physicalSize = const Size(320, 740);
      final teacher = await t.runAsync(() => store.lookup('teacher'));
      final pages = <Widget>[
        HomeScreen(onTab: (_) {}),
        const LearnScreen(),
        const ProfileScreen(),
        const AccountScreen(),
        const AccountScreen(changePassword: true),
        ...[0, 1, 2, 3].map((mode) => OnlineToolScreen(mode: mode)),
        const PicturesScreen(),
        const DictionaryScreen(),
        WordScreen(word: teacher!),
        const ToolsScreen(),
        const VocabularyScreen(),
        const MemoryGameScreen(),
        const PairGameScreen(),
        const GrammarScreen(),
        LessonScreen(lesson: lessons.first),
        const DataInfoScreen(),
        const TranslatorScreen(),
        const PronunciationScreen(),
        ...[0, 1, 2, 4].map((mode) => QuizScreen(mode: mode)),
      ];
      for (final page in pages) {
        await t.pumpWidget(host(page, scale: 2, reduced: true));
        await settleDb(t);
        expect(
          t.takeException(),
          isNull,
          reason: '${page.runtimeType} initial at 320px / 200%',
        );
        debugPrint('QA: Layout ${page.runtimeType}');
        final scroll = find
            .byWidgetPredicate(
              (w) =>
                  w is Scrollable &&
                  (w.axisDirection == AxisDirection.down ||
                      w.axisDirection == AxisDirection.up),
            )
            .first;
        for (var i = 0; i < 7; i++) {
          await t.drag(scroll, const Offset(0, -450));
          await t.pumpAndSettle();
          expect(
            t.takeException(),
            isNull,
            reason: '${page.runtimeType} scroll $i at 320px / 200%',
          );
        }
      }
      await t.pumpWidget(
        host(
          GameFinish(correct: 3, total: 4, points: 33, replay: () {}),
          scale: 2,
          reduced: true,
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        await store.dict.close();
        await store.user.close();
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: Platform.isWindows,
  );
}

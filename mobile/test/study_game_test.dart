import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/core/study_game.dart';
import 'package:lingoy/screens/study_game.dart';
import 'package:lingoy/ui/design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudyBank bank;
  setUpAll(() async {
    bank = StudyBank(
      jsonDecode(await rootBundle.loadString('assets/quiz_bank.json'))
          as Map<String, dynamic>,
    );
  });
  test(
    'Start has usable verb synonyms and separately selectable noun meanings',
    () {
      final w = bank.byLemma['start']!;
      expect(w.choices, contains('begin'));
      expect(w.context, 'boshlamoq; boshlab yubormoq');
      for (var i = 0; i < 20; i++) {
        final q = generateSynonymOptions(w, bank, random: Random(i));
        expect(q, isNotNull);
        expect(w.choices, contains(q!.correct));
        expect(q.context, w.context);
      }
      final noun = w.withMeaning(
        w.meanings.firstWhere((s) => s.choices.contains('beginning')),
      );
      expect(noun.choices, isNot(contains('begin')));
      expect(w.choices, contains('begin'));
    },
  );
  test(
    'Synonym options exclude legitimate synonyms and use close spellings',
    () {
      for (final lemma in ['big', 'large', 'lullaby']) {
        final word = bank.byLemma[lemma]!;
        for (var i = 0; i < 12; i++) {
          final q = generateSynonymOptions(word, bank, random: Random(i));
          expect(q, isNotNull, reason: lemma);
          expect(q!.options.length, 4);
          expect(q.options.map((o) => o.text).toSet().length, 4);
          for (final o in q.options.where((o) => o.text != q.correct)) {
            expect(word.synonyms, isNot(contains(o.text)));
            expect(similarity(q.correct, o.text), greaterThanOrEqualTo(45));
            expect(o.meaning, isNotEmpty);
          }
        }
      }
    },
  );
  test(
    'Translate tests meaning and non-word spelling, in all four positions',
    () {
      final positions = <int>{};
      for (var i = 0; i < 80; i++) {
        final q = generateTranslateOptions(
          bank.byLemma['receive']!,
          bank,
          random: Random(i),
        )!;
        positions.add(q.options.indexWhere((o) => o.kind == 'correct'));
        final typo = q.options.firstWhere((o) => o.kind == 'spelling');
        expect(typo.text, 'recieve');
        expect(bank.valid.contains(typo.text), false);
        expect(typo.explanation, contains('«ie» o‘rniga «ei»'));
        expect(q.options.where((o) => o.kind == 'word').length, 2);
      }
      expect(positions.length, 4);
    },
  );
  test(
    'One word can start, repeated prompts and synonym-free words are handled',
    () {
      final w = bank.byLemma['receive']!;
      expect(prepareSession('translate', [w], bank).length, 1);
      expect(prepareSession('translate', [w, w], bank).length, 1);
      expect(prepareSession('translate', [], bank), isEmpty);
      expect(
        generateSynonymOptions(
          const StudyWord(id: 1, lemma: 'example', translation: 'misol'),
          bank,
        ),
        null,
      );
    },
  );
  test('Ordinary questions never add a vulgar surprise distractor', () {
    expect(bank.byLemma.containsKey('shit'), true);
    for (var i = 0; i < 12; i++) {
      final q = generateTranslateOptions(
        const StudyWord(id: 1, lemma: 'sit', translation: 'o‘tirmoq'),
        bank,
        random: Random(i),
      );
      expect(q, isNotNull);
      expect(q!.options.any((o) => o.text == 'shit'), false);
    }
  });
  test('Polysemous answers cannot borrow an unrelated primary gloss', () {
    expect(
      generateSynonymOptions(
        const StudyWord(
          id: 1,
          lemma: 'run',
          translation: 'yugurmoq',
          groups: ['v1', 'n1'],
          synonyms: ['tally'],
          choices: ['tally'],
        ),
        bank,
      ),
      isNull,
    );
    final w = StudyWord.detail(
      {'id': 1, 'lemma': 'run', 'translation': 'yugurmoq'},
      [
        {'id': 'v1', 'words': '["run"]'},
        {'id': 'n1', 'words': '["run","tally"]'},
      ],
    );
    expect(w.choices, ['tally']);
    expect(generateSynonymOptions(w, bank), isNull);
  });
  testWidgets(
    'Correct answer shows only Continue; wrong answer explains and cannot score twice',
    (t) async {
      final q = generateTranslateOptions(
        bank.byLemma['receive']!,
        bank,
        random: Random(4),
      )!;
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(false),
          home: StudyGameScreen(
            mode: 'translate',
            questions: [q],
            onAnswer: (_, _) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final right = q.options.indexWhere((o) => o.text == q.correct);
      await t.tap(find.byKey(ValueKey('study-option-$right')));
      await t.pumpAndSettle();
      expect(find.text('Davom etish'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-explanation')), findsNothing);
      expect(find.textContaining('To‘g‘ri!'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      final wrong = q.options.indexWhere((o) => o.kind == 'spelling');
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          home: StudyGameScreen(
            mode: 'translate',
            questions: [q],
            onAnswer: (_, _) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('study-option-$wrong')));
      await t.pumpAndSettle();
      expect(find.text(q.options[wrong].explanation), findsOneWidget);
      expect(find.text('Davom etish'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(ValueKey('study-option-$right')))
            .onPressed,
        isNull,
      );
      store.accountId = 'changed-account';
      store.notifyListeners();
      await t.pumpAndSettle();
      expect(
        find.text('Akkaunt o‘zgardi. Yangi o‘yin boshlang.'),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('study-option-$right')), findsNothing);
      store.accountId = null;
      expect(t.takeException(), isNull);
    },
  );
}

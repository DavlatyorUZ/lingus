import 'package:flutter_test/flutter_test.dart';
import 'package:lingoy/core/models.dart';
import 'package:lingoy/core/grammar_checker.dart';

void main() {
  test(
    'Uzbek apostrophe and optional Latin variants normalize identically',
    () {
      expect(normalize(' OʻQUVCHI '), normalize("o'quvchi"));
      expect(normalize('ğöşç'), "g'o'shch");
    },
  );
  test('SM2 lapse resets and schedules ten minutes, not a full day', () {
    final now = DateTime(2026, 11, 15, 10);
    final r = scheduleReview(
      grade: 0,
      repetitions: 4,
      interval: 24,
      ease: 1.3,
      now: now,
    );
    expect(r.repetitions, 0);
    expect(r.ease, 1.3);
    expect(r.due.difference(now), const Duration(minutes: 10));
  });
  test('SM2 successful progression and ease floor persist', () {
    final now = DateTime(2026);
    final a = scheduleReview(
      grade: 2,
      repetitions: 0,
      interval: 0,
      ease: 2.5,
      now: now,
    );
    final b = scheduleReview(
      grade: 2,
      repetitions: a.repetitions,
      interval: a.interval,
      ease: a.ease,
      now: now,
    );
    final c = scheduleReview(
      grade: 2,
      repetitions: b.repetitions,
      interval: b.interval,
      ease: b.ease,
      now: now,
    );
    expect(a.interval, 1);
    expect(b.interval, 6);
    expect(c.interval, 15);
    expect(c.repetitions, 3);
    expect(
      () => scheduleReview(
        grade: 9,
        repetitions: 0,
        interval: 0,
        ease: 2.5,
        now: now,
      ),
      throwsArgumentError,
    );
  });
  test('Grammar checks return exact applicable offsets and corrections', () {
    const s = 'She don’t like apples. I have went to school.';
    final issues = checkGrammar(s);
    expect(issues.length, 2);
    expect(
      issues.map((e) => e.replacement),
      containsAll(['She doesn’t', 'have gone']),
    );
    for (final i in issues) {
      expect(s.substring(i.start, i.end), i.original);
    }
  });
  test(
    'Valid questions and lexical exceptions avoid agreement false positives',
    () {
      for (final text in [
        'Does he have a book?',
        'Can she go home?',
        'I study at a university.',
        'She is an honest person.',
        'They have gone home.',
        'I agree with you.',
      ]) {
        expect(checkGrammar(text), isEmpty, reason: text);
      }
    },
  );
  test('Conjugation, articles, plurals and comparatives', () {
    for (final text in [
      'I is ready.',
      'He have a book.',
      'Did she went home?',
      'a apple',
      'an university',
      'more better',
      'many informations',
      'looking forward to hear from you',
    ]) {
      expect(checkGrammar(text), isNotEmpty, reason: text);
    }
  });
}

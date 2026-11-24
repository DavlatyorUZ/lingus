import 'package:flutter_test/flutter_test.dart';
import 'package:lingoy/core/grammar_checker.dart';

void main() {
  test('Valid context, code and possessives do not get rewritten', () {
    for (final text in [
      'She is married with two children.',
      'They have lived here since 2 years ago.',
      'Your welcome speech was kind.',
      'I am boring, but I am honest.',
      "One of my friend's books is here.",
      'She is good in English class.',
      '`I is ready`',
      '```\nShe don\'t like it.\n```',
      'She `is` go home.',
      'Your welcome message was helpful.',
    ]) {
      expect(checkGrammar(text), isEmpty, reason: text);
    }
  });
  test('New corrections retain exact ranges and can be applied together', () {
    for (final pair in {
      'She am ready.': 'She is ready.',
      'There is many books.': 'There are many books.',
      'There are a book.': 'There is a book.',
      'She does not likes apples.': 'She does not like apples.',
      'I should of known.': 'I should have known.',
      'He used to went there.': 'He used to go there.',
      'a children': 'a child',
      'two childs': 'two children',
      'one of my friend': 'one of my friends',
      'I listen music.': 'I listen to music.',
    }.entries) {
      expect(
        applyGrammarIssues(pair.key, checkGrammar(pair.key)),
        pair.value,
        reason: pair.key,
      );
    }
    const text = '🙂 I is ready. She am here.';
    expect(
      applyGrammarIssues(text, checkGrammar(text)),
      '🙂 I am ready. She is here.',
    );
  });
  test('Applying a stale suggestion cannot overwrite changed text', () {
    final issues = checkGrammar('I is ready.');
    expect(
      () => applyGrammarIssues('I am ready.', issues),
      throwsArgumentError,
    );
  });
}

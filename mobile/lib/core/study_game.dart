import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'lexical_presentation.dart';

String _norm(String s) => s.toLowerCase().replaceAll('_', ' ').trim();

final _sensitiveDistractor = RegExp(
  r"qo[‘’ʻʼ']pol|haqorat|so[‘’ʻʼ']kinish|\bjinsiy\b|\bqin\b|\bnajas\b",
  caseSensitive: false,
);

class StudyWord {
  final int id;
  final String lemma, translation, context;
  final List<String> groups, synonyms, choices;
  final List<StudyMeaning> meanings;
  final String senseId;
  const StudyWord({
    required this.id,
    required this.lemma,
    required this.translation,
    this.context = '',
    this.groups = const [],
    this.synonyms = const [],
    this.choices = const [],
    this.meanings = const [],
    this.senseId = '',
  });
  factory StudyWord.from(Map<String, dynamic> m) => StudyWord(
    id: m['id'] as int,
    lemma: m['lemma'] as String,
    translation: m['translation'] as String? ?? '',
    context: m['context'] as String? ?? '',
    groups: (m['groups'] as List? ?? []).cast<String>(),
    synonyms: (m['synonyms'] as List? ?? []).cast<String>(),
    choices: (m['choices'] as List? ?? []).cast<String>(),
    senseId: m['senseId'] as String? ?? '',
    meanings: (m['meanings'] as List? ?? [])
        .map((s) => StudyMeaning.from((s as Map).cast<String, dynamic>()))
        .toList(),
  );
  StudyWord withMeaning(StudyMeaning sense) => StudyWord(
    id: id,
    lemma: lemma,
    translation: translation,
    groups: groups,
    synonyms: synonyms,
    choices: sense.choices,
    context: sense.context,
    meanings: meanings,
    senseId: sense.id,
  );
  static StudyWord detail(
    Map<String, dynamic> word,
    List<Map<String, Object?>> senses,
  ) {
    List<String> words(Map<String, Object?> s) =>
        (jsonDecode(s['words'] as String) as List)
            .cast<String>()
            .map(_norm)
            .where((w) => w != _norm(word['lemma'] as String))
            .toList();
    final meanings = senses
        .map(
          (s) => StudyMeaning(
            id: s['id'] as String,
            pos: s['pos'] as String? ?? '',
            definition: s['definition'] as String? ?? '',
            context: s['meaning_uz'] as String? ?? '',
            choices: senseSynonyms(
              word['lemma'] as String,
              s,
            ).map(_norm).toList(),
          ),
        )
        .where((s) => s.choices.isNotEmpty)
        .toList();
    final result = StudyWord(
      id: word['id'] as int,
      lemma: word['lemma'] as String,
      translation: word['translation'] as String? ?? '',
      groups: senses.map((s) => s['id'] as String).toList(),
      synonyms: senses.expand(words).toSet().toList(),
      meanings: meanings,
    );
    if (meanings.isEmpty) return result;
    final glosses = result.translation
        .split(';')
        .map(_norm)
        .where((s) => s.isNotEmpty)
        .toList();
    int score(StudyMeaning sense) {
      final parts = sense.context.split(';').map(_norm).toSet();
      for (var i = 0; i < glosses.length; i++) {
        if (parts.contains(glosses[i])) return glosses.length - i + 1;
      }
      return 0;
    }

    var first = meanings.first;
    for (final sense in meanings.skip(1)) {
      if (score(sense) > score(first)) first = sense;
    }
    return result.withMeaning(first);
  }
}

class StudyMeaning {
  final String id, pos, definition, context;
  final List<String> choices;
  const StudyMeaning({
    required this.id,
    required this.pos,
    required this.definition,
    required this.context,
    required this.choices,
  });
  factory StudyMeaning.from(Map<String, dynamic> m) => StudyMeaning(
    id: m['id'] as String,
    pos: m['pos'] as String? ?? '',
    definition: m['definition'] as String? ?? '',
    context: m['context'] as String? ?? '',
    choices: (m['choices'] as List).cast<String>(),
  );
}

class StudyOption {
  final String text, meaning, kind, explanation;
  const StudyOption(this.text, this.meaning, this.kind, this.explanation);
}

class StudyQuestion {
  final StudyWord word;
  final String question, context, correct;
  final List<StudyOption> options;
  const StudyQuestion(
    this.word,
    this.question,
    this.context,
    this.correct,
    this.options,
  );
}

class StudyBank {
  final List<StudyWord> entries;
  final Set<String> valid;
  final Map<String, List<String>> misspellings;
  late final Map<String, StudyWord> byLemma = {
    for (final w in entries) w.lemma: w,
  };
  StudyBank(Map<String, dynamic> json)
    : entries = (json['entries'] as List)
          .map((w) => StudyWord.from((w as Map).cast<String, dynamic>()))
          .toList(),
      valid = (json['validWords'] as List).cast<String>().toSet(),
      misspellings = (json['typicalMisspellings'] as Map).map(
        (k, v) => MapEntry(k as String, (v as List).cast<String>()),
      );
  static Future<StudyBank>? _loaded;
  static Future<StudyBank> load() => _loaded ??= rootBundle
      .loadString('assets/quiz_bank.json')
      .then((s) => StudyBank(jsonDecode(s) as Map<String, dynamic>))
      .catchError((Object e) {
        _loaded = null;
        throw e;
      });
}

int editDistance(String a, String b) {
  var row = List.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final next = [i];
    for (var j = 1; j <= b.length; j++) {
      next.add(
        min(
          min(row[j] + 1, next[j - 1] + 1),
          row[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ),
      );
    }
    row = next;
  }
  return row[b.length];
}

// Normalize Uzbek apostrophes and common derivations; generic verbs are not evidence.
Set<String> _meaningTerms(String s) => s
    .toLowerCase()
    .replaceAll(RegExp("[‘’ʻʼ`]"), "'")
    .split(RegExp("[^a-z']+"))
    .map((w) => w.replaceFirst(RegExp(r'(moq|uvchi|ish|lik)$'), ''))
    .where(
      (w) =>
          w.length > 2 &&
          !{
            'bir',
            'bilan',
            'uchun',
            'emas',
            'yoki',
            'holda',
            'juda',
            'nisbatan',
            "qo'pol",
            'norasmiy',
            "bo'l",
            'qil',
            'et',
            'odam',
            'kishi',
            'narsa',
          }.contains(w),
    )
    .toSet();
bool _meaningOverlap(String a, String b) =>
    _meaningTerms(a).intersection(_meaningTerms(b)).isNotEmpty;
String _synonymMeaning(StudyWord word, StudyWord? target) {
  if (word.context.isNotEmpty) return word.context;
  if (word.groups.length <= 1) {
    return word.translation.isNotEmpty
        ? word.translation
        : target?.translation ?? '';
  }
  for (final part in word.translation.split(';')) {
    if (_meaningOverlap(part, target?.translation ?? '')) return part.trim();
  }
  return '';
}

String _phonetic(String w) => w
    .replaceAll('ph', 'f')
    .replaceAll('kn', 'n')
    .replaceAll('ck', 'k')
    .replaceAll(RegExp('[aeiouy]'), '')
    .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
int similarity(String a, String b) {
  var prefix = 0, suffix = 0;
  while (prefix < min(a.length, b.length) && a[prefix] == b[prefix]) {
    prefix++;
  }
  while (suffix < min(a.length, b.length) &&
      a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) {
    suffix++;
  }
  return 100 -
      12 * editDistance(a, b) +
      min(prefix, 4) * 4 +
      min(suffix, 4) * 3 +
      (_phonetic(a) == _phonetic(b) ? 20 : 0);
}

bool _sameWordFamily(String a, String b) {
  final base = a.length <= b.length ? a : b,
      longer = a.length <= b.length ? b : a;
  if (longer.endsWith(base) &&
      {
        'en',
        're',
        'un',
        'dis',
        'over',
        'under',
        'mis',
      }.contains(longer.substring(0, longer.length - base.length))) {
    return true;
  }
  if (!longer.startsWith(base)) return false;
  return {
    's',
    'es',
    'ed',
    'ing',
    'ly',
    'ness',
    'less',
    'ful',
    'er',
    'est',
    if (base.endsWith('e')) ...['r', 'st'],
  }.contains(longer.substring(base.length));
}

List<StudyWord> _candidates(
  StudyWord word,
  String correct,
  StudyBank bank,
  Random random,
) {
  final target = bank.byLemma[correct],
      banned = {
        _norm(word.lemma),
        correct,
        ...word.synonyms,
        ...?target?.synonyms,
      },
      groups = {...word.groups, ...?target?.groups};
  for (final lemma in banned.toList()) {
    banned.addAll(bank.byLemma[lemma]?.synonyms ?? const <String>[]);
  }
  final matches =
      bank.entries
          .where(
            (w) =>
                !banned.contains(w.lemma) &&
                (w.lemma.length - correct.length).abs() <= 4 &&
                similarity(correct, w.lemma) >= 45 &&
                !_sameWordFamily(correct, w.lemma) &&
                w.translation.isNotEmpty &&
                !_sensitiveDistractor.hasMatch(w.translation) &&
                w.translation != word.translation &&
                w.translation != target?.translation &&
                !_meaningOverlap(w.translation, word.translation) &&
                !_meaningOverlap(w.translation, target?.translation ?? '') &&
                !w.groups.any(groups.contains),
          )
          .map(
            (w) => (w, similarity(correct, w.lemma) + random.nextDouble() * 4),
          )
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
  return matches.take(3).map((e) => e.$1).toList();
}

String? _spelling(String word, StudyBank bank) {
  final list = [...?bank.misspellings[word]];
  for (var i = 0; i < word.length - 1; i++) {
    list.add(
      '${word.substring(0, i)}${word[i + 1]}${word[i]}${word.substring(i + 2)}',
    );
  }
  for (var i = 0; i < word.length; i++) {
    list.add(word.substring(0, i) + word.substring(i + 1));
    list.add(word.substring(0, i) + word[i] + word.substring(i));
  }
  if (word.isNotEmpty) {
    list.add(word + word[word.length - 1]);
    list.add('${word}e');
  }
  for (final w in list) {
    if (w != word &&
        w.length > 1 &&
        !bank.valid.contains(w) &&
        RegExp(r"^[a-z]+(?:[ '-][a-z]+){0,5}$").hasMatch(w) &&
        w.split(RegExp(r"[ '-]")).any((t) => !bank.valid.contains(t))) {
      return w;
    }
  }
  return null;
}

String _spellingDetail(String correct, String wrong) {
  var a = 0, b = 0;
  while (a < min(correct.length, wrong.length) && correct[a] == wrong[a]) {
    a++;
  }
  while (b < min(correct.length, wrong.length) - a &&
      correct[correct.length - 1 - b] == wrong[wrong.length - 1 - b]) {
    b++;
  }
  final x = wrong.substring(a, wrong.length - b),
      y = correct.substring(a, correct.length - b);
  return x.isNotEmpty && y.isNotEmpty
      ? '«$x» o‘rniga «$y» yoziladi'
      : x.isNotEmpty
      ? '«$x» ortiqcha yozilgan'
      : '«$y» tushib qolgan';
}

String _brief(String s) {
  final text = s.split(';').take(2).join('; ');
  return text.length > 120 ? text.substring(0, 120).trim() : text;
}

StudyOption _real(StudyWord w, String correct, String meaning) => StudyOption(
  w.lemma,
  w.translation,
  'word',
  '«${w.lemma}» — ${_brief(w.translation)}; yozilishi o‘xshash, ma’nosi boshqa. To‘g‘ri javob «$correct» — ${_brief(meaning)}.',
);
StudyQuestion? generateSynonymOptions(
  StudyWord word,
  StudyBank bank, {
  Random? random,
}) {
  final rng = random ?? Random(),
      choices =
          word.choices
              .where(
                (w) =>
                    RegExp(r'^[a-z]+(?: [a-z]+){0,2}$').hasMatch(w) &&
                    w != _norm(word.lemma),
              )
              .toList()
            ..shuffle(rng);
  for (final correct in choices) {
    final meaning = _synonymMeaning(word, bank.byLemma[correct]);
    if (meaning.isEmpty) continue;
    final others = _candidates(word, correct, bank, rng);
    if (others.length < 3) continue;
    final options = [
      StudyOption(correct, meaning, 'correct', ''),
      ...others.map((w) => _real(w, correct, meaning)),
    ]..shuffle(rng);
    return StudyQuestion(word, word.lemma, meaning, correct, options);
  }
  return null;
}

StudyQuestion? generateTranslateOptions(
  StudyWord word,
  StudyBank bank, {
  Random? random,
}) {
  final rng = random ?? Random(),
      correct = _norm(word.lemma),
      typo = _spelling(correct, bank),
      others = _candidates(word, correct, bank, rng);
  if (word.translation.isEmpty || typo == null || others.length < 2) {
    return null;
  }
  final options = [
    StudyOption(correct, word.translation, 'correct', ''),
    StudyOption(
      typo,
      '',
      'spelling',
      '«$typo» imlosida ${_spellingDetail(correct, typo)}. To‘g‘risi «$correct» — ${_brief(word.translation)}.',
    ),
    ...others.take(2).map((w) => _real(w, correct, word.translation)),
  ]..shuffle(rng);
  return StudyQuestion(word, word.translation, '', correct, options);
}

List<StudyQuestion> prepareSession(
  String mode,
  List<StudyWord> words,
  StudyBank bank, {
  Random? random,
}) {
  final rng = random ?? Random(),
      ordered = [...words]..shuffle(rng),
      seen = <String>{},
      sets = <String>{},
      out = <StudyQuestion>[];
  for (final word in ordered) {
    final q = mode == 'synonyms'
        ? generateSynonymOptions(word, bank, random: rng)
        : generateTranslateOptions(word, bank, random: rng);
    if (q == null) {
      continue;
    }
    final set = q.options.map((o) => o.text).toList()..sort();
    if (seen.contains(_norm(q.question)) || sets.contains(set.join('|'))) {
      continue;
    }
    seen.add(_norm(q.question));
    sets.add(set.join('|'));
    out.add(q);
  }
  return out;
}

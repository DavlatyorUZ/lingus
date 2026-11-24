import 'dart:convert';

List<dynamic> lexicalList(Object? value) {
  try {
    final decoded = value is String ? jsonDecode(value) : value;
    return decoded is List ? decoded : [];
  } catch (_) {
    return [];
  }
}

String lexicalKey(String value) => value
    .toLowerCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// A synonym belongs to this exact meaning, never to the union of senses.
List<String> senseSynonyms(String lemma, Map<String, Object?> sense) {
  final words = lexicalList(sense['words']).whereType<String>().toList();
  if (!words.any((w) => lexicalKey(w) == lexicalKey(lemma))) return [];
  final seen = <String>{lexicalKey(lemma)};
  final result = <String>[];
  for (final raw in words) {
    final word = raw.replaceAll('_', ' ').trim(), key = lexicalKey(raw);
    if (word.isEmpty ||
        word.length > 80 ||
        RegExp(r'[<>\n\r{}\[\]]').hasMatch(word) ||
        !seen.add(key)) {
      continue;
    }
    result.add(word);
    if (result.length == 6) break;
  }
  return result;
}

class SenseExample {
  final String en;
  final String? uz;
  const SenseExample(this.en, [this.uz]);
}

/// Prefer an existing statement, negative and question; do not invent grammar.
List<SenseExample> senseExamples(Map<String, Object?> sense) {
  final candidates = <SenseExample>[];
  final seen = <String>{};
  void add(String en, String? uz) {
    en = en.trim();
    final key = lexicalKey(en).replaceFirst(RegExp(r'[.!]+$'), '');
    if (en.isEmpty || en.length > 320 || !seen.add(key)) return;
    candidates.add(SenseExample(en, uz?.trim()));
  }

  for (final row in lexicalList(sense['bilingual_examples']).whereType<Map>()) {
    if (row['en'] is String) {
      add(
        row['en'] as String,
        row['uz'] is String ? row['uz'] as String : null,
      );
    }
  }
  for (final row in lexicalList(sense['examples']).whereType<String>()) {
    add(row, null);
  }
  String type(SenseExample e) => e.en.trim().endsWith('?')
      ? 'question'
      : RegExp(
          r"\bnot\b|n't\b|n’t\b|\bnever\b",
          caseSensitive: false,
        ).hasMatch(e.en)
      ? 'negative'
      : 'positive';
  final result = <SenseExample>[];
  for (final kind in ['positive', 'negative', 'question']) {
    final matching = candidates.where((e) => type(e) == kind);
    if (matching.isNotEmpty) result.add(matching.first);
  }
  for (final e in candidates) {
    if (result.length == 3) break;
    if (!result.contains(e)) result.add(e);
  }
  return result;
}

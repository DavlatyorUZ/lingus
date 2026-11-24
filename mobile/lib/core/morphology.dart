import 'models.dart';

/// Possible morphological analyses, always verified against dictionary POS.
/// This is deterministic offline morphology, not a contextual tense classifier.
class FormRule {
  final String lemma, pos, reason;
  const FormRule(this.lemma, this.pos, this.reason);
}

class BaseForm {
  final String input, pos, meaning, definition;
  final Word word;
  final List<String> reasons;
  const BaseForm({
    required this.input,
    required this.pos,
    required this.word,
    required this.reasons,
    this.meaning = '',
    this.definition = '',
  });
  String get infinitive => pos == 'v' ? 'to ${word.lemma}' : word.lemma;
  bool get unchanged => normalize(input) == normalize(word.lemma);
  String get partOfSpeech =>
      {'v': 'Fe’l', 'n': 'Ot', 'a': 'Sifat', 'r': 'Ravish'}[pos] ?? 'So‘z';
}

class WordAnalysis {
  final String input;
  final Word? direct;
  final List<BaseForm> bases;
  const WordAnalysis(this.input, this.direct, this.bases);
  bool get found => direct != null || bases.isNotEmpty;
}

/// Remove surrounding punctuation without losing an internal possessive.
String normalizeFormInput(String input) {
  var q = normalize(input);
  final punctuation = RegExp(r'^[\s.,!?;:()\[\]{}<>]+|[\s.,!?;:()\[\]{}<>]+$');
  const pairs = {"'": "'", '"': '"', '“': '”', '«': '»', '„': '“'};
  while (q.isNotEmpty) {
    final previous = q;
    q = q.replaceAll(punctuation, '').trim();
    if (q.length >= 2 && pairs[q[0]] == q[q.length - 1]) {
      q = q.substring(1, q.length - 1).trim();
    }
    if (q == previous) break;
  }
  if (q.endsWith("'") && !q.endsWith("s'")) {
    q = q.substring(0, q.length - 1);
  }
  return q;
}

List<String> englishTokens(String input) {
  final text = normalize(input);
  return RegExp(r"[a-z]+(?:'[a-z]+)*'?")
      .allMatches(text)
      .map((m) {
        var token = m[0]!;
        final quoted = m.start > 0 && text[m.start - 1] == "'";
        if (token.endsWith("'") && (quoted || !token.endsWith("s'"))) {
          token = token.substring(0, token.length - 1);
        }
        return token;
      })
      .toSet()
      .toList();
}

List<FormRule> regularForms(String input) {
  final q = normalize(input);
  if (!RegExp(r"^[a-z]+(?:'s|')?$").hasMatch(q)) return [];
  final forms = <FormRule>[];
  void add(String lemma, String pos, String reason) {
    if (lemma.length >= 2 && lemma != q) {
      forms.add(FormRule(lemma, pos, reason));
    }
  }

  bool cvc(String stem) =>
      stem.length >= 3 &&
      RegExp(r'[^aeiou][aeiou][^aeiouwxy]$').hasMatch(stem) &&
      RegExp(r'[aeiouy]+').allMatches(stem).length == 1;
  String undouble(String stem) =>
      RegExp(r'([b-df-hj-np-tv-z])\1$').hasMatch(stem)
      ? stem.substring(0, stem.length - 1)
      : stem;
  void pastOrIng(String suffix, String reason) {
    if (!q.endsWith(suffix) || q.length <= suffix.length + 1) return;
    final stem = q.substring(0, q.length - suffix.length);
    // hop -> hopping; hope -> hoping. Avoid proposing hop for hoping.
    if (!cvc(stem)) add(stem, 'v', reason);
    add(
      '$stem'
          'e',
      'v',
      reason,
    );
    final single = undouble(stem);
    if (single != stem) add(single, 'v', reason);
  }

  pastOrIng('ing', '-ing shakli: davomiy zamon yoki gerundiy/sifatdosh');
  if (q.endsWith('ying')) {
    add('${q.substring(0, q.length - 4)}ie', 'v', '-ing shakli: ie → y');
  }
  pastOrIng('ed', '-ed shakli: o‘tgan zamon yoki sifatdosh');
  if (q.endsWith('ied')) {
    add('${q.substring(0, q.length - 3)}y', 'v', 'O‘tgan zamon: y → ied');
  }
  if (q.endsWith('s') &&
      !q.endsWith('ss') &&
      !q.endsWith('us') &&
      !q.endsWith('is')) {
    final stem = q.substring(0, q.length - 1);
    add(stem, 'v', 'Hozirgi zamon: 3-shaxs birlik');
    add(stem, 'n', 'Ko‘plik shakli');
  }
  if (q.endsWith('ies')) {
    final stem = '${q.substring(0, q.length - 3)}y';
    add(stem, 'v', 'Hozirgi zamon: y → ies');
    add(stem, 'n', 'Ko‘plik: y → ies');
  }
  if (RegExp(r'(ches|shes|sses|xes|zes|oes)$').hasMatch(q)) {
    final stem = q.substring(0, q.length - 2);
    add(stem, 'v', 'Hozirgi zamon: -es');
    add(stem, 'n', 'Ko‘plik: -es');
  }
  for (final suffix in ['er', 'est']) {
    if (q.endsWith(suffix) && q.length > suffix.length + 1) {
      final stem = q.substring(0, q.length - suffix.length);
      final label = suffix == 'er' ? 'Qiyosiy daraja' : 'Orttirma daraja';
      for (final pos in ['a', 'r']) {
        add(stem, pos, label);
        add('${stem}e', pos, label);
        add(undouble(stem), pos, label);
        if (stem.endsWith('i')) {
          add('${stem.substring(0, stem.length - 1)}y', pos, label);
        }
      }
    }
  }
  const contractions = {
    "it's",
    "he's",
    "she's",
    "that's",
    "what's",
    "who's",
    "there's",
    "here's",
    "let's",
  };
  if (q.endsWith("'s") && !contractions.contains(q)) {
    add(q.substring(0, q.length - 2), 'n', 'Egalik shakli');
  }
  if (q.endsWith("s'")) {
    final base = q.substring(0, q.length - 1);
    add(base, 'n', 'Ko‘plikdagi egalik shakli');
    for (final item in regularForms(base).where((f) => f.pos == 'n')) {
      add(item.lemma, 'n', 'Ko‘plikdagi egalik shakli');
    }
  }
  return forms;
}

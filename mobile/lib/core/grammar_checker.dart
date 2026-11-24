/// Conservative English checks. Deterministic rules, not an AI or a full parser.
class GrammarIssue {
  final int start, end;
  final String original, replacement, explanation;
  const GrammarIssue(
    this.start,
    this.end,
    this.original,
    this.replacement,
    this.explanation,
  );
}

class _Rule {
  final String pattern, explanation;
  final String Function(RegExpMatch) correction;
  final bool Function(String, RegExpMatch)? when;
  const _Rule(this.pattern, this.correction, this.explanation, {this.when});
}

String _case(String old, String next) =>
    old.isNotEmpty && old[0] == old[0].toUpperCase()
    ? '${next[0].toUpperCase()}${next.substring(1)}'
    : next;
final _rules = <_Rule>[
  _Rule(r'\bi\s+is\b', (m) => 'I am', 'I olmoshi bilan am ishlatiladi.'),
  _Rule(r'\bi\s+are\b', (m) => 'I am', 'I olmoshi bilan am ishlatiladi.'),
  _Rule(
    r'\byou\s+is\b',
    (m) => _case(m[0]!, 'you are'),
    'You olmoshi bilan are ishlatiladi.',
  ),
  _Rule(
    r'\b(we|they)\s+is\b',
    (m) => '${m[1]} are',
    'We va they bilan are ishlatiladi.',
  ),
  _Rule(
    r'\b(he|she|it)\s+are\b',
    (m) => '${m[1]} is',
    'He, she va it bilan is ishlatiladi.',
  ),
  _Rule(
    r'\b(we|they|you)\s+was\b',
    (m) => '${m[1]} were',
    'Standart ingliz tilida we, they, you bilan were ishlatiladi.',
  ),
  _Rule(
    r'\b(he|she|it)\s+don[’\x27]t\b',
    (m) => '${m[1]} doesn’t',
    'Present Simple inkorida he/she/it uchun doesn’t kerak.',
  ),
  _Rule(
    r'\b(i|we|they|you)\s+doesn[’\x27]t\b',
    (m) => '${m[1]} don’t',
    'I, we, they, you bilan don’t ishlatiladi.',
  ),
  _Rule(
    r'(^|[.!?]\s+)(he|she|it)\s+have\b',
    (m) => '${m[1]}${m[2]} has',
    'Gap boshidagi he/she/it uchun oddiy hozirgi zamonda has ishlatiladi.',
  ),
  _Rule(
    r'(^|[.!?]\s+)(we|they|you|i)\s+has\b',
    (m) => '${m[1]}${m[2]} have',
    'I, we, they, you bilan have ishlatiladi.',
  ),
  _Rule(
    r'\b(am|is|are)\s+agree\b',
    (m) => m[1]!.toLowerCase() == 'is' ? 'agrees' : 'agree',
    'Agree fe’lidan oldin bu tuzilmada be ishlatilmaydi: I agree.',
  ),
  _Rule(
    r'\b(can|could|must|should|would|will|may|might)\s+to\s+(\w+)\b',
    (m) => '${m[1]} ${m[2]}',
    'Modal fe’ldan keyin fe’l to-siz keladi.',
  ),
  _Rule(
    r'\bmore\s+(better|easier|faster|bigger|smaller|worse)\b',
    (m) => m[1]!,
    'Ikki qiyosiy shakl birga qo‘llanmaydi.',
  ),
  _Rule(
    r'\bmost\s+(best|worst|easiest|fastest|biggest)\b',
    (m) => m[1]!,
    'Ikki orttirma shakl birga qo‘llanmaydi.',
  ),
  _Rule(
    r'\ba\s+(apple|orange|egg|umbrella|hour|honest person|engineer)\b',
    (m) => _case(m[0]!, 'an ${m[1]}'),
    'Bu birikmada keyingi so‘z unli tovushdan boshlanadi: an.',
  ),
  _Rule(
    r'\ban\s+(university|European|book|car|house|student|teacher)\b',
    (m) => _case(m[0]!, 'a ${m[1]}'),
    'Bu birikmada keyingi so‘z undosh tovushdan boshlanadi: a.',
  ),
  _Rule(
    r'\b(informations|advices|equipments|furnitures|homeworks)\b',
    (m) => _case(m[0]!, m[0]!.toLowerCase().substring(0, m[0]!.length - 1)),
    'Bu ma’nodagi inglizcha ot odatda sanalmaydi va -s olmaydi.',
  ),
  _Rule(
    r'\balot\b',
    (m) => _case(m[0]!, 'a lot'),
    'A lot ikki alohida so‘z bilan yoziladi.',
  ),
  _Rule(
    r'\byour\s+welcome\b(?=[.!?]|\s*$)',
    (m) => _case(m[0]!, 'you’re welcome'),
    'Javob iborasi: You’re welcome. Your — egalik shakli.',
  ),
  _Rule(
    r'\bdiscuss\s+about\b',
    (m) => _case(m[0]!, 'discuss'),
    'Discuss odatda bevosita to‘ldiruvchi oladi, about shart emas.',
  ),
  _Rule(
    r'\bdiscussed\s+about\b',
    (m) => _case(m[0]!, 'discussed'),
    'Discussed dan keyin about kerak emas.',
  ),
  _Rule(
    r'\binterested\s+on\b',
    (m) => _case(m[0]!, 'interested in'),
    'Biror narsaga qiziqish: interested in.',
  ),
  _Rule(
    r'\bdepend\s+of\b',
    (m) => _case(m[0]!, 'depend on'),
    'Biror narsaga bog‘liq bo‘lish: depend on.',
  ),
  _Rule(
    r'\bdepends\s+of\b',
    (m) => _case(m[0]!, 'depends on'),
    'To‘g‘ri birikma: depends on.',
  ),
  _Rule(
    r'\bmarried\s+with\b',
    (m) => _case(m[0]!, 'married to'),
    'Turmush o‘rtog‘ini ko‘rsatishda married to ishlatiladi.',
    when: (text, m) => !RegExp(
      r'^\s+(?:(?:one|two|three|four|five|six|many|several|\d+)\s+)?(?:children|kids|sons|daughters|twins|a\s+child)\b',
      caseSensitive: false,
    ).hasMatch(text.substring(m.end)),
  ),
  _Rule(
    r'\bgood\s+in\s+English\b(?!\s+(?:class|classes|lessons|literature|schools?))',
    (m) => _case(m[0]!, 'good at English'),
    'Til bo‘yicha qobiliyat uchun odatda good at English ishlatiladi.',
  ),
  _Rule(
    r'\blooking\s+forward\s+to\s+(hear|meet|see)\b',
    (m) => _case(
      m[0]!,
      'looking forward to ${{'hear': 'hearing', 'meet': 'meeting', 'see': 'seeing'}[m[1]!.toLowerCase()]}',
    ),
    'Look forward to iborasida to — predlog, keyingi fe’l -ing oladi.',
  ),
  _Rule(
    r'\bevery\s+days\b',
    (m) => _case(m[0]!, 'every day'),
    'Every bilan bu tuzilmada birlik shakli day ishlatiladi.',
  ),
  _Rule(
    r'\bsince\s+(\d+)\s+(days|months|years|weeks)\b(?!\s+ago\b)',
    (m) => _case(m[0]!, 'for ${m[1]} ${m[2]}'),
    'Davomiy vaqt miqdori uchun for; boshlanish nuqtasi uchun since ishlatiladi.',
  ),
  _Rule(
    r'\bmuch\s+(books|students|people|cars|questions|words)\b',
    (m) => _case(m[0]!, 'many ${m[1]}'),
    'Sanaladigan ko‘plikdagi otlar bilan many ishlatiladi.',
  ),
  _Rule(
    r'\bbetween\s+you\s+and\s+i\b',
    (m) => _case(m[0]!, 'between you and me'),
    'Predlogdan keyin object olmoshi me ishlatiladi.',
  ),
  _Rule(
    r'\b(has|have|had)\s+(went|saw|ate|wrote|spoke|took|gave|broke|knew|drove)\b',
    (m) =>
        '${m[1]} ${{'went': 'gone', 'saw': 'seen', 'ate': 'eaten', 'wrote': 'written', 'spoke': 'spoken', 'took': 'taken', 'gave': 'given', 'broke': 'broken', 'knew': 'known', 'drove': 'driven'}[m[2]!.toLowerCase()]}',
    'Perfect zamonda fe’lning uchinchi shakli ishlatiladi.',
  ),
  _Rule(
    r'\bdid\s+(not\s+)?(i\s+|you\s+|he\s+|she\s+|we\s+|they\s+)?(went|saw|ate|wrote|spoke|took|gave|knew|bought)\b',
    (m) => _case(
      m[0]!,
      'did ${m[1] ?? ''}${m[2] ?? ''}${{'went': 'go', 'saw': 'see', 'ate': 'eat', 'wrote': 'write', 'spoke': 'speak', 'took': 'take', 'gave': 'give', 'knew': 'know', 'bought': 'buy'}[m[3]!.toLowerCase()]}',
    ),
    'Did dan keyin asosiy fe’l birinchi shaklda bo‘ladi.',
  ),
  _Rule(
    r'\bdidn[’\x27]t\s+(went|saw|ate|wrote|spoke|took|gave|knew|bought)\b',
    (m) => _case(
      m[0]!,
      'didn’t ${{'went': 'go', 'saw': 'see', 'ate': 'eat', 'wrote': 'write', 'spoke': 'speak', 'took': 'take', 'gave': 'give', 'knew': 'know', 'bought': 'buy'}[m[1]!.toLowerCase()]}',
    ),
    'Didn’t dan keyin fe’lning boshlang‘ich shakli ishlatiladi.',
  ),
  _Rule(
    r'\b(does|doesn[’\x27]t)\s+(he\s+|she\s+|it\s+)?(goes|likes|works|reads|plays|wants|needs)\b',
    (m) =>
        '${m[1]} ${m[2] ?? ''}${m[3]!.substring(0, m[3]!.length - (m[3]!.toLowerCase() == 'goes' ? 2 : 1))}',
    'Does / doesn’t bor tuzilmada asosiy fe’l -s olmaydi.',
  ),
  _Rule(
    r'(^|[.!?]\s+)(he|she|it)\s+(go|work|read|play|like|want|need)\b',
    (m) => '${m[1]}${m[2]} ${m[3]}${m[3]!.toLowerCase() == 'go' ? 'es' : 's'}',
    'Oddiy hozirgi zamondagi bu darak gapda he/she/it bilan fe’lga -s yoki -es qo‘shiladi.',
  ),

  _Rule(
    r'\b(he|she|it)\s+am\b',
    (m) => '${m[1]} is',
    'He, she, it bilan is ishlatiladi.',
  ),
  _Rule(
    r'\b(you|we|they)\s+am\b',
    (m) => '${m[1]} are',
    'You, we, they bilan are ishlatiladi.',
  ),
  _Rule(
    r'\bthere\s+is\s+(many|several)\b',
    (m) => _case(m[0]!, 'there are ${m[1]}'),
    'Many va several ko‘plikni bildiradi: there are.',
  ),
  _Rule(
    r'\bthere\s+are\s+(a|an)\s+(?!number\b|lot\b|few\b|couple\b)(book|car|student|teacher|apple|orange|house)\b',
    (m) => _case(m[0]!, 'there is ${m[1]} ${m[2]}'),
    'Bitta sanaladigan narsa uchun there is ishlatiladi.',
  ),
  _Rule(
    r'\b(does|do|doesn[’\x27]t|don[’\x27]t)\s+(not\s+)?(he\s+|she\s+|it\s+|they\s+|we\s+|you\s+|i\s+)?(likes|works|reads|plays|wants|needs)\b',
    (m) =>
        '${m[1]} ${m[2] ?? ''}${m[3] ?? ''}${m[4]!.substring(0, m[4]!.length - 1)}',
    'Do / does yordamchi fe’lidan keyin asosiy fe’l -s olmaydi.',
  ),
  _Rule(
    r'\b(can|could|must|should|would|will|may|might)\s+(went|ate|wrote|spoke|took|gave|knew|bought)\b',
    (m) =>
        '${m[1]} ${{'went': 'go', 'ate': 'eat', 'wrote': 'write', 'spoke': 'speak', 'took': 'take', 'gave': 'give', 'knew': 'know', 'bought': 'buy'}[m[2]!.toLowerCase()]}',
    'Modal fe’ldan keyin asosiy fe’lning boshlang‘ich shakli keladi.',
  ),
  _Rule(
    r'\b(could|should|would|must|might)\s+of\s+(been|done|gone|seen|known|taken|written)\b',
    (m) => '${m[1]} have ${m[2]}',
    'Bu tuzilmada of emas, have ishlatiladi.',
  ),
  _Rule(
    r'\bused\s+to\s+(went|ate|wrote|spoke|took|gave)\b',
    (m) => _case(
      m[0]!,
      'used to ${{'went': 'go', 'ate': 'eat', 'wrote': 'write', 'spoke': 'speak', 'took': 'take', 'gave': 'give'}[m[1]!.toLowerCase()]}',
    ),
    'Used to dan keyin fe’lning boshlang‘ich shakli keladi.',
  ),
  _Rule(
    r'\ba\s+(children|men|women|feet|teeth)\b(?![’\x27])',
    (m) => _case(
      m[0]!,
      'a ${{'children': 'child', 'men': 'man', 'women': 'woman', 'feet': 'foot', 'teeth': 'tooth'}[m[1]!.toLowerCase()]}',
    ),
    'A artiklidan keyin sanaladigan ot birlikda keladi.',
  ),
  _Rule(
    r'\b(two|three|four|five|six|seven|eight|nine|ten|\d+)\s+(childs|mans|womans|foots|tooths)\b(?![’\x27])',
    (m) =>
        '${m[1]} ${{'childs': 'children', 'mans': 'men', 'womans': 'women', 'foots': 'feet', 'tooths': 'teeth'}[m[2]!.toLowerCase()]}',
    'Bu otlarning ko‘plik shakli istisno tariqasida o‘zgaradi.',
  ),
  _Rule(
    r'\bone\s+of\s+(my|your|his|her|our|their|the)\s+(friend|student|teacher|book)\b(?![’\x27])',
    (m) => _case(m[0]!, 'one of ${m[1]} ${m[2]}s'),
    'One of tuzilmasida tanlanayotgan guruh ko‘plikda bo‘ladi.',
  ),
  _Rule(
    r'\b(listen|listens|listening|listened)\s+(music|the radio)\b',
    (m) => '${m[1]} to ${m[2]}',
    'Listen bilan bu birikmada to predlogi kerak.',
  ),
];
final _compiledRules = [
  for (final rule in _rules) RegExp(rule.pattern, caseSensitive: false),
];
int get grammarRuleCount => _rules.length;
String _withoutCode(String input) => input.replaceAllMapped(
  RegExp(
    r'```[\s\S]*?(?:```|$)|`[^`\n]*`|https?://[^\s]+|\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b',
  ),
  (m) => ' ' * m[0]!.length,
);
String applyGrammarIssues(String input, List<GrammarIssue> issues) {
  var result = input;
  for (final issue in issues.reversed) {
    if (issue.start < 0 ||
        issue.end > result.length ||
        result.substring(issue.start, issue.end) != issue.original) {
      throw ArgumentError('Matn o‘zgargan. Qayta tekshiring.');
    }
    result = result.replaceRange(issue.start, issue.end, issue.replacement);
  }
  return result;
}

List<GrammarIssue> checkGrammar(String input) {
  final found = <GrammarIssue>[];
  final checked = _withoutCode(input);
  for (var i = 0; i < _rules.length; i++) {
    final rule = _rules[i];
    for (final m in _compiledRules[i].allMatches(checked)) {
      if (input.substring(m.start, m.end) != m[0]) continue;
      if (rule.when != null && !rule.when!(input, m)) continue;
      if (found.any((x) => m.start < x.end && m.end > x.start)) continue;
      final replacement = rule.correction(m);
      if (replacement == m[0]) continue;
      found.add(
        GrammarIssue(m.start, m.end, m[0]!, replacement, rule.explanation),
      );
    }
  }
  found.sort((a, b) => a.start.compareTo(b.start));
  return found;
}

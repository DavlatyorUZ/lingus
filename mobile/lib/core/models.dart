import 'dart:math' as math;

String normalize(String s) => s
    .toLowerCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp('[‘’ʻʼ`ʹ]'), "'")
    .replaceAll('ğ', "g'")
    .replaceAll('ö', "o'")
    .replaceAll('ş', 'sh')
    .replaceAll('ç', 'ch')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String dayKey([DateTime? time]) {
  final d = time ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const levelNames = [
  'Boshlang‘ich',
  'Asosiy',
  'O‘rta',
  'Yuqori o‘rta',
  'Ilg‘or',
  'Mukammal',
];

class Word {
  final int id;
  final String lemma, translation, level, levelSource, translationSource, ipa;
  const Word({
    required this.id,
    required this.lemma,
    this.translation = '',
    this.level = '',
    this.levelSource = '',
    this.translationSource = '',
    this.ipa = '',
  });
  factory Word.from(Map<String, Object?> m) => Word(
    id: m['id'] as int,
    lemma: m['lemma'] as String,
    translation: m['translation'] as String? ?? '',
    level: m['level'] as String? ?? '',
    levelSource: m['level_source'] as String? ?? '',
    translationSource: m['translation_source'] as String? ?? '',
    ipa: m['ipa'] as String? ?? '',
  );
}

class ReviewSchedule {
  final int repetitions;
  final double interval, ease;
  final DateTime due;
  const ReviewSchedule({
    required this.repetitions,
    required this.interval,
    required this.ease,
    required this.due,
  });
}

// SM-2 adaptation: Again = 10 minutes; Hard/Good/Easy map to quality 3/4/5.
ReviewSchedule scheduleReview({
  required int grade,
  required int repetitions,
  required double interval,
  required double ease,
  required DateTime now,
}) {
  if (grade < 0 || grade > 3) throw ArgumentError.value(grade);
  final q = [0, 3, 4, 5][grade];
  final ef = math.max(1.3, ease + 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (q < 3) {
    return ReviewSchedule(
      repetitions: 0,
      interval: 10 / 1440,
      ease: ef,
      due: now.add(const Duration(minutes: 10)),
    );
  }
  final n = repetitions + 1;
  final days = n == 1
      ? 1.0
      : n == 2
      ? 6.0
      : math.max(1.0, (interval * ease).roundToDouble());
  return ReviewSchedule(
    repetitions: n,
    interval: days,
    ease: ef,
    due: now.add(Duration(days: days.round())),
  );
}

String displayCount(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]} ',
);

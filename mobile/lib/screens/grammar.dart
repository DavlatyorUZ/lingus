import 'package:material_ui/material_ui.dart';

import '../ui/design.dart';
import '../core/models.dart';

class Lesson {
  final String id, title, level, rule, explanation, mistake;
  final List<String> examples;
  final List<Question> questions;
  const Lesson(
    this.id,
    this.title,
    this.level,
    this.rule,
    this.explanation,
    this.examples,
    this.mistake,
    this.questions,
  );
}

class Question {
  final String text;
  final List<String> options;
  final int answer;
  const Question(this.text, this.options, this.answer);
}

const lessons = [
  Lesson(
    'present-simple',
    'Present Simple',
    'A1',
    'I / you / we / they + V\nHe / she / it + V-s',
    'Odatlar, takrorlanuvchi ishlar va umumiy haqiqatlar uchun ishlatiladi. Inkor: do not / does not + fe’lning asosiy shakli. Savol: Do / Does + ega + fe’l?',
    [
      'I study English every morning.',
      'She reads a book before bed.',
      'Does he work on Sundays?',
    ],
    'Does ishlatilganda asosiy fe’lga -s qo‘shilmaydi: Does she read?',
    [
      Question('She ___ English every day.', [
        'study',
        'studies',
        'studying',
      ], 1),
      Question('___ you like museums?', ['Does', 'Do', 'Are'], 1),
      Question('He does not ___ coffee.', ['drinks', 'drinking', 'drink'], 2),
    ],
  ),
  Lesson(
    'articles',
    'Articles: a, an, the',
    'A1',
    'a / an + birlikdagi sanaladigan ot\nthe + aniq, ma’lum narsa',
    'A — undosh tovushdan, an — unli tovushdan oldin keladi. Tanlov harfga emas, tovushga bog‘liq. The suhbatdoshga ma’lum yoki oldin aytilgan narsani bildiradi.',
    [
      'I bought a notebook. The notebook is green.',
      'She is an engineer.',
      'He studies at a university.',
    ],
    'A university deyiladi: university /juː/ tovushidan boshlanadi.',
    [
      Question('She is ___ honest person.', ['a', 'an', 'the a'], 1),
      Question('I saw a cat. ___ cat was white.', ['A', 'An', 'The'], 2),
      Question('He has ___ new book.', ['a', 'an', 'two'], 0),
    ],
  ),
  Lesson(
    'continuous',
    'Present Continuous',
    'A1',
    'am / is / are + V-ing',
    'Hozir sodir bo‘layotgan yoki vaqtinchalik vaziyatni ifodalaydi. Is / are ega bilan mos keladi. Harakatning odat yoki ayni paytdagi jarayon ekanini farqlang.',
    [
      'I am learning a new word.',
      'They are waiting outside.',
      'She is not sleeping now.',
    ],
    'I am knowing deyilmaydi; odatda I know ishlatiladi.',
    [
      Question('They ___ studying now.', ['is', 'are', 'am'], 1),
      Question('She is ___ a letter.', ['write', 'writes', 'writing'], 2),
      Question('I ___ listening.', ['am', 'is', 'are'], 0),
    ],
  ),
  Lesson(
    'past-simple',
    'Past Simple',
    'A2',
    'V-ed / irregular V2\nDid + ega + V?',
    'O‘tmishda tugagan harakatni bildiradi. Noto‘g‘ri fe’llarning ikkinchi shakli yodlanadi. Did ishlatilgan savol va inkorda fe’l boshlang‘ich shaklda bo‘ladi.',
    [
      'I visited Samarkand last year.',
      'We went to a museum yesterday.',
      'Did you enjoy the trip?',
    ],
    'Did you went? emas, Did you go?',
    [
      Question('Yesterday we ___ to school.', ['go', 'went', 'gone'], 1),
      Question('Did she ___ the book?', ['read', 'reads', 'reading'], 0),
      Question('I ___ not see him yesterday.', ['do', 'does', 'did'], 2),
    ],
  ),
  Lesson(
    'comparison',
    'Comparatives',
    'A2',
    'short adjective + -er\nmore + long adjective + than',
    'Ikki narsani solishtirishda comparative qo‘llanadi. Good → better, bad → worse kabi istisnolar bor. Orttirma daraja: the tallest, the most interesting.',
    [
      'This book is shorter than that one.',
      'English is more useful for my work.',
      'Today is better than yesterday.',
    ],
    'More easier deyilmaydi; easier kifoya.',
    [
      Question('This task is ___ than the last one.', [
        'easy',
        'easier',
        'more easier',
      ], 1),
      Question('She is the ___ student here.', [
        'tallest',
        'taller',
        'tall',
      ], 0),
      Question('This film is more ___ .', [
        'interest',
        'interesting',
        'interestedly',
      ], 1),
    ],
  ),
  Lesson(
    'present-perfect',
    'Present Perfect',
    'B1',
    'have / has + V3',
    'O‘tmishdagi harakatning hozirgi natijasi yoki hozirgacha bo‘lgan tajriba uchun ishlatiladi. Aniq tugagan vaqt (yesterday, last year) aytilsa, odatda Past Simple kerak.',
    [
      'I have learned ten new words.',
      'She has never visited London.',
      'Have you finished your homework?',
    ],
    'I have seen him yesterday emas, I saw him yesterday.',
    [
      Question('She ___ finished her work.', ['have', 'has', 'is'], 1),
      Question('I have ___ this book.', ['read', 'reading', 'reads'], 0),
      Question('We ___ him yesterday.', ['have seen', 'see', 'saw'], 2),
    ],
  ),
  Lesson(
    'conditionals',
    'First & Second Conditional',
    'B1',
    'If + Present, will + V\nIf + Past, would + V',
    'First conditional — kelajakda amalga oshishi mumkin bo‘lgan shart. Second conditional — faraziy yoki ehtimoli past vaziyat. If qismida odatiy first conditional uchun will ishlatilmaydi.',
    [
      'If it rains, I will stay home.',
      'If I had more time, I would read more.',
      'If I were you, I would practise daily.',
    ],
    'If it will rain emas, If it rains.',
    [
      Question('If she studies, she ___ pass.', ['would', 'will', 'did'], 1),
      Question('If I had a car, I ___ drive there.', [
        'will',
        'would',
        'have',
      ], 1),
      Question('If it ___, we will stay inside.', [
        'rains',
        'will rain',
        'rain',
      ], 0),
    ],
  ),
  Lesson(
    'passive',
    'Passive Voice',
    'B2',
    'be + past participle (V3)',
    'Bajaruvchidan ko‘ra harakat yoki uning natijasi muhim bo‘lsa passive ishlatiladi. Zamon be fe’li orqali ko‘rsatiladi. By + bajaruvchi zarurat bo‘lganda qo‘shiladi.',
    [
      'The book was written in 2020.',
      'English is spoken in many countries.',
      'The report has been completed.',
    ],
    'The book wrote by him emas, The book was written by him.',
    [
      Question('The letter ___ sent yesterday.', ['is', 'was', 'has'], 1),
      Question('The work has ___ completed.', ['be', 'being', 'been'], 2),
      Question('These cars ___ made here.', ['is', 'are', 'am'], 1),
    ],
  ),
  Lesson(
    'reported',
    'Reported Speech',
    'B2',
    'She said (that) she was tired.',
    'Birovning gapini o‘zlashtirib aytishda olmoshlar va vaqt ko‘rsatkichlari vaziyatga mos o‘zgaradi. O‘tgan zamondagi reporting verb bilan zamon ko‘pincha orqaga siljiydi. Hali ham haqiqiy umumiy faktlarda bu doimo majburiy emas.',
    [
      '“I am tired.” → She said she was tired.',
      '“I will help.” → He said he would help.',
      'She told me that she liked the book.',
    ],
    'Said me emas; told me yoki said to me.',
    [
      Question('He said he ___ help.', ['will', 'would', 'can will'], 1),
      Question('She ___ me she was tired.', ['said', 'told', 'spoke'], 1),
      Question('“I am ready.” → He said he ___ ready.', [
        'were',
        'was',
        'be',
      ], 1),
    ],
  ),
  Lesson(
    'inversion',
    'Inversion for Emphasis',
    'C1',
    'Never / Rarely + auxiliary + subject + V',
    'Salbiy yoki cheklovchi ravish gap boshiga chiqsa, ta’kid uchun yordamchi fe’l egadan oldin keladi. Bu ko‘proq rasmiy yoki adabiy uslubda ishlatiladi.',
    [
      'Never have I seen such a view.',
      'Rarely does she arrive late.',
      'Not only did he apologise, but he also helped.',
    ],
    'Never I have seen emas; Never have I seen.',
    [
      Question('Never ___ I seen this before.', [
        'have',
        'I have',
        'having',
      ], 0),
      Question('Rarely ___ he complain.', ['do', 'does', 'is'], 1),
      Question('Not only ___ she arrive early, but she helped.', [
        'did',
        'does did',
        'was did',
      ], 0),
    ],
  ),
  Lesson(
    'clefts',
    'Cleft Sentences',
    'C1',
    'It is / was + focus + that / who …',
    'Gapning bir qismini ajratib, urg‘u berish uchun cleft sentence ishlatiladi. What-cleft tuzilmasi ehtiyoj, fikr yoki harakatni ta’kidlashi mumkin.',
    [
      'It was Ali who found the answer.',
      'What I need is more practice.',
      'It was yesterday that she called.',
    ],
    'Urg‘u qaratilgan bo‘lakni tanlang; ortiqcha cleft ishlatish matnni og‘irlashtiradi.',
    [
      Question('It was Sara ___ solved the problem.', [
        'who',
        'where',
        'when',
      ], 0),
      Question('What I need ___ more time.', ['are', 'is', 'be'], 1),
      Question('It was at noon ___ he arrived.', ['who', 'what', 'that'], 2),
    ],
  ),
  Lesson(
    'subjunctive',
    'Mandative Subjunctive',
    'C2',
    'suggest / insist + that + subject + base verb',
    'Talab yoki tavsiya mazmunidagi rasmiy gaplarda that-dan keyin fe’l asosiy shaklda kelishi mumkin. Bu ayniqsa Amerika inglizchasida keng uchraydi; Britaniya inglizchasida should + V ham ishlatiladi.',
    [
      'I suggest that he be informed.',
      'They insisted that she attend the meeting.',
      'It is essential that everyone arrive on time.',
    ],
    'He bo‘lsa ham subjunctive tuzilmasida arrives emas, arrive ishlatiladi.',
    [
      Question('They insisted that he ___ present.', ['is', 'was', 'be'], 2),
      Question('I suggest that she ___ early.', [
        'arrive',
        'arrives',
        'arrived',
      ], 0),
      Question('It is essential that he ___ informed.', ['be', 'is', 'has'], 0),
    ],
  ),
];

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});
  @override
  State<GrammarScreen> createState() => _GrammarState();
}

class _GrammarState extends State<GrammarScreen> {
  String lv = '';
  Set<String> done = {};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await store.doneLessons();
    if (mounted) setState(() => done = r);
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Grammatika daftari',
    child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Grammatika', style: display(24)),
        const SizedBox(height: 14),
        Text(
          '${done.length} / ${lessons.length} ta dars yakunlangan',
          style: TextStyle(color: muted(c), fontSize: 12),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 7,
          children: ['', ...levels]
              .map(
                (l) => ChoiceChip(
                  label: Text(l.isEmpty ? 'Barchasi' : l),
                  selected: lv == l,
                  onSelected: (_) => setState(() => lv = l),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        ...lessons
            .where((l) => lv.isEmpty || l.level == lv)
            .map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Glass(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: LevelBadge(l.level),
                    title: Text(l.title, style: display(21)),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Qoida · misollar · 3 ta savol',
                        style: TextStyle(fontSize: 10, color: muted(c)),
                      ),
                    ),
                    trailing: AppIcon(
                      done.contains(l.id)
                          ? AppIcons.checkCircleOutline
                          : AppIcons.arrowForward,
                      size: 21,
                      color: muted(c),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => LessonScreen(lesson: l),
                        ),
                      );
                      load();
                    },
                  ),
                ),
              ),
            ),
        const SizedBox(height: 16),
        Text(
          'Darajalar darslarni tartiblash uchun berilgan. Darsni tugatish CEFR sertifikatini bermaydi. Barcha darslar ochiq.',
          style: TextStyle(fontSize: 10, color: muted(c)),
        ),
      ],
    ),
  );
}

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonScreen({super.key, required this.lesson});
  @override
  State<LessonScreen> createState() => _LessonState();
}

class _LessonState extends State<LessonScreen> {
  final answers = <int, int>{};
  bool checked = false, completed = false;
  @override
  Widget build(BuildContext c) {
    final l = widget.lesson;
    return PageFrame(
      title: l.title,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          LevelBadge(l.level),
          const SizedBox(height: 18),
          Text(l.title, style: display(34)),
          const SizedBox(height: 22),
          Glass(
            color: gold.withValues(alpha: .17),
            child: SelectableText(
              l.rule,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(l.explanation, style: TextStyle(fontSize: 14, height: 1.8)),
          const SectionTitle('Misollar'),
          ...l.examples.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Glass(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: Text(e, style: TextStyle(fontSize: 13))),
                    AudioButton(e),
                  ],
                ),
              ),
            ),
          ),
          const SectionTitle('Ko‘p uchraydigan xato'),
          Glass(
            color: coral.withValues(alpha: .1),
            child: Text(l.mistake, style: TextStyle(fontSize: 13)),
          ),
          const SectionTitle('O‘zingizni tekshiring'),
          ...l.questions.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.key + 1}. ${e.value.text}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...e.value.options.asMap().entries.map(
                      (o) => InkWell(
                        onTap: completed
                            ? null
                            : () => setState(() {
                                answers[e.key] = o.key;
                                checked = false;
                              }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            children: [
                              AppIcon(
                                answers[e.key] == o.key
                                    ? AppIcons.radioButtonChecked
                                    : AppIcons.radioButtonUnchecked,
                                color:
                                    checked && answers[e.key] != e.value.answer
                                    ? coral
                                    : sage,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(o.value)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (checked)
                      Text(
                        answers[e.key] == e.value.answer
                            ? 'To‘g‘ri!'
                            : 'Qoidani yana bir marta o‘qing.',
                        style: TextStyle(
                          color: answers[e.key] == e.value.answer
                              ? sage
                              : coral,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          TactileButton(
            completed ? 'Dars yakunlandi' : 'Javoblarni tekshirish',
            onTap: answers.length != l.questions.length || completed
                ? null
                : () async {
                    final all = l.questions.asMap().entries.every(
                      (e) => answers[e.key] == e.value.answer,
                    );
                    if (all) await store.lessonDone(l.id);
                    if (mounted) {
                      setState(() {
                        checked = true;
                        completed = all;
                      });
                    }
                  },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

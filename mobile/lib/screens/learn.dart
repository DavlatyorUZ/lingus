import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import '../core/illustrations.dart';
import 'pictures.dart';
import 'games.dart';
import 'study_game.dart';
import 'home.dart';
import '../ui/design.dart';
import '../ui/learning_art.dart';
import '../ui/tab_motion.dart';
import 'dictionary.dart';
import 'grammar.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});
  void open(BuildContext c, Widget page) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => page));
  @override
  Widget build(BuildContext c) => ListView(
    padding: EdgeInsets.fromLTRB(
      20,
      24,
      20,
      30 + MediaQuery.paddingOf(c).bottom,
    ),
    children: [
      Text('O‘yinlar', style: display(26)),
      const SizedBox(height: 8),
      Text(
        'Ko‘ring, eslang va toping.',
        style: TextStyle(color: muted(c), fontSize: 14),
      ),
      const SizedBox(height: 20),
      Glass(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            MenuRow(
              'Sinonimlar',
              'So‘z tanlang, yaqin yozilishlarni ajrating',
              AppIcons.autoStoriesOutlined,
              () => openStudyGame(c, 'synonyms'),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            MenuRow(
              'Tarjima',
              'O‘zbekchadan inglizchaga · ma’no va imlo',
              AppIcons.translate,
              () => openStudyGame(c, 'translate'),
            ),
          ],
        ),
      ),
      const SectionTitle('Boshqa mashqlar'),
      SceneItem(
        delay: .1,
        child: PracticeHero(
          game: true,
          onTap: () => open(c, const MemoryGameScreen()),
        ),
      ),
      const SizedBox(height: 14),
      Glass(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            MenuRow(
              'Juftini top',
              '4 ta so‘z va ularning ma’nolari',
              AppIcons.gridViewRounded,
              () => open(c, const PairGameScreen()),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            MenuRow(
              'Eslab top',
              'Mening so‘zlarimni vaqti kelganda takrorlash',
              AppIcons.history,
              () => open(c, const FlashcardScreen()),
            ),
          ],
        ),
      ),
      const SectionTitle('Yana mashqlar'),
      Glass(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ...{
              0: 'Tarjimani toping',
              1: 'So‘zni yozing',
              2: 'Tinglab toping',
              4: 'So‘z sprinti',
            }.entries.map(
              (e) => MenuRow(
                e.value,
                e.key == 4
                    ? '60 soniyali mashq'
                    : '${store.level} darajasidagi so‘zlar',
                e.key == 2
                    ? AppIcons.headphonesOutlined
                    : AppIcons.editOutlined,
                () => open(c, QuizScreen(mode: e.key)),
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('Lug‘at va grammatika'),
      Glass(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            MenuRow(
              'Rasmli lug‘at',
              '${pictureWords.length} ta rasmli yozuv',
              AppIcons.imageOutlined,
              () => open(c, const PicturesScreen()),
            ),
            MenuRow(
              'Grammatika',
              'Qoidalar va misollar',
              AppIcons.menuBookOutlined,
              () => open(c, const GrammarScreen()),
            ),
          ],
        ),
      ),
      const SectionTitle('Daraja bo‘yicha so‘zlar'),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: levels
            .map(
              (lv) => ActionChip(
                label: Text(lv),
                onPressed: () => open(
                  c,
                  PageFrame(
                    title: '$lv so‘zlari',
                    child: DictionaryScreen(initialLevel: lv),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}

/// Saved-word practice now requires recall rather than self-grading a flip card.
class FlashcardScreen extends StatelessWidget {
  final int? folder;
  const FlashcardScreen({super.key, this.folder});
  @override
  Widget build(BuildContext c) =>
      MemoryGameScreen(pictures: false, folder: folder);
}

class QuizScreen extends StatefulWidget {
  final int mode;
  const QuizScreen({super.key, this.mode = 0});
  @override
  State<QuizScreen> createState() => _QuizState();
}

class _QuizState extends State<QuizScreen> {
  List<Word>? words;
  List<Word> options = [];
  final input = TextEditingController();
  int index = 0, correct = 0, left = 60;
  bool answered = false, right = false, done = false, submitting = false;
  Timer? timer;
  final mistakes = <Word>[];
  String lv = store.level;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    timer?.cancel();
    final r = await store.practiceWords(
      lv: lv,
      limit: widget.mode == 4 ? 80 : 14,
    );
    if (!mounted) return;
    setState(() {
      words = r;
      index = 0;
      correct = 0;
      done = false;
      left = 60;
      mistakes.clear();
      prepare();
    });
    if (widget.mode == 4 && r.length >= 4) {
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          left--;
          if (left <= 0) {
            done = true;
            t.cancel();
          }
        });
      });
    }
  }

  void prepare() {
    answered = false;
    right = false;
    submitting = false;
    input.clear();
    if (words == null || words!.isEmpty || index >= words!.length) return;
    final w = words![index];
    final others =
        (words!
                .where((x) => x.translation != w.translation && x.id != w.id)
                .toList()
              ..shuffle())
            .take(3);
    options = [w, ...others]..shuffle();
  }

  Future<void> answer(bool r) async {
    if (answered || done || submitting) return;
    final w = words![index];
    setState(() => submitting = true);
    try {
      await store.answer(
        w,
        r,
        kind: widget.mode == 2
            ? 'listening'
            : widget.mode == 1
            ? 'spelling'
            : 'quiz',
      );
      if (!mounted) return;
      setState(() {
        submitting = false;
        answered = true;
        right = r;
        if (r) {
          correct++;
        } else {
          mistakes.add(w);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => submitting = false);
        toast(context, 'Natijani saqlab bo‘lmadi. Qayta urinib ko‘ring.');
      }
    }
  }

  void next() {
    setState(() {
      index++;
      if (index >= words!.length) {
        done = true;
        timer?.cancel();
      } else {
        prepare();
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    final names = [
      'Tarjimani toping',
      'So‘zni yozing',
      'Tinglab toping',
      'Juftliklar',
      'So‘z sprinti',
    ];
    return PageFrame(
      title: names[widget.mode],
      child: words == null
          ? Center(child: CircularProgressIndicator(color: muted(c)))
          : words!.length < 4
          ? EmptyState(
              'Avval so‘z saqlang',
              'Kamida 4 ta ma’nosi turlicha so‘z kerak.',
              action: TactileButton(
                'Lug‘atni ochish',
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                ),
              ),
            )
          : done
          ? SessionResult(
              correct: correct,
              total: correct + mistakes.length,
              label: 'Mashq yakunlandi',
              mistakes: mistakes,
              onReplay: () => load(),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Saqlangan so‘zlar')),
                    const SizedBox(width: 12),
                    Text(
                      widget.mode == 4
                          ? '$left soniya'
                          : '${index + 1} / ${words!.length}',
                      style: TextStyle(
                        color: muted(c),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Glass(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Eyebrow(
                        widget.mode == 1
                            ? 'INGLIZCHASINI YOZING'
                            : widget.mode == 2
                            ? 'TINGLANG VA YOZING'
                            : 'TO‘G‘RI MA’NONI TANLANG',
                      ),
                      const SizedBox(height: 28),
                      if (widget.mode == 2)
                        IconButton(
                          tooltip: 'So‘zni tinglash',
                          iconSize: 56,
                          icon: AppIcon(
                            AppIcons.volumeUpRounded,
                            color: muted(c),
                          ),
                          onPressed: () => pronounce(c, words![index].lemma),
                        )
                      else
                        Text(
                          widget.mode == 1
                              ? words![index].translation
                              : words![index].lemma,
                          textAlign: TextAlign.center,
                          style: display(32),
                        ),
                      const SizedBox(height: 25),
                      if (widget.mode == 0 || widget.mode == 4)
                        LevelBadge(words![index].level),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                if (widget.mode == 1 || widget.mode == 2) ...[
                  TextField(
                    controller: input,
                    enabled: !answered,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => answer(
                      normalize(input.text) == normalize(words![index].lemma),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Inglizcha so‘z…',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!answered)
                    TactileButton(
                      'Tekshirish',
                      onTap: submitting
                          ? null
                          : () => answer(
                              normalize(input.text) ==
                                  normalize(words![index].lemma),
                            ),
                    ),
                ] else
                  ...options.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TactileButton(
                        w.translation,
                        secondary: true,
                        onTap: answered || submitting
                            ? null
                            : () => answer(w.id == words![index].id),
                      ),
                    ),
                  ),
                if (answered) ...[
                  const SizedBox(height: 15),
                  Glass(
                    color: (right ? sage : coral).withValues(alpha: .15),
                    child: Column(
                      children: [
                        AppIcon(
                          right
                              ? AppIcons.checkCircleOutline
                              : AppIcons.infoOutline,
                          color: right ? sage : coral,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          right
                              ? 'To‘g‘ri javob!'
                              : 'To‘g‘ri javob: ${words![index].lemma} — ${words![index].translation}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: right ? sage : coral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TactileButton(
                    'Keyingisi',
                    icon: AppIcons.arrowForward,
                    onTap: next,
                  ),
                ],
              ],
            ),
    );
  }
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});
  @override
  State<MatchScreen> createState() => _MatchState();
}

class _MatchState extends State<MatchScreen> {
  List<Word>? words;
  List<Word> shuffled = [];
  Set<int> matched = {};
  int? selected;
  bool busy = false;
  String message = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await store.practiceWords(limit: 20);
    final unique = <String>{};
    final chosen = r.where((w) => unique.add(w.translation)).take(5).toList();
    if (mounted) {
      setState(() {
        words = chosen;
        shuffled = [...chosen]..shuffle();
        matched = {};
        selected = null;
        message = '';
      });
    }
  }

  Future<void> pair(Word w) async {
    if (selected == null || matched.contains(w.id) || busy) return;
    final id = selected!;
    final source = words!.firstWhere((x) => x.id == id);
    final right = id == w.id;
    setState(() => busy = true);
    await store.answer(source, right, kind: 'match');
    if (mounted) {
      setState(() {
        busy = false;
        if (right) matched.add(id);
        message = right ? 'To‘g‘ri juftlik!' : 'Mos kelmadi. Qayta sinang.';
        selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Juftini toping',
    child: words == null
        ? Center(child: CircularProgressIndicator(color: muted(c)))
        : words!.length < 4
        ? EmptyState(
            'Avval so‘z saqlang',
            'Kamida 4 ta turli ma’no kerak.',
            action: TactileButton(
              'Lug‘atni ochish',
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const DictionaryScreen()),
              ),
            ),
          )
        : matched.length == words!.length
        ? SessionResult(
            correct: matched.length,
            total: words!.length,
            label: 'Barcha juftliklar topildi',
            onReplay: load,
          )
        : ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text('Bir so‘z. Ikki til.', style: display(30)),
              const SizedBox(height: 12),
              Text(
                'Avval chapdagi inglizcha so‘zni, keyin uning ma’nosini tanlang.',
                style: TextStyle(color: muted(c), fontSize: 12),
              ),
              const SizedBox(height: 25),
              ...List.generate(
                words!.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: matched.contains(words![i].id) ? .3 : 1,
                          child: TactileButton(
                            words![i].lemma,
                            secondary: selected != words![i].id,
                            onTap: matched.contains(words![i].id) || busy
                                ? null
                                : () => setState(() => selected = words![i].id),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Opacity(
                          opacity: matched.contains(shuffled[i].id) ? .3 : 1,
                          child: TactileButton(
                            shuffled[i].translation,
                            secondary: true,
                            onTap: matched.contains(shuffled[i].id) || busy
                                ? null
                                : () => pair(shuffled[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: muted(c)),
              ),
            ],
          ),
  );
}

class SessionResult extends StatelessWidget {
  final int correct, total;
  final String label;
  final VoidCallback onReplay;
  final List<Word> mistakes;
  const SessionResult({
    super.key,
    required this.correct,
    required this.total,
    required this.label,
    required this.onReplay,
    this.mistakes = const [],
  });
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(26),
    children: [
      const SizedBox(height: 26),
      Center(
        child: Container(
          width: 126,
          height: 126,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [palette(c).ctaHover, palette(c).cta],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: .3),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Text('$correct', style: display(55, color: ink)),
          ),
        ),
      ),
      const SizedBox(height: 32),
      Text(label, textAlign: TextAlign.center, style: display(29)),
      const SizedBox(height: 14),
      Text(
        '$total ta mashqdan $correct ta to‘g‘ri',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted(c)),
      ),
      const SizedBox(height: 30),
      TactileButton(
        'Yana mashq qilish',
        icon: AppIcons.replay,
        onTap: onReplay,
      ),
      const SizedBox(height: 10),
      TactileButton('Tugatish', secondary: true, onTap: () => Navigator.pop(c)),
      if (mistakes.isNotEmpty) ...[
        const SectionTitle('Qayta ko‘rib chiqing'),
        ...mistakes.toSet().map(
          (w) => WordTile(w, onTap: () => openWord(c, w)),
        ),
      ],
    ],
  );
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import '../core/study_game.dart';
import '../core/account_api.dart';
import '../ui/design.dart';
import '../ui/game_motion.dart';

Future<void> openStudyGame(BuildContext c, String mode) async {
  final account = store.accountId;
  final questions = await showDialog<List<StudyQuestion>>(
    context: c,
    builder: (_) => StudyWordPicker(mode: mode),
  );
  if (!c.mounted ||
      store.accountId != account ||
      questions == null ||
      questions.isEmpty) {
    return;
  }
  await Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) => StudyGameScreen(mode: mode, questions: questions),
    ),
  );
}

List<StudyQuestion> _prepare((String, List<StudyWord>, StudyBank) args) =>
    prepareSession(args.$1, args.$2, args.$3);

class StudyWordPicker extends StatefulWidget {
  final String mode;
  const StudyWordPicker({super.key, required this.mode});
  @override
  State<StudyWordPicker> createState() => _PickerState();
}

class _PickerState extends State<StudyWordPicker> {
  final query = TextEditingController();
  final selected = <int, StudyWord>{}, details = <int, StudyWord>{};
  List<Word> words = [];
  StudyBank? bank;
  Timer? timer;
  bool busy = true, starting = false;
  String? error;
  int generation = 0;
  late final String? ownerAccount = store.accountId;
  bool accountChanged = false;
  void accountGuard() {
    if (!mounted || accountChanged || store.accountId == ownerAccount) return;
    setState(() {
      accountChanged = true;
      generation++;
      words = [];
      selected.clear();
      details.clear();
      query.clear();
      busy = false;
      error = "Akkaunt o‘zgardi. Oynani yopib, qayta boshlang.";
    });
  }

  @override
  void initState() {
    super.initState();
    store.addListener(accountGuard);
    load();
  }

  @override
  void dispose() {
    store.removeListener(accountGuard);
    timer?.cancel();
    query.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (accountChanged) return;
    final run = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      bank ??= await StudyBank.load();
      final result = query.text.trim().isEmpty
          ? await store.savedWords()
          : await store.search(query.text);
      if (!mounted || run != generation) {
        return;
      }
      final visible = result.isEmpty && query.text.trim().isEmpty
          ? await store.recentViewed()
          : result;
      if (!mounted || run != generation) return;
      setState(() => words = visible);
    } catch (_) {
      if (mounted && run == generation) {
        setState(() => error = 'So‘zlar ochilmadi. Qayta urinib ko‘ring.');
      }
    } finally {
      if (mounted && run == generation) {
        setState(() => busy = false);
      }
    }
  }

  Future<StudyWord> detail(Word w) async {
    if (details.containsKey(w.id)) {
      return details[w.id]!;
    }
    final senses = await store.senses(w.id);
    final d = StudyWord.detail({
      'id': w.id,
      'lemma': w.lemma,
      'translation': store.editorialMeaning(w) ?? w.translation,
    }, senses);
    if (!mounted || accountChanged || store.accountId != ownerAccount) {
      throw StateError('Account changed');
    }
    details[w.id] = d;
    if (mounted) {
      setState(() {});
    }
    return d;
  }

  Future<void> toggle(Word w) async {
    if (starting || accountChanged) {
      return;
    }
    if (selected.containsKey(w.id)) {
      setState(() => selected.remove(w.id));
      return;
    }
    if (selected.length >= 30) {
      toast(context, 'Bir turda 30 tagacha so‘z tanlang.');
      return;
    }
    try {
      final d = await detail(w);
      if (!mounted || starting || accountChanged) {
        return;
      }
      if (selected.length >= 30) {
        return;
      }
      if (widget.mode == 'synonyms' && d.choices.isEmpty) {
        toast(
          context,
          'Bu so‘zga bog‘langan sinonim topilmadi. Tarjima rejimini tanlang.',
        );
        return;
      }
      if (d.translation.isEmpty) {
        toast(context, 'Avval so‘zning ma’nosini aniqlang.');
        return;
      }
      setState(() => selected[w.id] = d);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Sinonimlar ochilmadi. Qayta urinib ko‘ring.');
      }
    }
  }

  Future<void> synonym(String text) async {
    try {
      final word = await store.lookup(text);
      if (!mounted) {
        return;
      }
      if (word == null) {
        toast(context, 'Sinonimni lug‘atdan qidirib ko‘ring.');
        return;
      }
      await toggle(word);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Sinonim tanlanmadi. Qayta urinib ko‘ring.');
      }
    }
  }

  Future<void> translate(Word word) async {
    if (starting || accountChanged) {
      return;
    }
    setState(() => starting = true);
    try {
      final r = await accountApi.request(
        '/dictionary/translate',
        method: 'POST',
        body: {'text': word.lemma},
      );
      if (!mounted || accountChanged || store.accountId != ownerAccount) return;
      await store.cacheRemoteWord((r['word'] as Map).cast<String, dynamic>());
      details.remove(word.id);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => starting = false);
      }
    }
  }

  Future<void> start() async {
    if (starting || accountChanged || selected.isEmpty || bank == null) {
      return;
    }
    setState(() {
      starting = true;
      error = null;
    });
    try {
      final questions = await compute(_prepare, (
        widget.mode,
        selected.values.toList(),
        bank!,
      ));
      if (!mounted || accountChanged || store.accountId != ownerAccount) {
        return;
      }
      if (questions.isEmpty) {
        setState(
          () => error = 'Aniq va yaqin variantlar yetarli emas. Boshqa so‘z yoki sinonim tanlang.',
        );
        return;
      }
      if (questions.length < selected.length) {
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Tayyor savollar'),
            content: Text(
              '${questions.length} ta savol tayyor. Takroriy savollar va aniq variant yetishmagan so‘zlar chiqarildi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Tanlovga qaytish'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Boshlash'),
              ),
            ],
          ),
        );
        if (go != true ||
            !mounted ||
            accountChanged ||
            store.accountId != ownerAccount) {
          return;
        }
      }
      if (mounted && !accountChanged && store.accountId == ownerAccount) {
        Navigator.pop(context, questions);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'O‘yin tayyorlanmadi. Qayta urinib ko‘ring.');
      }
    } finally {
      if (mounted) {
        setState(() => starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SizedBox(
        height: math.min(MediaQuery.sizeOf(c).height * .88, 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.mode == 'synonyms' ? 'Sinonimlar' : 'Tarjima',
                      style: display(20),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yopish',
                    onPressed: starting ? null : () => Navigator.pop(c),
                    icon: const AppIcon(AppIcons.close, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                key: const ValueKey('study-scroll'),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: query,
                            enabled: !starting,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'So‘z yoki ibora qidiring…',
                              prefixIcon: AppIcon(AppIcons.search, size: 18),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (_) {
                              timer?.cancel();
                              generation++;
                              timer = Timer(
                                const Duration(milliseconds: 240),
                                load,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${selected.length} ta tanlandi · 30 tagacha',
                            style: TextStyle(color: muted(c), fontSize: 12),
                          ),
                          if (selected.isNotEmpty)
                            SizedBox(
                              height: math.max(
                                44,
                                MediaQuery.textScalerOf(c).scale(24) + 18,
                              ),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: selected.values
                                    .map(
                                      (w) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: InputChip(
                                          label: Text(w.lemma),
                                          onDeleted: starting
                                              ? null
                                              : () => setState(
                                                  () => selected.remove(w.id),
                                                ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: palette(c).error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (busy)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (words.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'So‘z topilmadi. Boshqa yozilish yoki qisqaroq so‘z bilan qidiring.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        _wordRow,
                        childCount: words.length,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              key: const ValueKey('study-footer'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(c).dividerColor),
                ),
              ),
              child: FilledButton(
                key: const ValueKey('study-start'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed:
                    selected.isEmpty || starting || busy || accountChanged
                    ? null
                    : () {
                        FocusScope.of(c).unfocus();
                        start();
                      },
                child: Text(starting ? 'Tayyorlanmoqda…' : 'O‘yinni boshlash'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _wordRow(BuildContext c, int i) {
    final w = words[i],
        d = selected[w.id] ?? details[w.id],
        meaning = store.editorialMeaning(w) ?? w.translation;
    return ExpansionTile(
      key: ValueKey('study-word-${w.id}'),
      onExpansionChanged: (v) {
        if (v) {
          detail(w).catchError((Object e) {
            if (mounted) {
              setState(() => error = 'Sinonimlar ochilmadi.');
            }
            return StudyWord(id: w.id, lemma: w.lemma, translation: meaning);
          });
        }
      },
      leading: Checkbox(
        value: selected.containsKey(w.id),
        onChanged: starting ? null : (_) => toggle(w),
      ),
      title: Text(w.lemma, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        meaning.isEmpty ? 'Tarjimasi hali yo‘q' : meaning,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        if (d != null && d.meanings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey('sense-${w.id}-${d.senseId}'),
              initialValue: d.senseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Mashq uchun ma’no'),
              items: d.meanings
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${const {'v': 'Fe’l', 'n': 'Ot', 'a': 'Sifat', 's': 'Sifat', 'r': 'Ravish'}[s.pos] ?? s.pos} · ${s.context.isNotEmpty ? s.context : s.definition}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: starting
                  ? null
                  : (id) {
                      if (id == null) return;
                      final updated = d.withMeaning(
                        d.meanings.firstWhere((s) => s.id == id),
                      );
                      setState(() {
                        details[w.id] = updated;
                        if (selected.containsKey(w.id)) {
                          selected[w.id] = updated;
                        }
                      });
                    },
            ),
          ),
        if (meaning.isEmpty)
          TextButton(
            onPressed: starting ? null : () => translate(w),
            child: const Text('Ma’nosini onlayn aniqlash'),
          ),
        if (d == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Sinonimlarni ochish uchun bosing.'),
          )
        else if (d.choices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Bog‘langan sinonim yo‘q. Tarjima rejimida mashq qilishingiz mumkin.',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: d.choices
                  .take(6)
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      onPressed: starting ? null : () => synonym(s),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class StudyGameScreen extends StatefulWidget {
  final String mode;
  final List<StudyQuestion> questions;
  final Future<void> Function(StudyWord, bool)? onAnswer;
  const StudyGameScreen({
    super.key,
    required this.mode,
    required this.questions,
    this.onAnswer,
  });
  @override
  State<StudyGameScreen> createState() => _StudyState();
}

class _StudyState extends State<StudyGameScreen> {
  int index = 0, correct = 0;
  int? answer;
  bool done = false;
  late final String? account = store.accountId;
  late List<StudyQuestion> questions = widget.questions;
  StudyQuestion get question => questions[index];
  @override
  void initState() {
    super.initState();
    store.addListener(accountGuard);
  }

  void accountGuard() {
    if (mounted && store.accountId != account) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(accountGuard);
    super.dispose();
  }

  Future<void> replay() async {
    final bank = await StudyBank.load();
    if (!mounted || store.accountId != account) {
      return;
    }
    final next = prepareSession(
      widget.mode,
      questions.map((q) => q.word).toList(),
      bank,
    );
    if (next.isEmpty) {
      return;
    }
    setState(() {
      questions = next;
      index = 0;
      correct = 0;
      answer = null;
      done = false;
    });
  }

  void choose(int i) {
    if (answer != null || store.accountId != account) {
      return;
    }
    final right = question.options[i].text == question.correct;
    setState(() {
      answer = i;
      if (right) {
        correct++;
      }
    });
    // One captured database call: a late account switch cannot replay the answer.
    (widget.onAnswer?.call(question.word, right) ??
            store.answer(
              Word(
                id: question.word.id,
                lemma: question.word.lemma,
                translation: question.word.translation,
              ),
              right,
              kind: widget.mode,
            ))
        .catchError((Object e) {
          if (mounted && store.accountId == account) {
            toast(context, 'Natija qurilmaga saqlanmadi.');
          }
        });
  }

  void next() {
    if (answer == null) {
      return;
    }
    setState(() {
      if (index + 1 == questions.length) {
        done = true;
      } else {
        index++;
        answer = null;
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    if (store.accountId != account) {
      return const PageFrame(
        title: 'Mashq',
        child: Center(child: Text('Akkaunt o‘zgardi. Yangi o‘yin boshlang.')),
      );
    }
    if (done) {
      return PageFrame(
        title: 'Natija',
        child: GameFinish(
          correct: correct,
          total: questions.length,
          points: correct * 10,
          replay: replay,
        ),
      );
    }
    final q = question;
    return PageFrame(
      title: widget.mode == 'synonyms' ? 'Sinonimlar' : 'Tarjima',
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Savol ${index + 1} / ${questions.length}',
            style: TextStyle(color: muted(c)),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: index / questions.length,
            minHeight: 5,
          ),
          const SizedBox(height: 24),
          Text(
            widget.mode == 'synonyms'
                ? 'Sinonimini toping'
                : 'Inglizchasini toping',
            style: TextStyle(color: muted(c)),
          ),
          const SizedBox(height: 10),
          Text(q.question, style: display(30)),
          if (q.context.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(q.context, style: TextStyle(color: muted(c))),
          ],
          const SizedBox(height: 24),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                key: ValueKey('study-option-$i'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(18),
                  side: BorderSide(
                    color: answer == i
                        ? (q.options[i].text == q.correct
                              ? palette(c).success
                              : palette(c).error)
                        : palette(c).border,
                  ),
                ),
                onPressed: answer != null ? null : () => choose(i),
                child: Text(
                  q.options[i].text,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          if (answer != null) ...[
            if (q.options[answer!].text != q.correct)
              Semantics(
                liveRegion: true,
                child: Text(
                  q.options[answer!].explanation,
                  key: const ValueKey('study-explanation'),
                  style: const TextStyle(height: 1.6),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(onPressed: next, child: const Text('Davom etish')),
          ],
        ],
      ),
    );
  }
}

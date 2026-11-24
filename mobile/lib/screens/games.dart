import 'dart:math';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import 'dictionary.dart';
import '../core/illustrations.dart';
import '../core/game_session.dart';
import '../ui/design.dart';
import '../ui/game_motion.dart';

class _Target {
  final Word word;
  final String clue;
  final PictureWord? art;
  final bool english;
  const _Target(this.word, this.clue, this.art, {this.english = false});
}

Future<List<_Target>> _catalog({int? folder}) async {
  final words = await store.savedWords(folder: folder);
  final definitions = await store.firstDefinitions(
    words
        .where((w) => pictureFor(w.lemma) == null && w.translation.isEmpty)
        .map((w) => w.id),
  );
  final targets = <_Target>[], clues = <String>{};
  for (final w in words) {
    final p = pictureFor(w.lemma);
    var clue = store.editorialMeaning(w) ?? p?.meaning ?? w.translation;
    var english = false;
    if (clue.isEmpty) {
      clue = definitions[w.id] ?? '';
      english = clue.isNotEmpty;
    }
    if (clue.isNotEmpty && clues.add(clue)) {
      targets.add(_Target(w, clue, p, english: english));
    }
  }
  return targets;
}

class MemoryGameScreen extends StatefulWidget {
  final bool pictures;
  final int? folder;
  const MemoryGameScreen({super.key, this.pictures = true, this.folder});
  @override
  State<MemoryGameScreen> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGameScreen> {
  List<_Target>? questions;
  List<_Target> pool = [];
  final List<_Target> mistakes = [];
  RecallRound? round;
  int index = 0, points = 0, perfect = 0, combo = 0, trigger = 0;
  int? selected;
  bool saving = false, committed = false, done = false;
  String? error;
  final random = Random();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      questions = null;
      error = null;
      done = false;
      index = 0;
      points = 0;
      perfect = 0;
      combo = 0;
      mistakes.clear();
    });
    try {
      pool = await _catalog(folder: widget.folder);
      final q = List<_Target>.of(pool)..shuffle(random);
      if (!mounted) return;
      questions = q.length < 4 ? [] : q.take(10).toList();
      if (questions!.isNotEmpty) {
        setup();
      }
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => error = 'O‘yin ochilmadi. Qayta urinib ko‘ring.');
      }
    }
  }

  void setup() {
    final target = questions![index];
    final distractions =
        pool
            .where(
              (p) =>
                  p.word.id != target.word.id &&
                  p.clue != target.clue &&
                  p.word.lemma != target.word.lemma,
            )
            .toList()
          ..shuffle(random);
    // Favor a few plausible choices from the same topic without duplicates.
    final sameTopic = distractions
        .where(
          (p) => target.art != null && p.art?.category == target.art!.category,
        )
        .take(2)
        .toList();
    final choices = [
      target,
      ...sameTopic,
      ...distractions
          .where((p) => !sameTopic.contains(p))
          .take(3 - sameTopic.length),
    ];
    pool = [...pool.where((p) => p.word.id != target.word.id), target];
    final ids = choices.map((p) => p.word.id).toList()..shuffle(random);
    round = RecallRound(target.word.id, ids);
    selected = null;
    committed = false;
    saving = false;
    error = null;
  }

  Future<void> choose(int id) async {
    if (saving || round == null) return;
    final result = round!.choose(id);
    if (result == null) return;
    setState(() {
      selected = id;
      trigger++;
    });
    if (!result) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.lightImpact();
    await commit();
  }

  Future<void> commit() async {
    if (saving || committed) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await store.gameReview(questions![index].word, round!.perfect);
      if (!mounted) return;
      setState(() {
        saving = false;
        committed = true;
        if (round!.perfect) {
          perfect++;
          combo++;
          points += 10 + min(combo - 1, 5) * 2;
        } else {
          combo = 0;
          points += 3;
          if (!mistakes.any((t) => t.word.id == questions![index].word.id)) {
            mistakes.add(questions![index]);
          }
        }
      });
      // Decode only the next visible-sized photograph while feedback is shown.
      // Keeping the same provider dimensions as WordArt avoids a second decode.
      if (index + 1 < questions!.length) {
        final art = questions![index + 1].art;
        if (art != null && art.asset.endsWith('.webp')) {
          final pixels = (170 * MediaQuery.devicePixelRatioOf(context))
              .ceil()
              .clamp(64, 1200);
          unawaited(
            precacheImage(
              ResizeImage(AssetImage(art.asset), width: pixels),
              context,
              onError: (_, _) {},
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Natija saqlanmadi. Qayta saqlang.';
        });
      }
    }
  }

  void retryMistakes() {
    if (mistakes.isEmpty) return;
    final retry = List<_Target>.of(mistakes)..shuffle(random);
    setState(() {
      questions = retry;
      index = 0;
      points = perfect = combo = 0;
      done = false;
      mistakes.clear();
      setup();
    });
  }

  Widget reviewMistakes(BuildContext c) => Glass(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Qayta ko‘riladigan so‘zlar', style: display(18)),
        const SizedBox(height: 6),
        Text(
          'Shu turda adashgan ${mistakes.length} ta so‘z. Tinglang va yana bir marta toping.',
          style: TextStyle(fontSize: 12, color: muted(c)),
        ),
        const SizedBox(height: 8),
        for (final item in mistakes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.word.lemma,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.clue,
                        style: TextStyle(color: muted(c), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                AudioButton(item.word.lemma),
              ],
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TactileButton(
            'Shu so‘zlarni qaytarish',
            secondary: true,
            onTap: retryMistakes,
          ),
        ),
      ],
    ),
  );

  void next() {
    if (!committed) return;
    setState(() {
      if (index + 1 >= questions!.length) {
        done = true;
      } else {
        index++;
        setup();
      }
    });
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: widget.pictures ? 'Rasmni top' : 'Eslab top',
    child: _body(c),
  );
  Widget _body(BuildContext c) {
    if (questions == null) {
      return error != null
          ? EmptyState(
              'O‘yin ochilmadi',
              error!,
              action: TactileButton('Qayta urinish', onTap: load),
            )
          : const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (questions!.isEmpty) {
      return EmptyState(
        'Avval so‘z saqlang',
        'Kamida 4 ta ma’nosi turlicha so‘zni lug‘atdan saqlang.',
        action: TactileButton(
          'Lug‘atni ochish',
          onTap: () => Navigator.pushReplacement(
            c,
            MaterialPageRoute(builder: (_) => const DictionaryScreen()),
          ),
        ),
      );
    }
    if (done) {
      return GameFinish(
        correct: perfect,
        total: questions!.length,
        points: points,
        replay: load,
        review: mistakes.isEmpty ? null : reviewMistakes(c),
      );
    }
    final target = questions![index];
    final solved = round!.solved;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 5,
          children: [
            Text(
              'Savol ${index + 1} / ${questions!.length}',
              style: TextStyle(color: muted(c), fontSize: 13),
            ),
            Text(
              '$points ball${combo > 1 ? ' · $combo ketma-ket' : ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: (index + (solved ? 1 : 0)) / questions!.length,
          ),
          duration: motionDuration(c, 260),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 5,
              backgroundColor: palette(c).border,
            ),
          ),
        ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: motionDuration(c, 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) => AnimatedBuilder(
            animation: a,
            child: RepaintBoundary(child: child),
            builder: (_, child) => Opacity(
              opacity: a.value.clamp(0, 1),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .001)
                  ..translateByDouble(0, (1 - a.value) * 28, 0, 1)
                  ..rotateY((1 - a.value) * .55)
                  ..scaleByDouble(.9 + .1 * a.value, .9 + .1 * a.value, 1, 1),
                child: child,
              ),
            ),
          ),
          child: Glass(
            key: ValueKey('question-$index'),
            child: Column(
              children: [
                if (widget.pictures && target.art != null) ...[
                  ExcludeSemantics(
                    child: WordArt(
                      target.art!,
                      width: 170,
                      height: 170,
                      radius: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  target.english
                      ? 'Inglizcha izohga mos so‘zni toping'
                      : 'Inglizchasini toping',
                  style: TextStyle(color: muted(c), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  target.clue,
                  textAlign: TextAlign.center,
                  style: display(target.english ? 18 : 23),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...round!.options.map((id) {
          final t = pool.firstWhere((p) => p.word.id == id);
          final wrong = round!.missed.contains(id);
          final right = solved && id == round!.answer;
          final color = right
              ? palette(c).success
              : wrong
              ? palette(c).error
              : palette(c).border;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnswerMotion(
              trigger: selected == id ? trigger : 0,
              success: right,
              child: Semantics(
                button: true,
                enabled: !solved && !wrong,
                label: t.word.lemma,
                child: AnimatedContainer(
                  duration: motionDuration(c, 220),
                  decoration: BoxDecoration(
                    color: (right || wrong)
                        ? color.withValues(alpha: .12)
                        : surface(c),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color,
                      width: right || wrong ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('option-$id'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: solved || wrong || saving ? null : () => choose(id),
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.word.lemma,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (right || wrong) ...[
                            const SizedBox(width: 10),
                            AppIcon(
                              right ? AppIcons.check : AppIcons.close,
                              size: 21,
                              color: color,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        AnimatedSize(
          duration: motionDuration(c, 240),
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              if (selected != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    solved
                        ? (round!.perfect
                              ? 'To‘g‘ri! Davom etamiz.'
                              : 'Topdingiz! Bu so‘zni tezroq qaytaramiz.')
                        : 'Yana bir bor urinib ko‘ring.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: solved
                          ? Theme.of(c).colorScheme.primary
                          : muted(c),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (solved) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AudioButton(target.word.lemma),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'So‘zni tinglang',
                        style: TextStyle(fontSize: 12, color: muted(c)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text(error!, style: TextStyle(color: palette(c).error)),
                SizedBox(
                  width: double.infinity,
                  child: TactileButton(
                    error != null
                        ? 'Qayta saqlash'
                        : saving
                        ? 'Saqlanmoqda…'
                        : index + 1 == questions!.length
                        ? 'Natijani ko‘rish'
                        : 'Keyingi so‘z',
                    icon: AppIcons.arrowForward,
                    onTap: saving
                        ? null
                        : error != null
                        ? commit
                        : next,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class PairGameScreen extends StatefulWidget {
  const PairGameScreen({super.key});
  @override
  State<PairGameScreen> createState() => _PairState();
}

class _PairState extends State<PairGameScreen> {
  List<_Target>? words;
  List<int> order = [];
  Set<int> matched = {}, mistakes = {};
  int? first, second;
  bool busy = false, done = false;
  int trigger = 0, moves = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      words = null;
      error = null;
      done = false;
      matched = {};
      mistakes = {};
      first = null;
      second = null;
      moves = 0;
      busy = false;
    });
    try {
      final all = await _catalog();
      all.shuffle();
      // Meanings must also be unique, so every card has just one match.
      final unique = <_Target>[];
      for (final p in all) {
        if (!unique.any((t) => t.clue == p.clue)) unique.add(p);
        if (unique.length == 4) break;
      }
      if (!mounted) return;
      setState(() {
        words = unique;
        order = List.generate(unique.length * 2, (i) => i)..shuffle();
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Juftliklar ochilmadi.');
    }
  }

  Future<void> select(int card) async {
    if (busy || matched.contains(card % 4) || first == card) return;
    if (first == null) {
      setState(() => first = card);
      HapticFeedback.selectionClick();
      return;
    }
    final a = first! % 4, b = card % 4;
    setState(() {
      second = card;
      busy = true;
      moves++;
      trigger++;
      error = null;
    });
    if (a == b) {
      try {
        await store.gameReview(words![a].word, !mistakes.contains(a));
        if (!mounted) return;
        HapticFeedback.lightImpact();
        setState(() {
          matched.add(a);
          first = null;
          second = null;
          busy = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            busy = false;
            first = null;
            second = null;
            error = 'Natija saqlanmadi. Juftlikni yana tanlang.';
          });
        }
      }
    } else {
      mistakes.addAll([a, b]);
      await Future<void>.delayed(motionDuration(context, 650));
      if (mounted) {
        setState(() {
          first = null;
          second = null;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Juftini top',
    child: words == null
        ? (error != null
              ? EmptyState(
                  'O‘yin ochilmadi',
                  error!,
                  action: TactileButton('Qayta urinish', onTap: load),
                )
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)))
        : words!.length < 4
        ? EmptyState(
            'Avval so‘z saqlang',
            'Kamida 4 ta turli ma’no kerak.',
            action: TactileButton(
              'Lug‘atni ochish',
              onTap: () => Navigator.pushReplacement(
                c,
                MaterialPageRoute(builder: (_) => const DictionaryScreen()),
              ),
            ),
          )
        : done
        ? GameFinish(
            correct: 4 - mistakes.length,
            total: 4,
            points: (4 - mistakes.length) * 10 + mistakes.length * 3,
            replay: load,
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Inglizcha so‘zni o‘zbekcha ma’nosi bilan juftlang.',
                style: TextStyle(color: muted(c), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                '${matched.length} / 4 juftlik · $moves urinish',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (c, b) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: order.map((card) {
                    final id = card % 4;
                    final found = matched.contains(id),
                        selected = first == card || second == card;
                    final wrong =
                        selected && second != null && first! % 4 != second! % 4;
                    final color = found
                        ? palette(c).success
                        : wrong
                        ? palette(c).error
                        : selected
                        ? Theme.of(c).colorScheme.primary
                        : palette(c).border;
                    return SizedBox(
                      width: (b.maxWidth - 12) / 2,
                      child: AnswerMotion(
                        trigger: selected ? trigger : 0,
                        success: !wrong,
                        child: AnimatedContainer(
                          duration: motionDuration(c, 260),
                          constraints: const BoxConstraints(minHeight: 92),
                          decoration: BoxDecoration(
                            color: found
                                ? color.withValues(alpha: .12)
                                : surface(c),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: color,
                              width: selected || found ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            key: ValueKey('pair-$card'),
                            onTap: found || busy ? null : () => select(card),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: motionDuration(c, 260),
                                    child: found
                                        ? AppIcon(
                                            AppIcons.check,
                                            key: ValueKey('matched-$card'),
                                            color: color,
                                            size: 22,
                                          )
                                        : Text(
                                            card < 4 ? 'English' : 'O‘zbekcha',
                                            key: ValueKey('label-$card'),
                                            style: TextStyle(
                                              color: muted(c),
                                              fontSize: 10,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    card < 4
                                        ? words![id].word.lemma
                                        : words![id].clue,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(color: palette(c).error),
                  ),
                ),
              if (matched.length == 4) ...[
                const SizedBox(height: 24),
                TactileButton(
                  'Natijani ko‘rish',
                  onTap: () => setState(() => done = true),
                ),
              ],
            ],
          ),
  );
}

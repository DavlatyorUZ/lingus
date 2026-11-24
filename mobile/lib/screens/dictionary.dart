import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/design.dart';
import '../ui/search_tools.dart';
import '../ui/base_forms.dart';
import '../core/morphology.dart';
import '../core/lexical_presentation.dart';
import '../core/models.dart';
import '../core/illustrations.dart';
import 'learn.dart';
import '../core/account_api.dart';
import '../core/voice_search.dart';

Future<void> openWord(
  BuildContext c,
  Word w, {
  String? sourceForm,
  BaseForm? analysis,
}) async {
  try {
    await store.rememberViewed(w);
  } catch (_) {
    /* Details remain usable when history cannot be written. */
  }
  if (!c.mounted) return;
  await Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) =>
          WordScreen(word: w, sourceForm: sourceForm, analysis: analysis),
    ),
  );
}

class DictionaryScreen extends StatefulWidget {
  final String initial;
  final String initialLevel;
  const DictionaryScreen({
    super.key,
    this.initial = '',
    this.initialLevel = '',
  });
  @override
  State<DictionaryScreen> createState() => _DictionaryState();
}

class _DictionaryState extends State<DictionaryScreen> {
  final controller = TextEditingController();
  Timer? debounce;
  List<Word> words = [], suggestions = [];
  List<BaseForm> forms = [];
  String lv = '';
  bool reverse = false, busy = true, more = true, listening = false;
  String? owner;
  int generation = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    controller.text = widget.initial;
    lv = '';
    owner = store.accountId;
    store.addListener(storeChanged);
    load();
  }

  @override
  void dispose() {
    store.removeListener(storeChanged);
    controller.dispose();
    debounce?.cancel();
    super.dispose();
  }

  void storeChanged() {
    if (!mounted) return;
    if (owner != store.accountId) {
      owner = store.accountId;
      controller.clear();
      load();
    } else if (controller.text.trim().isEmpty && !busy) {
      load();
    }
  }

  Future<void> open(Word word) async {
    await openWord(context, word);
    if (mounted && controller.text.trim().isEmpty) await load();
  }

  Future<void> listen() async {
    final account = store.accountId;
    setState(() => listening = true);
    FocusScope.of(context).unfocus();
    try {
      final text = await VoiceSearch.recognize(reverse: reverse);
      if (!mounted || account != store.accountId || text == null) return;
      controller.text = text;
      await load();
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> load({bool append = false}) async {
    debounce?.cancel();
    final run = ++generation;
    final query = controller.text, filter = lv;
    final reversed = reverse;
    setState(() {
      busy = true;
      error = null;
    });
    if (!append) {
      words = [];
      forms = [];
    }
    if (query.trim().length > 160) {
      setState(() {
        busy = false;
        error = 'Lug‘at uchun 160 belgigacha bo‘lgan so‘z yoki qisqa ibora kiriting.';
      });
      return;
    }
    try {
      final r = query.trim().isEmpty
          ? await store.recentViewed()
          : await store.search(
              query,
              lv: filter,
              reverse: reversed,
              offset: append ? words.length : 0,
            );
      final spelling = query.trim().isNotEmpty && !reversed && r.isEmpty
          ? await store.spellingSuggestions(query)
          : <Word>[];
      final inflections = query.trim().isEmpty || reversed
          ? <BaseForm>[]
          : await store.baseForms(query, includeUnchanged: true);
      if (!mounted || run != generation) return;
      setState(() {
        suggestions = spelling;
        forms = inflections;
        words = append ? [...words, ...r] : r;
        more = query.trim().isNotEmpty && r.length == 40;
        busy = false;
      });
    } catch (_) {
      if (mounted && run == generation) {
        setState(() {
          busy = false;
          error = 'Qidiruv bajarilmadi. Qayta urinib ko‘ring.';
        });
      }
    }
  }

  Future<void> translateMissing() async {
    final query = controller.text.trim();
    if (query.isEmpty || query.length > 160 || busy) return;
    final run = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await accountApi.request(
        '/dictionary/translate',
        method: 'POST',
        body: {'text': query},
      );
      final raw = (result['word'] as Map).cast<String, dynamic>();
      await store.cacheRemoteWord(raw);
      if (!mounted || run != generation) return;
      setState(() {
        words = [Word.from(raw.cast<String, Object?>())];
        more = false;
        busy = false;
      });
    } catch (e) {
      if (mounted && run == generation) {
        setState(() {
          busy = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final recent = controller.text.trim().isEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            children: [
              Expanded(child: Text('Lug‘at', style: display(22))),
              if (!recent)
                Text(
                  reverse ? 'UZ → EN' : 'EN → UZ',
                  style: TextStyle(fontSize: 11, color: muted(c)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: const ValueKey('dictionary-results'),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              const ComingTools(),
              const SizedBox(height: 18),
              if (recent) ...[
                Text('Oxirgi ko‘rilganlar', style: display(15)),
                const SizedBox(height: 10),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                EmptyState(
                  error!,
                  '',
                  action: TactileButton('Qayta urinish', onTap: () => load()),
                )
              else if (recent && words.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 18,
                  ),
                  child: Column(
                    children: [
                      AppIcon(AppIcons.history, size: 32, color: muted(c)),
                      const SizedBox(height: 12),
                      Text(
                        'Qaysi so‘zni o‘rganamiz?',
                        style: display(17),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pastdan so‘z izlang. Ma’nosini ochgan so‘zlaringiz shu yerda qoladi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: muted(c)),
                      ),
                    ],
                  ),
                )
              else ...[
                if (store.spellingAliases[normalize(controller.text)] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'To‘g‘ri yozilishi: ${store.spellingAliases[normalize(controller.text)]}',
                      style: TextStyle(color: muted(c), fontSize: 12),
                    ),
                  ),
                if (forms.isNotEmpty)
                  BaseFormsCard(
                    forms: forms,
                    originalExists: words.any(
                      (w) =>
                          normalize(w.lemma) ==
                          normalizeFormInput(controller.text),
                    ),
                    onOpen: (f) =>
                        openWord(c, f.word, sourceForm: f.input, analysis: f),
                  ),
                for (final word in words)
                  WordTile(
                    word,
                    key: ValueKey(word.id),
                    onTap: () => open(word),
                  ),
                if (words.isEmpty)
                  EmptyState(
                    'So‘z topilmadi',
                    'Yozilishini tekshiring yoki ma’nosini aniqlang.',
                    icon: AppIcons.searchOff,
                    action: TactileButton(
                      'Ma’nosini aniqlash',
                      onTap: translateMissing,
                    ),
                  ),
                if (suggestions.isNotEmpty) ...[
                  Text(
                    'Shuni nazarda tutdingizmi?',
                    style: TextStyle(fontSize: 12, color: muted(c)),
                  ),
                  Wrap(
                    spacing: 6,
                    children: suggestions
                        .map(
                          (w) => ActionChip(
                            label: Text(w.lemma),
                            onPressed: () {
                              controller.text = w.lemma;
                              load();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (more && words.isNotEmpty)
                  TextButton(
                    onPressed: busy ? null : () => load(append: true),
                    child: const Text('Yana ko‘rsatish'),
                  ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            8,
            14,
            MediaQuery.paddingOf(c).bottom + 8,
          ),
          child: SearchComposer(
            controller: controller,
            reverse: reverse,
            busy: busy,
            listening: listening,
            onVoice: listen,
            onSwap: () {
              reverse = !reverse;
              load();
            },
            onSearch: () {
              FocusScope.of(c).unfocus();
              load();
            },
            onClear: () {
              controller.clear();
              load();
            },
            onChanged: (_) {
              debounce?.cancel();
              generation++;
              setState(() {
                words = [];
                forms = [];
                busy = true;
                error = null;
              });
              debounce = Timer(const Duration(milliseconds: 230), () => load());
            },
          ),
        ),
      ],
    );
  }
}

class WordScreen extends StatefulWidget {
  final Word word;
  final String? sourceForm;
  final BaseForm? analysis;
  const WordScreen({
    super.key,
    required this.word,
    this.sourceForm,
    this.analysis,
  });
  @override
  State<WordScreen> createState() => _WordState();
}

class _WordState extends State<WordScreen> {
  Word? enriched;
  String? translationError;
  Future<void> fillTranslation() async {
    try {
      final result = await accountApi.request(
        '/dictionary/translate',
        method: 'POST',
        body: {'text': widget.word.lemma},
      );
      final raw = (result['word'] as Map).cast<String, dynamic>();
      await store.cacheRemoteWord(raw);
      if (mounted) {
        setState(() => enriched = Word.from(raw.cast<String, Object?>()));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => translationError =
              'Internet mavjud bo‘lganda ma’nosi aniqlanadi.',
        );
      }
    }
  }

  late Future<List<Map<String, Object?>>> future;
  int visibleSenses = 3;
  String? activeSense;
  bool sourcesOpen = false;
  bool allTranslations = false;
  String posFilter = '';
  @override
  void initState() {
    super.initState();
    future = store.senses(widget.word.id);
    if (widget.word.translation.isEmpty) fillTranslation();
  }

  @override
  Widget build(BuildContext c) {
    final w = enriched ?? widget.word;
    final selected = widget.analysis;
    final shortMeaning = selected == null
        ? w.translation
        : selected.meaning.isNotEmpty
        ? selected.meaning
        : selected.definition;
    final picture = pictureFor(w.lemma);
    final phonetic =
        picturePhonetics[w.lemma] ??
        w.ipa.replaceAll('ˈ', '').replaceAll('ˌ', '');
    return PageFrame(
      title: 'Lug‘at sahifasi',
      actions: [
        IconButton(
          tooltip: 'Ulashish',
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              text:
                  '${w.lemma}${w.level.isEmpty ? '' : ' · ${w.level}'}\n$shortMeaning\nLINGOY',
            ),
          ),
          icon: AppIcon(AppIcons.iosShare, size: 20),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
        children: [
          MotionIn(
            child: Column(
              children: [
                if (picture != null) ...[
                  Hero(
                    tag: 'word-art-${w.id}',
                    child: WordArt(
                      picture,
                      width: 140,
                      height: 140,
                      radius: 18,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'Rasmdagi ma’no: ${picture.meaning}',
                    style: TextStyle(fontSize: 10, color: muted(c)),
                  ),
                  if (photoFor(picture.word) case final photo?) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${photo.credit} · ${photo.license}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, color: muted(c)),
                    ),
                    TextButton(
                      onPressed: () => showLicensePage(
                        context: c,
                        applicationName: 'Lingoy',
                      ),
                      child: const Text('Rasm manbasi va litsenziyalar'),
                    ),
                  ],
                  const SizedBox(height: 22),
                ] else
                  const SizedBox(height: 16),
                SelectableText(
                  w.lemma,
                  textAlign: TextAlign.center,
                  style: display(38),
                ),
                if (widget.sourceForm != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${widget.sourceForm} → ${w.lemma}',
                    style: TextStyle(
                      color: Theme.of(c).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (phonetic.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    phonetic,
                    style: TextStyle(
                      fontSize: 17,
                      color: muted(c),
                      fontFamily: 'NotoSans',
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    Text(
                      'Inglizcha · Lug‘at',
                      style: TextStyle(color: muted(c), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AudioControl(w.lemma, 'en-GB', 'UK'),
                    _AudioControl(w.lemma, 'en-US', 'US'),
                    AnimatedBuilder(
                      animation: store,
                      builder: (c, _) => IconButton(
                        tooltip: store.saved.contains(w.id)
                            ? 'Saqlangan'
                            : 'So‘zni saqlash',
                        style: IconButton.styleFrom(
                          backgroundColor: surface(c),
                          minimumSize: const Size(54, 54),
                          side: BorderSide(color: Theme.of(c).dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        onPressed: () async {
                          await store.toggleSave(w);
                          if (c.mounted) {
                            toast(
                              c,
                              store.saved.contains(w.id)
                                  ? 'Shaxsiy lug‘atga saqlandi'
                                  : 'Lug‘atdan olib tashlandi',
                            );
                          }
                        },
                        icon: AnimatedSwitcher(
                          duration: motionDuration(c, 180),
                          child: AppIcon(
                            store.saved.contains(w.id)
                                ? AppIcons.bookmarkRounded
                                : AppIcons.bookmarkOutlineRounded,
                            key: ValueKey(store.saved.contains(w.id)),
                            color: Theme.of(c).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    TactileButton(
                      'Mashq',
                      icon: AppIcons.styleOutlined,
                      onTap: () async {
                        await store.ensureSaved(w.id);
                        if (c.mounted) {
                          Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) => const FlashcardScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 27),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette(c).surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette(c).border.withValues(alpha: .6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  selected == null
                      ? 'O‘ZBEKCHA MA’NO'
                      : selected.meaning.isEmpty
                      ? 'INGLIZCHA IZOH'
                      : 'TANLANGAN SHAKL · QISQA MA’NO',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  shortMeaning.isEmpty
                      ? 'Bu yozuv uchun o‘zbekcha tarjima hali kiritilmagan. Inglizcha izoh quyida mavjud.'
                      : allTranslations
                      ? shortMeaning
                      : shortMeaning
                            .split(';')
                            .take(3)
                            .map((x) => x.trim())
                            .join('; '),
                  style: display(21),
                ),
                if (shortMeaning.split(';').length > 3)
                  TextButton(
                    onPressed: () =>
                        setState(() => allTranslations = !allTranslations),
                    child: Text(
                      allTranslations ? 'Yig‘ish' : 'Barcha tarjimalar',
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ExpansionTile(
              onExpansionChanged: (v) => setState(() => sourcesOpen = v),
              trailing: AnimatedRotation(
                turns: sourcesOpen ? .5 : 0,
                duration: motionDuration(c, 220),
                child: AppIcon(AppIcons.chevronDown, size: 18),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(
                'Manbalar va daraja haqida',
                style: TextStyle(fontSize: 11, color: muted(c)),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tarjima: ${selected?.meaning.isNotEmpty == true
                        ? 'Lingoy original qisqa ma’no'
                        : w.translationSource.contains('AI definition-aligned')
                        ? 'Lingoy — AI yordamida, inglizcha ta’rif asosida'
                        : w.translationSource.contains('original editorial')
                        ? 'Lingoy tahririy lug‘ati'
                        : w.translationSource.replaceAll('LEXORA', 'Lingoy')}. ${w.level.isEmpty ? 'CEFR darajasi manbada mavjud emas.' : 'CEFR: ${w.levelSource.replaceAll('LEXORA', 'Lingoy')}. Daraja ma’noga qarab farqlanishi mumkin.'} ${picturePhonetics.containsKey(w.lemma) ? 'Rasmli to‘plam uchun US transkripsiyasi.' : 'CMU asosidagi urg‘usiz fonemalar ketma-ketligi.'}',
                    style: TextStyle(fontSize: 12, color: muted(c)),
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: future,
            builder: (c, s) {
              if (!s.hasData) {
                return Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: CircularProgressIndicator(color: muted(c)),
                  ),
                );
              }
              final allSenses = s.data!;
              final ordered = selected == null
                  ? allSenses
                  : <Map<String, Object?>>[
                      ...allSenses.where((s) => s['pos'] == selected.pos),
                      ...allSenses.where((s) => s['pos'] != selected.pos),
                    ];
              final senses = posFilter.isEmpty
                  ? ordered
                  : ordered.where((s) => s['pos'] == posFilter).toList();
              const posNames = {
                'v': 'Fe’l',
                'n': 'Ot',
                'a': 'Sifat',
                'r': 'Ravish',
                'function': 'Yordamchi so‘z',
              };
              final parts = ordered
                  .map((s) => s['pos'] as String)
                  .toSet()
                  .toList();
              final firstOpen = senses.isEmpty
                  ? ''
                  : senses.first['id'] as String;
              final active = activeSense ?? firstOpen;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Ma’nolar va misollar'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Ma’noni ochib, unga tegishli misol va sinonimlarni ko‘ring.',
                      key: const ValueKey('sense-count'),
                      style: TextStyle(color: muted(c), fontSize: 13),
                    ),
                  ),
                  if (parts.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['', ...parts]
                              .map(
                                (pos) => Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: ChoiceChip(
                                    key: ValueKey('sense-pos-$pos'),
                                    label: Text(
                                      pos.isEmpty
                                          ? 'Barchasi'
                                          : posNames[pos] ?? pos,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: posFilter == pos,
                                    onSelected: (_) => setState(() {
                                      posFilter = pos;
                                      visibleSenses = 3;
                                      activeSense = null;
                                    }),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ...senses
                      .take(visibleSenses)
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (e) => Padding(
                          key: ValueKey('sense-row-${e.value['id']}'),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SensePanel(
                            lemma: w.lemma,
                            sense: e.value,
                            index: e.key,
                            expanded: active == e.value['id'],
                            onToggle: () => setState(
                              () => activeSense = active == e.value['id']
                                  ? ''
                                  : e.value['id'] as String,
                            ),
                            onFollow: follow,
                          ),
                        ),
                      ),
                  if (senses.length > visibleSenses)
                    TextButton(
                      key: const ValueKey('more-senses'),
                      onPressed: () => setState(() => visibleSenses += 3),
                      child: const Text('Boshqa ma’nolarni ko‘rish'),
                    ),
                  const SizedBox(height: 26),
                  Text(
                    'Inglizcha izoh, misol va so‘z munosabatlari: Princeton WordNet 3.0. O‘zbekcha ma’no: UzWordnet 1.0 yoki ko‘rsatilgan original qo‘shimcha. Manbadagi xatolar saqlangan bo‘lishi mumkin.',
                    style: TextStyle(fontSize: 10, color: muted(c)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> follow(String word) async {
    final w = await store.lookup(word);
    if (!mounted) return;
    if (w == null) {
      toast(context, 'Alohida yozuv topilmadi');
      return;
    }
    openWord(context, w);
  }
}

class _AudioControl extends StatelessWidget {
  final String word, accent, label;
  const _AudioControl(this.word, this.accent, this.label);
  @override
  Widget build(BuildContext c) => OutlinedButton(
    onPressed: () => pronounce(c, word, accent: accent),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(64, 48),
      padding: const EdgeInsets.all(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(AppIcons.volumeUpOutlined, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _SensePanel extends StatelessWidget {
  final String lemma;
  final Map<String, Object?> sense;
  final int index;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(String) onFollow;
  const _SensePanel({
    required this.lemma,
    required this.sense,
    required this.index,
    required this.expanded,
    required this.onToggle,
    required this.onFollow,
  });
  @override
  Widget build(BuildContext c) {
    final examples = senseExamples(sense),
        synonyms = senseSynonyms(lemma, sense);
    final meaning = sense['meaning_uz'] as String? ?? '',
        definition = sense['definition'] as String? ?? '';
    final pos =
        {
          'n': 'Ot',
          'v': 'Fe’l',
          'a': 'Sifat',
          'r': 'Ravish',
          'function': 'Yordamchi so‘z',
        }[sense['pos']] ??
        'So‘z';
    final p = palette(c);
    return DecoratedBox(
      key: ValueKey('sense-${sense['id']}'),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1} · $pos',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted(c),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meaning.isNotEmpty ? meaning : definition,
                            maxLines: expanded ? null : 2,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: motionDuration(c, 180),
                      child: AppIcon(
                        AppIcons.chevronDown,
                        size: 18,
                        color: muted(c),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: motionDuration(c, 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (meaning.isNotEmpty && definition.isNotEmpty) ...[
                          Text(
                            definition,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: muted(c),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (examples.isNotEmpty) ...[
                          const Text(
                            'Misollar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          ...examples.map(
                            (e) => _ExampleCard(en: e.en, uz: e.uz),
                          ),
                        ],
                        if (synonyms.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Shu ma’nodagi sinonimlar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: synonyms
                                .map(
                                  (w) => TextButton(
                                    onPressed: () => onFollow(w),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(44, 44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    child: Text(
                                      w,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        FutureBuilder<List<String>>(
                          future: store.antonyms([sense]),
                          builder: (c, a) => !a.hasData || a.data!.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Qarama-qarshi ma’nolar',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 6,
                                      children: a.data!
                                          .take(4)
                                          .map(
                                            (w) => TextButton(
                                              onPressed: () => onFollow(w),
                                              child: Text(w),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final String en;
  final String? uz;
  const _ExampleCard({required this.en, this.uz});
  @override
  Widget build(BuildContext c) => Container(
    key: ValueKey('example-$en'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: palette(c).border.withValues(alpha: .45)),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(en, style: const TextStyle(fontSize: 15, height: 1.55)),
        if (uz?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          SelectableText(
            uz!,
            style: TextStyle(fontSize: 14, height: 1.5, color: muted(c)),
          ),
        ],
      ],
    ),
  );
}

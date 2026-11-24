import 'package:material_ui/material_ui.dart';

import '../ui/design.dart';
import '../ui/base_forms.dart';
import '../core/morphology.dart';
import '../core/models.dart';
import '../core/grammar_checker.dart';
import 'dictionary.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsState();
}

class _ToolsState extends State<ToolsScreen> {
  final input = TextEditingController();
  List<GrammarIssue> issues = [];
  bool checked = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void check() {
    setState(() {
      issues = checkGrammar(input.text);
      checked = true;
    });
  }

  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
    children: [
      Text('Yozuvni tekshirish', style: display(24)),
      const SizedBox(height: 16),
      Text(
        '$grammarRuleCount ta mahalliy qoida orqali ko‘p uchraydigan inglizcha xatolarni tekshiring.',
        style: TextStyle(color: muted(c), fontSize: 12),
      ),
      const SizedBox(height: 23),
      TextField(
        controller: input,
        minLines: 5,
        maxLines: 10,
        maxLength: 4000,
        onChanged: (_) => setState(() => checked = false),
        decoration: const InputDecoration(
          hintText: 'Masalan: She don’t like apples.\nI have went to school.',
        ),
      ),
      const SizedBox(height: 15),
      TactileButton(
        'Grammatikani tekshirish',
        icon: AppIcons.spellcheck,
        onTap: input.text.trim().isEmpty ? null : check,
      ),
      if (checked) ...[
        const SizedBox(height: 24),
        Glass(
          color: muted(c).withValues(alpha: .1),
          child: Row(
            children: [
              AppIcon(
                issues.isEmpty
                    ? AppIcons.checkCircleOutline
                    : AppIcons.manageSearch,
                color: muted(c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  issues.isEmpty
                      ? 'Mavjud qoidalar bo‘yicha xato topilmadi.'
                      : '${issues.length} ta tekshirish tavsiyasi topildi.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (issues.length > 1) ...[
          const SizedBox(height: 12),
          TactileButton(
            'Barcha tavsiyalarni qo‘llash',
            icon: AppIcons.check,
            secondary: true,
            onTap: () {
              try {
                input.text = applyGrammarIssues(input.text, issues);
              } on ArgumentError {
                toast(c, 'Matn o‘zgargan. Qayta tekshiramiz.');
              }
              check();
            },
          ),
        ],
        ...issues.map(
          (issue) => Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.original,
                    style: TextStyle(
                      color: palette(c).error,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    issue.replacement,
                    style: TextStyle(
                      color: muted(c),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    issue.explanation,
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 13),
                  TactileButton(
                    'Tavsiya etilganini qo‘llash',
                    secondary: true,
                    onTap: () {
                      input.text = input.text.replaceRange(
                        issue.start,
                        issue.end,
                        issue.replacement,
                      );
                      check();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 22),
      Text(
        'Bu to‘liq til modeli emas. Murakkab gap ma’nosi, barcha imlo xatolari va kontekstni tekshirmaydi. “Xato topilmadi” natijasi matn mutlaqo to‘g‘ri degani emas. Tavsiyani kontekstga qarab qo‘llang.',
        style: TextStyle(fontSize: 10, color: muted(c)),
      ),
      const SectionTitle('So‘z ma’nosini tekshiring'),
      TactileButton(
        'Oflayn tarjimani ochish',
        secondary: true,
        icon: AppIcons.translate,
        onTap: () => Navigator.push(
          c,
          MaterialPageRoute(builder: (_) => const TranslatorScreen()),
        ),
      ),
    ],
  );
}

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});
  @override
  State<TranslatorScreen> createState() => _TranslatorState();
}

class _TranslatorState extends State<TranslatorScreen> {
  final input = TextEditingController();
  List<Word> results = [];
  List<WordAnalysis> analyses = [];
  bool reverse = false, busy = false, searched = false;
  String note = '';
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> translate() async {
    if (busy || input.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final text = normalize(input.text);
      final w = reverse ? null : await store.lookup(text);
      var found = <Word>[];
      var analyzed = <WordAnalysis>[];
      var message = '';
      if (reverse) {
        found = await store.search(text, reverse: true, limit: 30);
      } else if (w != null && text.contains(' ')) {
        found = [w];
      } else {
        // First try an inflected phrasal verb, then analyze individual tokens.
        final phrase = await store.baseForms(text, includeUnchanged: true);
        if (text.contains(' ') && phrase.isNotEmpty) {
          analyzed = [WordAnalysis(text, w, phrase)];
        } else {
          analyzed = await store.analyzeText(text);
          if (analyzed.length > 1) message = 'Quyida matndagi so‘zlar va ularning mumkin bo‘lgan asosiy shakllari. Bu yaxlit gap tarjimasi emas.';
        }
      }
      if (mounted) {
        setState(() {
          results = found;
          analyses = analyzed;
          note = message;
          searched = true;
        });
      }
    } catch (_) {
      if (mounted) {
        toast(context, 'Qidiruv amalga oshmadi. Qayta urinib ko‘ring.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Oflayn tarjima',
    child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Tarjima', style: display(24)),
        const SizedBox(height: 18),
        Text(
          'Matndagi so‘zlarni toping: went → go, running → run. Tarjima va shakl tahlili to‘liq oflayn.',
          style: TextStyle(color: muted(c), fontSize: 12),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                reverse ? 'O‘zbekcha → English' : 'English → O‘zbekcha',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Tillarni almashtirish',
              onPressed: () => setState(() {
                reverse = !reverse;
                results = [];
                analyses = [];
                searched = false;
              }),
              icon: AppIcon(AppIcons.swapHoriz, color: muted(c)),
            ),
          ],
        ),
        TextField(
          controller: input,
          minLines: 2,
          maxLines: 5,
          maxLength: 300,
          onSubmitted: (_) => translate(),
          decoration: InputDecoration(
            hintText: reverse
                ? 'Masalan: bilim, kitob, maqsad'
                : 'Masalan: achievement, learn, look after',
          ),
        ),
        const SizedBox(height: 14),
        TactileButton(
          busy ? 'Qidirilmoqda…' : 'Tarjimasini topish',
          icon: AppIcons.translate,
          onTap: busy ? null : translate,
        ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              note,
              style: TextStyle(fontSize: 11, color: palette(c).error),
            ),
          ),
        if (searched && results.isEmpty && !analyses.any((a) => a.found))
          EmptyState(
            'Lug‘atda topilmadi',
            'Qisqaroq so‘z yozing yoki tarjima yo‘nalishini almashtiring.',
          ),
        const SizedBox(height: 22),
        ...results.map((w) => WordTile(w, onTap: () => openWord(c, w))),
        ...analyses
            .where((a) => a.found)
            .map(
              (a) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.direct != null)
                    WordTile(a.direct!, onTap: () => openWord(c, a.direct!)),
                  if (a.bases.isNotEmpty)
                    BaseFormsCard(
                      forms: a.bases,
                      originalExists: a.direct != null,
                      onOpen: (f) =>
                          openWord(c, f.word, sourceForm: f.input, analysis: f),
                    ),
                ],
              ),
            ),
        if (analyses.any((a) => !a.found))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Topilmagan so‘zlar: ${analyses.where((a) => !a.found).map((a) => a.input).join(', ')}',
              style: TextStyle(color: muted(c), fontSize: 11),
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'O‘zbekcha ma’nolar bazaning bir qismini qamrab oladi. Ko‘p ma’noli so‘zlarda to‘g‘ri ma’noni kontekstga qarab tanlang. To‘liq gapni avtomatik tarjima qilish bu versiyada yo‘q.',
          style: TextStyle(fontSize: 10, color: muted(c)),
        ),
      ],
    ),
  );
}

class PronunciationScreen extends StatefulWidget {
  const PronunciationScreen({super.key});
  @override
  State<PronunciationScreen> createState() => _PronunciationState();
}

class _PronunciationState extends State<PronunciationScreen> {
  final target = TextEditingController(text: 'achievement');
  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Talaffuz ustaxonasi',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Talaffuz', style: display(24)),
        const SizedBox(height: 25),
        TextField(
          controller: target,
          onChanged: (_) => setState(() {}),
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Inglizcha so‘z yoki ibora',
          ),
        ),
        const SizedBox(height: 22),
        Glass(
          child: Column(
            children: [
              const Eyebrow('QURILMADAGI OFLAYN OVOZ'),
              const SizedBox(height: 26),
              AppIcon(AppIcons.graphicEqRounded, size: 65, color: muted(c)),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AudioButton(target.text, accent: 'en-GB'),
                  const SizedBox(width: 10),
                  Text('UK'),
                  const SizedBox(width: 27),
                  AudioButton(target.text),
                  const SizedBox(width: 10),
                  Text('US'),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Avval tinglang, keyin ovoz chiqarib takrorlang.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted(c)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          'Faqat telefonga o‘rnatilgan oflayn inglizcha TTS ovozi ishlatiladi. Kerakli UK yoki US ovozi bo‘lmasa, ilova uni mavjud emas deb ko‘rsatadi. Mikrofon va ovoz yuborish funksiyasi yo‘q.',
          style: TextStyle(fontSize: 11, color: muted(c)),
        ),
      ],
    ),
  );
}

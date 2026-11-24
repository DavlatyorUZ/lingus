import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/core/morphology.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Purple brand with neutral surfaces has readable text in both themes', () {
    const p = LingoyPalette.night;
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final t in [appTheme(false), appTheme(true)]) {
      final x = t.extension<LingoyPalette>()!;
      expect(contrast(x.text, x.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(x.textMuted, x.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(x.onCta, x.cta), greaterThanOrEqualTo(4.5));
    }
    expect(p.lerp(LingoyPalette.day, 1).bg, LingoyPalette.day.bg);
  });
  testWidgets('Every local SVG parses and renders without icon fonts', (
    tester,
  ) async {
    for (final path in AppIcons.assets) {
      final svg = await rootBundle.loadString(path);
      expect(svg, contains('<svg'));
      expect(svg, isNot(contains('<image')));
      expect(svg, isNot(contains('href=')));
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(true),
        home: Scaffold(
          body: Wrap(
            children: AppIcons.assets
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: AppIcon(a),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNWidgets(AppIcons.assets.length));
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('SVG stays 18px inside a larger input target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(true),
        home: const Scaffold(
          body: SizedBox(
            width: 48,
            height: 48,
            child: AppIcon(AppIcons.search, size: 18),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SvgPicture)), const Size(18, 18));
  });
  test('Bilingual pairs and emoji-free app source', () async {
    final pack = jsonDecode(
      await rootBundle.loadString('assets/sense_examples.json'),
    );
    final senses = pack['senses'] as Map<String, dynamic>;
    expect(senses.length, greaterThanOrEqualTo(113));
    expect(senses['v345761']['meaning_uz'], contains('boshlamoq'));
    for (final e in senses.entries) {
      expect(e.key, matches(RegExp(r'^[nvar]\d+$')));
      expect(e.value['meaning_uz'], isNotEmpty);
      for (final ex in e.value['examples']) {
        expect(ex['en'], isNotEmpty);
        expect(ex['uz'], isNotEmpty);
      }
    }
    final emoji = RegExp(
      '[\u{1F000}-\u{1FAFF}\u2600-\u27BF\uFE0F\u200D]',
      unicode: true,
    );
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(emoji.hasMatch(f.readAsStringSync()), false, reason: f.path);
    }
  });
  testWidgets('Reduced motion and CTA interaction', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(true),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: TactileButton(
              'Boshlash',
              icon: AppIcons.arrowForward,
              onTap: () => calls++,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
    await tester.tap(find.text('Boshlash'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
  test('Tokenization handles punctuation, case, and possessives', () {
    expect(
      englishTokens('She went, was running; STUDIED. teacher’s teachers\'!'),
      ['she', 'went', 'was', 'running', 'studied', "teacher's", "teachers'"],
    );
    expect(regularForms('sing').where((x) => x.pos == 'v'), isEmpty);
    expect(regularForms('hoping').where((x) => x.lemma == 'hop'), isEmpty);
    expect(regularForms('hopping').any((x) => x.lemma == 'hop'), true);
  });
  test('Surrounding quotes and punctuation keep possessives intact', () {
    for (final pair in {
      "'Running'": 'running',
      '“studied!”': 'studied',
      '[(running)].': 'running',
      "teacher's": "teacher's",
      "teachers'": "teachers'",
    }.entries) {
      expect(normalizeFormInput(pair.key), pair.value, reason: pair.key);
    }
    expect(
      englishTokens(
        "She said 'running', \"studied\", and ‘read’. teachers' books; teacher's pen. Don't.",
      ),
      [
        'she',
        'said',
        'running',
        'studied',
        'and',
        'read',
        "teachers'",
        'books',
        "teacher's",
        'pen',
        "don't",
      ],
    );
  });
}

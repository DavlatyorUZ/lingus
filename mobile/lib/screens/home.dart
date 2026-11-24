import 'package:material_ui/material_ui.dart';

import '../ui/design.dart';
import '../ui/tab_motion.dart';
import '../ui/word_journey.dart';
import 'collections.dart';
import '../core/models.dart';
import '../core/illustrations.dart';
import 'dictionary.dart';
import 'vocabulary.dart';
import 'pictures.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onTab;
  final DateTime? referenceTime;
  const HomeScreen({super.key, required this.onTab, this.referenceTime});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  late final Future<Word?> daily = _daily();
  Future<Word?> _daily() async {
    final p =
        starterPictureWords[(widget.referenceTime ?? DateTime.now())
                .difference(DateTime(2026))
                .inDays %
            starterPictureWords.length];
    return await store.lookup(p.word) ?? await store.daily();
  }

  @override
  Widget build(BuildContext c) => ListView(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      28 + MediaQuery.paddingOf(c).bottom,
    ),
    children: [
      SceneItem(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salom, ${store.name}', style: display(23)),
                  const SizedBox(height: 5),
                  Text(
                    'Bugun nimani o‘rganamiz?',
                    style: TextStyle(color: muted(c), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SceneItem(
        delay: .06,
        child: Container(
          decoration: BoxDecoration(
            color: palette(c).surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: dark(c) ? palette(c).brandLight : palette(c).brand,
              width: 1.5,
            ),
          ),
          child: InkWell(
            key: const ValueKey('home-search'),
            onTap: () => widget.onTab(1),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette(c).cta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppIcon(
                      AppIcons.search,
                      size: 22,
                      color: palette(c).onCta,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'So‘z yoki iborani qidiring',
                      style: TextStyle(
                        color: palette(c).text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      const SceneItem(delay: .10, child: JourneyWelcome()),
      const SizedBox(height: 16),
      const SceneItem(delay: .16, child: EssentialsLinks()),
      const SectionTitle('Kun so‘zi'),
      FutureBuilder<Word?>(
        future: daily,
        builder: (c, s) {
          final w = s.data;
          if (w == null) {
            return const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final pic = pictureFor(w.lemma);
          return SceneItem(
            delay: .25,
            child: MotionIn(
              child: Glass(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => openWord(c, w),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (c, b) {
                            final large =
                                MediaQuery.textScalerOf(c).scale(14) > 23;
                            final text = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.lemma, style: display(26)),
                                const SizedBox(height: 7),
                                Text(
                                  pic?.meaning ?? w.translation,
                                  style: TextStyle(
                                    color: muted(c),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                            final art = pic == null
                                ? const SizedBox.shrink()
                                : WordArt(
                                    pic,
                                    width: 96,
                                    height: 96,
                                    radius: 12,
                                  );
                            return large
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      art,
                                      const SizedBox(height: 12),
                                      text,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: text),
                                      const SizedBox(width: 12),
                                      art,
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            LevelBadge(w.level),
                            const Spacer(),
                            AudioButton(w.lemma),
                            const SizedBox(width: 8),
                            const AppIcon(AppIcons.arrowForward, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      const SectionTitle('Tezkor bo‘limlar'),
      Glass(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            MenuRow(
              'Mening so‘zlarim',
              'Saqlangan so‘zlar va takrorlash',
              AppIcons.bookmarksOutlined,
              () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const VocabularyScreen()),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            MenuRow(
              'Rasmli lug‘at',
              '${pictureWords.length} ta rasmli yozuv',
              AppIcons.imageOutlined,
              () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const PicturesScreen()),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            MenuRow(
              'Onlayn xizmatlar',
              'Tarjima va tekshiruv',
              AppIcons.translate,
              () => widget.onTab(1),
            ),
          ],
        ),
      ),
    ],
  );
}

class MenuRow extends StatelessWidget {
  final String title, subtitle, icon;
  final VoidCallback onTap;
  const MenuRow(this.title, this.subtitle, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext c) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette(c).elevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: AppIcon(icon, size: 21)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: muted(c), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppIcon(AppIcons.chevronRight, size: 17, color: muted(c)),
        ],
      ),
    ),
  );
}

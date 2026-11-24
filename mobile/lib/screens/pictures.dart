import 'package:material_ui/material_ui.dart';

import '../core/illustrations.dart';
import '../ui/design.dart';
import 'dictionary.dart';

class PicturesScreen extends StatefulWidget {
  const PicturesScreen({super.key});
  @override
  State<PicturesScreen> createState() => _PicturesState();
}

class _PicturesState extends State<PicturesScreen> {
  String category = 'Barchasi';
  String query = '';
  List<PictureWord> visible = pictureWords;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void filter() {
    final base = category == 'Barchasi'
        ? pictureWords
        : picturesByCategory[category] ?? <PictureWord>[];
    final q = query.trim().toLowerCase();
    visible = q.isEmpty
        ? base
        : base
              .where(
                (p) =>
                    p.word.contains(q) || p.meaning.toLowerCase().contains(q),
              )
              .toList();
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> open(PictureWord p) async {
    final w = await store.lookup(p.word);
    if (!mounted) return;
    if (w != null) openWord(context, w);
  }

  @override
  Widget build(BuildContext c) {
    final pictures = visible;
    final large = MediaQuery.textScalerOf(c).scale(14) > 20;
    return PageFrame(
      title: 'Rasmli lug‘at',
      actions: const [ThemeToggle()],
      child: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pictureWords.length} ta rasmli yozuv\n${pictureWords.where((p) => !p.word.contains(' ')).length} ta so‘z · ${pictureWords.where((p) => p.word.contains(' ')).length} ta ibora',
                    style: TextStyle(color: muted(c), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) => setState(() {
                      query = value;
                      filter();
                    }),
                    decoration: const InputDecoration(
                      hintText: 'Rasmli so‘zni qidiring',
                      prefixIcon: AppIcon(AppIcons.search),
                    ),
                  ),
                  if (query.trim().isNotEmpty || category != 'Barchasi')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        '${pictures.length} ta natija',
                        style: TextStyle(color: muted(c), fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Barchasi', ...pictureCategories]
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(t),
                                selected: category == t,
                                onSelected: (_) => setState(() {
                                  category = t;
                                  filter();
                                }),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pictures.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                'Rasmli so‘z topilmadi',
                'Boshqa so‘z yoki mavzuni tanlang.',
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: large
                ? SliverList.builder(
                    itemCount: pictures.length,
                    itemBuilder: (c, i) {
                      final p = pictures[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Glass(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            onTap: () => open(p),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  WordArt(p, width: 70, height: 70, radius: 10),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.word,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          p.meaning,
                                          style: TextStyle(
                                            color: muted(c),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : SliverLayoutBuilder(
                    builder: (c, b) {
                      final columns = (b.crossAxisExtent / 160).floor().clamp(
                        2,
                        4,
                      );
                      final width =
                          (b.crossAxisExtent - (columns - 1) * 12) / columns;
                      final textHeight =
                          MediaQuery.textScalerOf(c).scale(14) * 4.5 + 30;
                      return SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (c, i) {
                            final p = pictures[i];
                            return Glass(
                              key: ValueKey(p.word),
                              padding: EdgeInsets.zero,
                              child: InkWell(
                                onTap: () => open(p),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AspectRatio(
                                        aspectRatio: 1,
                                        child: WordArt(p, radius: 10),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        p.word,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.meaning,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: muted(c),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: pictures.length,
                          addAutomaticKeepAlives: false,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: width - 20 + textHeight,
                        ),
                      );
                    },
                  ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Har bir rasm ko‘rsatilgan ma’noni ifodalaydi. Qolgan ma’nolar so‘z sahifasida berilgan.',
                style: TextStyle(color: muted(c), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

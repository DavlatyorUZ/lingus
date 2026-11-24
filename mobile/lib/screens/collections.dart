import 'package:material_ui/material_ui.dart';

import '../core/collections.dart';
import '../ui/design.dart';

class StudyCollectionScreen extends StatefulWidget {
  final String kind;
  const StudyCollectionScreen({super.key, required this.kind});
  @override
  State<StudyCollectionScreen> createState() => _CollectionState();
}

class _CollectionState extends State<StudyCollectionScreen> {
  final input = TextEditingController();
  late final Future<List<StudyEntry>> entries = loadEssentials();
  String group = 'Barchasi';
  bool savedOnly = false;
  Set<String> get saved =>
      (store.prefs.getStringList('essential-bookmarks') ?? []).toSet();
  Future<void> toggle(StudyEntry entry) async {
    final next = saved;
    next.contains(entry.id) ? next.remove(entry.id) : next.add(entry.id);
    if (await store.prefs.setStringList('essential-bookmarks', next.toList()) &&
        mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: widget.kind == 'daily' ? 'Kundalik so‘zlar' : 'Speaking iboralari',
    actions: [
      IconButton(
        tooltip: savedOnly ? 'Hammasini ko‘rish' : 'Saqlanganlarni ko‘rish',
        onPressed: () => setState(() => savedOnly = !savedOnly),
        icon: AppIcon(
          savedOnly ? AppIcons.bookmarkRounded : AppIcons.bookmarksOutlined,
        ),
      ),
    ],
    child: FutureBuilder<List<StudyEntry>>(
      future: entries,
      builder: (c, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Bo‘limni ochib bo‘lmadi. Qayta ochib ko‘ring.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!.where((e) => e.kind == widget.kind).toList();
        final groups = ['Barchasi', ...all.map((e) => e.group).toSet()];
        final query = normalizeStudyText(input.text);
        final bookmarks = saved;
        final visible = all
            .where(
              (e) =>
                  (group == 'Barchasi' || e.group == group) &&
                  (!savedOnly || bookmarks.contains(e.id)) &&
                  e.searchText.contains(query),
            )
            .toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.kind == 'daily'
                          ? 'Kundalik suhbatlarda kerak bo‘ladigan ${all.length} ta so‘z. Misolda qanday ishlatilishini ko‘ring.'
                          : 'Fikrni tabiiy ifodalash uchun ${all.length} ta ibora. Namunani o‘z tajribangizga moslab ayting.',
                      style: TextStyle(fontSize: 13, color: muted(c)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('collection-query'),
                      controller: input,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'So‘z, ibora yoki tarjima…',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(14),
                          child: AppIcon(AppIcons.search, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final value in groups)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(value),
                                selected: group == value,
                                onSelected: (_) =>
                                    setState(() => group = value),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${visible.length} ta ${widget.kind == 'daily' ? 'so‘z' : 'ibora'}${savedOnly ? ' · Saqlangan' : ''}',
                      style: TextStyle(fontSize: 12, color: muted(c)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(28),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Hozircha hech narsa topilmadi. Boshqa so‘z bilan qidiring yoki filtrni almashtiring.',
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (c, i) {
                  final e = visible[i];
                  final isSaved = bookmarks.contains(e.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Glass(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.group,
                            style: TextStyle(
                              fontSize: 10,
                              color: muted(c),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(e.word, style: display(21)),
                          const SizedBox(height: 6),
                          Text(
                            e.meaning,
                            style: TextStyle(fontSize: 14, color: muted(c)),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: palette(c).elevated,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.example,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  e.translation,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: muted(c),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              AudioButton(e.example),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Misolni tinglash',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: muted(c),
                                  ),
                                ),
                              ),
                              IconButton(
                                key: ValueKey('save-${e.id}'),
                                tooltip: isSaved
                                    ? 'Saqlanganlardan olish'
                                    : 'Saqlash',
                                onPressed: () => toggle(e),
                                icon: AppIcon(
                                  isSaved
                                      ? AppIcons.bookmarkRounded
                                      : AppIcons.bookmarkBorder,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class EssentialsLinks extends StatelessWidget {
  const EssentialsLinks({super.key});
  @override
  Widget build(BuildContext c) => Glass(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        _row(
          c,
          'daily',
          'Kundalik so‘zlar',
          'Ko‘p ishlatiladigan so‘zlar · misollar bilan',
          AppIcons.bookmarksOutlined,
        ),
        const Divider(height: 1, indent: 62, endIndent: 16),
        _row(
          c,
          'speaking',
          'Speaking iboralari',
          'Tabiiy suhbat · fikr va hikoya',
          AppIcons.headphonesOutlined,
        ),
      ],
    ),
  );
  Widget _row(
    BuildContext c,
    String kind,
    String title,
    String subtitle,
    String icon,
  ) => InkWell(
    key: ValueKey('collection-$kind'),
    borderRadius: BorderRadius.circular(18),
    onTap: () => Navigator.push(
      c,
      MaterialPageRoute(builder: (_) => StudyCollectionScreen(kind: kind)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          AppIcon(icon, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 11, color: muted(c))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppIcon(AppIcons.chevronRight, size: 18, color: muted(c)),
        ],
      ),
    ),
  );
}

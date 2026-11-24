import 'dart:io';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';

import '../core/vocabulary_csv.dart';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../ui/design.dart';
import '../core/models.dart';
import 'dictionary.dart';
import 'learn.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});
  @override
  State<VocabularyScreen> createState() => _VocabularyState();
}

class _VocabularyState extends State<VocabularyScreen> {
  int? folder;
  String query = '';
  bool transferring = false;
  final queryInput = TextEditingController();
  final Map<int, String> searchText = {};
  late Future<List<Word>> future;
  @override
  void initState() {
    super.initState();
    refresh();
    store.addListener(changed);
  }

  @override
  void dispose() {
    queryInput.dispose();
    store.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) refresh();
  }

  void refresh() {
    setState(() {
      future = readSaved(folder);
    });
  }

  Future<List<Word>> readSaved(int? selected) async {
    if (selected != null &&
        !(await store.folders()).any((f) => f['id'] == selected)) {
      if (folder == selected) folder = null;
      return store.savedWords();
    }
    return store.savedWords(folder: selected);
  }

  Future<void> addFolder() async {
    final name = await askText(
      context,
      'Yangi papka',
      hint: 'Masalan: IELTS so‘zlari',
    );
    if (name == null || name.isEmpty) return;
    try {
      await store.folderAdd(name);
    } catch (_) {
      if (mounted) {
        toast(context, 'Bu nomdagi papka mavjud yoki nom noto‘g‘ri.');
      }
    }
  }

  Future<void> export() async {
    if (transferring) return;
    setState(() => transferring = true);
    try {
      final words = await store.savedWords();
      if (words.isEmpty) {
        if (mounted) toast(context, 'Avval bir nechta so‘z saqlang.');
        return;
      }
      final csv = exportVocabulary(words);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/LINGOY_Lugat.csv');
      await file.writeAsString(csv, encoding: utf8);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'LINGOY shaxsiy lug‘atim'),
      );
    } catch (_) {
      if (mounted) toast(context, 'CSV eksporti bajarilmadi.');
    } finally {
      if (mounted) setState(() => transferring = false);
    }
  }

  Future<void> import() async {
    if (transferring) return;
    final destination = folder ?? 1;
    setState(() => transferring = true);
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: false,
      );
      if (r == null) return;
      final f = r.files.single;
      if (f.size > 5 * 1024 * 1024) {
        if (mounted) toast(context, 'CSV hajmi 5 MB dan kichik bo‘lsin.');
        return;
      }
      final bytes = f.bytes ?? await File(f.path!).readAsBytes();
      final parsed = await compute(parseVocabulary, utf8.decode(bytes));
      final report = await store.importVocabulary(
        parsed.lemmas,
        folder: destination,
      );
      if (mounted) {
        toast(
          context,
          '${report.added} ta yangi so‘z. Topilmagan: ${report.missing}. Takrorlar: ${report.duplicates}.${parsed.truncated ? ' Birinchi 10 000 satr olindi.' : ''}',
        );
      }
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) {
        toast(context, 'CSV o‘qilmadi. UTF-8 kodlangan faylni tanlang.');
      }
    } finally {
      if (mounted) setState(() => transferring = false);
    }
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Mening lug‘atim',
    actions: [
      PopupMenuButton<String>(
        enabled: !transferring,
        icon: AppIcon(AppIcons.moreVert),
        onSelected: (v) => v == 'export'
            ? export()
            : v == 'import'
            ? import()
            : addFolder(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'new', child: Text('Yangi papka')),
          PopupMenuItem(value: 'export', child: Text('CSV eksport')),
          PopupMenuItem(value: 'import', child: Text('CSV import')),
        ],
      ),
    ],
    child: FutureBuilder<List<Word>>(
      future: future,
      builder: (c, snapshot) {
        final all = snapshot.data ?? <Word>[];
        final list = query.isEmpty
            ? all
            : all
                  .where(
                    (w) => searchText
                        .putIfAbsent(
                          w.id,
                          () => normalize('${w.lemma} ${w.translation}'),
                        )
                        .contains(query),
                  )
                  .toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${store.saved.length} ta saqlangan so‘z',
                      style: display(24),
                    ),
                    const SizedBox(height: 22),
                    FutureBuilder<List<Map<String, Object?>>>(
                      future: store.folders(),
                      builder: (c, s) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text('Barchasi'),
                              selected: folder == null,
                              onSelected: (_) {
                                folder = null;
                                refresh();
                              },
                            ),
                            const SizedBox(width: 7),
                            ...?(s.data?.map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: GestureDetector(
                                  onLongPress: () => folderMenu(f),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${f['name']} · ${f['count']}',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    selected: folder == f['id'],
                                    onSelected: (_) {
                                      folder = f['id'] as int;
                                      refresh();
                                    },
                                  ),
                                ),
                              ),
                            )),
                            IconButton(
                              tooltip: 'Papka qo‘shish',
                              onPressed: addFolder,
                              icon: AppIcon(AppIcons.add, color: muted(c)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: queryInput,
                      onChanged: (q) => setState(() => query = normalize(q)),
                      decoration: InputDecoration(
                        hintText: 'Saqlangan so‘zlardan qidirish',
                        prefixIcon: AppIcon(AppIcons.search, color: muted(c)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (store.saved.isNotEmpty)
                      TactileButton(
                        'Takrorlashni boshlash',
                        icon: AppIcons.styleOutlined,
                        onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                            builder: (_) => FlashcardScreen(folder: folder),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),

                    if (transferring) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('CSV qayta ishlanmoqda…'),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            if (snapshot.hasError)
              SliverToBoxAdapter(
                child: EmptyState(
                  'Lug‘at ochilmadi',
                  'Qayta urinib ko‘ring.',
                  action: TactileButton('Qayta urinish', onTap: refresh),
                ),
              )
            else if (!snapshot.hasData)
              const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(22),
                sliver: SliverToBoxAdapter(
                  child: query.isNotEmpty
                      ? EmptyState(
                          'Mos so‘z topilmadi',
                          'Qidiruvni o‘zgartiring yoki tozalang.',
                          action: TactileButton(
                            'Qidiruvni tozalash',
                            secondary: true,
                            onTap: () {
                              queryInput.clear();
                              setState(() => query = '');
                            },
                          ),
                        )
                      : EmptyState(
                          folder == null
                              ? 'So‘zlar shu yerda jamlanadi'
                              : 'Bu papka hozircha bo‘sh',
                          'Lug‘atdan so‘z ochib, xatcho‘p belgisini bosing.',
                        ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final w = list[i];
                    return GestureDetector(
                      key: ValueKey('saved-${w.id}'),
                      onLongPress: () => move(w),
                      child: WordTile(w, onTap: () => openWord(c, w)),
                    );
                  },
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(22, 12, 22, 28),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'So‘zni bosib turing — boshqa papkaga ko‘chiring. Papka o‘chirilganda so‘zlar asosiy papkaga o‘tadi; takrorlash tarixi saqlanadi.',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> move(Word w) async {
    final fs = await store.folders();
    if (!mounted) return;
    final id = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Papkaga ko‘chirish', style: display(24)),
            ),
            ...fs.map(
              (f) => ListTile(
                title: Text(f['name'] as String),
                onTap: () => Navigator.pop(c, f['id'] as int),
              ),
            ),
          ],
        ),
      ),
    );
    if (id != null) await store.moveWord(w.id, id);
  }

  Future<void> folderMenu(Map<String, Object?> f) async {
    final id = f['id'] as int;
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Nomini o‘zgartirish'),
              onTap: () => Navigator.pop(c, 'rename'),
            ),
            if (id != 1)
              ListTile(
                title: Text('Papkani o‘chirish'),
                subtitle: Text('So‘zlar asosiy papkaga o‘tadi.'),
                onTap: () => Navigator.pop(c, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'rename') {
      final name = await askText(
        context,
        'Papka nomi',
        initial: f['name'] as String,
      );
      if (name != null && name.isNotEmpty) {
        try {
          await store.folderRename(id, name);
        } catch (_) {
          if (mounted) toast(context, 'Bu nomdan foydalanib bo‘lmaydi.');
        }
      }
    } else if (result == 'delete') {
      if (folder == id) folder = null;
      await store.folderDelete(id);
    }
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/core/store.dart';
import 'package:lingoy/core/models.dart';
import 'package:lingoy/core/vocabulary_csv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'CSV handles quotes, commas, mixed line endings and real apostrophes',
    () {
      final words = [
        Word(id: 1, lemma: 'apple', translation: 'olma, meva\nmisol'),
        Word(id: 2, lemma: "'tis", translation: 'it is'),
        Word(id: 3, lemma: '=formula'),
      ];
      final parsed = parseVocabulary(exportVocabulary(words));
      expect(parsed.lemmas, ['apple', "'tis", '=formula']);
      expect(
        parseVocabulary('lemma,translation\n"apple","one\r\ntwo"\nbook,kitob')
            .lemmas,
        ['apple', 'book'],
      );
      expect(() => parseVocabulary('word\napple'), throwsFormatException);
      expect(
        parseVocabulary('lemma\n${List.filled(10001, 'apple').join('\n')}')
            .truncated,
        true,
      );
    },
  );
  test(
    'Reverse search cannot fall back to an unrelated English name',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute(
        "CREATE TABLE entries(id INTEGER PRIMARY KEY,lemma TEXT,normalized TEXT,translation TEXT,level TEXT,translation_source TEXT)",
      );
      await db.execute(
        'CREATE VIRTUAL TABLE search USING fts4(lemma,translation,tokenize=unicode61)',
      );
      for (final row in [
        {
          'id': 1,
          'lemma': 'alphabet',
          'normalized': 'alphabet',
          'translation': '',
          'level': '',
          'translation_source': '',
        },
        {
          'id': 2,
          'lemma': 'book',
          'normalized': 'book',
          'translation': 'kitob',
          'level': 'A1',
          'translation_source': '',
        },
        {
          'id': 3,
          'lemma': 'bookshop',
          'normalized': 'bookshop',
          'translation': 'kitob do‘koni',
          'level': 'A2',
          'translation_source': '',
        },
      ]) {
        await db.insert('entries', row);
        await db.rawInsert(
          'INSERT INTO search(docid,lemma,translation) VALUES(?,?,?)',
          [row['id'], row['lemma'], row['translation']],
        );
      }
      final store = Store()..dict = db;
      expect(await store.search('alpha', reverse: true), isEmpty);
      expect((await store.search('kitob', reverse: true)).first.lemma, 'book');
      expect(await store.search('phab', bilingual: true), isEmpty);
      expect(await store.search(List.filled(200, 'a').join()), isEmpty);
    },
  );
  test('Bulk import preserves reviews, batches large lists, and reset clears study bookmarks', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('lingoy-v2-data-');
    await databaseFactory.setDatabasesPath(dir.path);
    SharedPreferences.setMockInitialValues({
      'name': 'Davlatyor',
      'theme': 'dark',
      'onboarded': true,
      'essential-bookmarks': ['example'],
    });
    final store = Store();
    await store.init();
    expect(store.ready, true, reason: store.error);
    addTearDown(() async {
      await store.dict.close();
      await store.user.close();
    });
    final apple = (await store.lookup('apple'))!;
    await store.review(apple, 2);
    final before = (await store.user.query(
      'saved',
      where: 'word_id=?',
      whereArgs: [apple.id],
    )).single;
    var changes = 0;
    void listener() => changes++;
    store.addListener(listener);
    final report = await store.importVocabulary([
      'apple',
      'APPLE',
      'book',
      'zzword_not_in_lingoy',
    ], folder: 9999);
    expect([report.added, report.missing, report.duplicates], [1, 1, 2]);
    expect(changes, 1);
    final after = (await store.user.query(
      'saved',
      where: 'word_id=?',
      whereArgs: [apple.id],
    )).single;
    expect(after, before);
    final names = (await store.dict.rawQuery(
      'SELECT normalized FROM entries WHERE id NOT IN (?,?) LIMIT 1200',
      [apple.id, (await store.lookup('book'))!.id],
    )).map((r) => r['normalized'] as String).toList();
    final bulk = await store.importVocabulary(names);
    expect(bulk.added, 1200);
    final ordered = await store.user.query('saved', orderBy: 'due,added');
    expect(
      (await store.savedWords()).map((w) => w.id),
      ordered.map((r) => r['word_id']),
    );
    store.removeListener(listener);
    await store.clearUserData();
    expect(store.saved, isEmpty);
    expect(store.prefs.getStringList('essential-bookmarks'), isNull);
    expect(store.prefs.getString('name'), 'Davlatyor');
    expect(store.prefs.getString('theme'), 'dark');
  });
}

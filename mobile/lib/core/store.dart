import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'study_game.dart' show editDistance;
import 'account_api.dart';
import 'vocabulary_csv.dart';
import 'morphology.dart';
import 'illustrations.dart';
import 'dictionary_storage.dart';
import '../ui/motion_policy.dart';

dynamic _decodeAsset(String text) => jsonDecode(text);
Future<dynamic> _readAssetJson(String path) async =>
    compute(_decodeAsset, await rootBundle.loadString(path));

class Store extends ChangeNotifier {
  late Database dict, user;
  late SharedPreferences prefs;
  Map<String, dynamic> coverage = {};
  Map<String, dynamic> senseExamples = {}, morphExceptions = {};
  final Map<String, Future<List<BaseForm>>> _formsCache = {};
  Map<String, String> baseGlosses = {}, sensePriority = {};
  Map<String, String> informalGlosses = {}, spellingAliases = {};
  Set<int> saved = {};
  String theme = 'light', level = 'B1', name = 'Til o‘rganuvchi';
  String motion = 'auto';
  Future<Map<String, int>>? _statsCache;
  Future<List<int>>? _weekCache;
  String _cacheDay = '';
  @override
  void notifyListeners() {
    _statsCache = null;
    _weekCache = null;
    super.notifyListeners();
  }

  void _checkDay() {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    if (day != _cacheDay) {
      _cacheDay = day;
      _statsCache = null;
      _weekCache = null;
    }
  }

  int goal = 10;
  bool ready = false;
  bool recovering = false;
  String startupStage = 'Oflayn lug‘at tayyorlanmoqda…';
  Future<void>? _initializing;
  String? error;
  Future<void> init() {
    if (ready) return Future.value();
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  Future<void> _init() async {
    error = null;
    recovering = false;
    startupStage = 'Sozlamalar yuklanmoqda…';
    notifyListeners();
    try {
      prefs = await SharedPreferences.getInstance();
      theme = prefs.getString('theme') ?? 'light';
      motion = prefs.getString('motion') ?? 'auto';
      await Future.wait([DeviceBudget.inspect(), loadPictureCatalog()]);
      level = prefs.getString('level') ?? 'B1';
      goal = prefs.getInt('goal') ?? 10;
      name = prefs.getString('name') ?? 'Til o‘rganuvchi';
      startupStage = 'So‘zlar va ma’nolar yuklanmoqda…';
      notifyListeners();
      coverage = await _readAssetJson('assets/coverage.json');
      senseExamples =
          ((await _readAssetJson('assets/sense_examples.json'))
                  as Map<String, dynamic>)['senses']
              as Map<String, dynamic>;
      morphExceptions =
          ((await _readAssetJson('assets/morph_exceptions.json'))
                  as Map<String, dynamic>)['forms']
              as Map<String, dynamic>;
      baseGlosses =
          (((await _readAssetJson('assets/base_glosses.json'))
                      as Map<String, dynamic>)['glosses']
                  as Map)
              .cast<String, String>();
      informalGlosses = ((await _readAssetJson(
        'assets/informal_glosses.json',
      )) as Map).cast<String, String>();
      spellingAliases = ((await _readAssetJson(
        'assets/spelling_aliases.json',
      )) as Map).cast<String, String>();
      sensePriority =
          (((await _readAssetJson('assets/sense_priority.json'))
                      as Map<String, dynamic>)['first_senses']
                  as Map)
              .cast<String, String>();
      startupStage = 'Lug‘at fayli tekshirilmoqda…';
      notifyListeners();
      final base = await getDatabasesPath();
      final file = File(p.join(base, 'lexora-content-v1.db'));
      final revision =
          (jsonDecode(
                await rootBundle.loadString('assets/dictionary_revision.json'),
              ) as Map)['sha256']
              as String;
      dict = await openDictionaryWithRecovery(
        file: file,
        revision: revision,
        needsInstall: prefs.getString('dictionary_sha256') != revision,
        onRecovery: () {
          recovering = true;
          notifyListeners();
        },
      );
      await prefs.setString('dictionary_sha256', revision);
      await _openUser('lexora-user.db');
      saved = (await user.query(
        'saved',
        columns: ['word_id'],
      )).map((m) => m['word_id'] as int).toSet();
      ready = true;
    } catch (e) {
      debugPrint('Lingoy startup: $e');
      error = e is FileSystemException && e.osError?.errorCode == 28
          ? 'Lug‘at uchun joy yetmayapti. Kamida 200 MB joy bo‘shating va qayta urinib ko‘ring.'
          : 'Lug‘atni tayyorlab bo‘lmadi. Qayta urinib ko‘ring. Saqlangan so‘zlaringiz o‘chirilmaydi.';
    }
    notifyListeners();
  }

  String? accountId;
  bool syncing = false;
  String? syncError;
  Timer? _syncTimer;
  Future<void> _openUser(String filename) async {
    user = await openDatabase(
      p.join(await getDatabasesPath(), filename),
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
      },
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE folders(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE)',
        );
        await db.insert('folders', {'id': 1, 'name': 'Mening so‘zlarim'});
        await db.execute(
          'CREATE TABLE saved(word_id INTEGER PRIMARY KEY,folder_id INTEGER NOT NULL DEFAULT 1 REFERENCES folders(id),added INTEGER NOT NULL,reps INTEGER NOT NULL DEFAULT 0,interval REAL NOT NULL DEFAULT 0,ease REAL NOT NULL DEFAULT 2.5,due INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT,word_id INTEGER,kind TEXT NOT NULL,correct INTEGER NOT NULL,grade INTEGER,created INTEGER NOT NULL,day TEXT NOT NULL)',
        );
        await db.execute('CREATE INDEX events_day ON events(day)');
        await db.execute(
          'CREATE TABLE history(query TEXT PRIMARY KEY,created INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE lessons(id TEXT PRIMARY KEY,completed INTEGER NOT NULL)',
        );
      },
    );
    await user.execute(
      'CREATE TABLE IF NOT EXISTS sync_queue(word_id INTEGER PRIMARY KEY,mutation TEXT NOT NULL,deleted INTEGER NOT NULL)',
    );
    await user.execute(
      'CREATE TABLE IF NOT EXISTS remote_words(id INTEGER PRIMARY KEY,json TEXT NOT NULL)',
    );
    await user.execute(
      'CREATE TABLE IF NOT EXISTS viewed_words(word_id INTEGER PRIMARY KEY,viewed_at INTEGER NOT NULL)',
    );
  }

  Future<void> cacheRemoteWord(Map<String, dynamic> word) async {
    await user.insert('remote_words', {
      'id': word['id'],
      'json': jsonEncode(word),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String? editorialMeaning(Word word) {
    final direct = informalGlosses[word.lemma];
    if (direct != null) return direct;
    if ([
      'LEXORA original editorial',
      'Lingoy original editorial',
      'Lingoy AI definition-aligned editorial',
    ].contains(word.translationSource)) {
      return word.translation;
    }
    for (final pos in ['v', 'n', 'a', 's', 'r']) {
      final value = baseGlosses['${word.lemma}:$pos'];
      if (value != null) return value;
    }
    return null;
  }

  Future<List<Word>> _withCached(List<Word> words) async {
    if (!ready || words.isEmpty) return words;
    final rows = await user.query(
      'remote_words',
      where: 'id IN (${List.filled(words.length, '?').join(',')})',
      whereArgs: words.map((w) => w.id).toList(),
    );
    final cached = {
      for (final row in rows)
        row['id']: Word.from(
          (jsonDecode(row['json'] as String) as Map).cast<String, Object?>(),
        ),
    };
    return words.map((w) {
      final meaning = editorialMeaning(w);
      if (meaning == null) return cached[w.id] ?? w;
      return Word(
        id: w.id,
        lemma: w.lemma,
        translation: meaning,
        level: w.level,
        ipa: w.ipa,
        translationSource: w.translationSource,
        levelSource: w.levelSource,
      );
    }).toList();
  }

  Future<void> bindAccount(String? id) async {
    if (id == accountId) return;
    _syncTimer?.cancel();
    while (syncing) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await user.close();
    accountId = id;
    await _openUser(id == null ? 'lexora-user.db' : 'lingoy-account-$id.db');
    saved = (await user.query(
      'saved',
      columns: ['word_id'],
    )).map((w) => w['word_id'] as int).toSet();
    notifyListeners();
    if (id != null) {
      _syncTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => syncSaved(),
      );
    }
  }

  Future<void> _queueSaved(
    int id,
    bool deleted, {
    DatabaseExecutor? executor,
  }) async {
    if (accountId == null) return;
    await (executor ?? user).insert('sync_queue', {
      'word_id': id,
      'mutation': accountApi.verifier(),
      'deleted': deleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> importGuestWords() async {
    if (accountId == null) return 0;
    final guest = await openDatabase(
      p.join(await getDatabasesPath(), 'lexora-user.db'),
      readOnly: true,
    );
    final rows = await guest.query('saved'),
        remote = await guest.query('remote_words');
    await guest.close();
    var added = 0;
    await user.transaction((tx) async {
      for (final row in rows) {
        final id = row['word_id'] as int;
        if (saved.contains(id)) continue;
        await tx.insert('saved', {
          ...row,
          'folder_id': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await tx.insert('sync_queue', {
          'word_id': id,
          'mutation': accountApi.verifier(),
          'deleted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        added++;
      }
      for (final row in remote) {
        await tx.insert(
          'remote_words',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    saved = (await user.query(
      'saved',
      columns: ['word_id'],
    )).map((r) => r['word_id'] as int).toSet();
    notifyListeners();
    unawaited(syncSaved());
    return added;
  }

  Future<void> syncSaved() async {
    if (accountId == null || syncing || accountApi.user?['id'] != accountId) {
      return;
    }
    syncing = true;
    try {
      while (true) {
        final rows = await user.query('sync_queue', limit: 500);
        if (rows.isEmpty) break;
        final result = await accountApi.request(
          '/saved',
          method: 'POST',
          body: {
            'changes': rows
                .map(
                  (r) => {
                    'id': r['mutation'],
                    'word_id': r['word_id'],
                    'deleted': r['deleted'] == 1,
                  },
                )
                .toList(),
          },
        );
        for (final id in result['acknowledged'] as List) {
          await user.delete('sync_queue', where: 'mutation=?', whereArgs: [id]);
        }
      }
      final result = await accountApi.request('/saved');
      for (final row in result['words'] as List) {
        if (row['deleted'] == 0 && (row['word_id'] as int) >= 1000000000) {
          final data = await accountApi.request(
            '/dictionary/${row['word_id']}',
          );
          await cacheRemoteWord((data['word'] as Map).cast<String, dynamic>());
        }
      }
      await user.transaction((tx) async {
        final pending = (await tx.query('sync_queue'))
            .map((r) => r['word_id'])
            .toSet();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final row in result['words'] as List) {
          final id = row['word_id'] as int;
          if (pending.contains(id)) continue;
          if (row['deleted'] == 1) {
            await tx.delete('saved', where: 'word_id=?', whereArgs: [id]);
          } else {
            await tx.insert('saved', {
              'word_id': id,
              'folder_id': 1,
              'added': now,
              'due': now,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      });
      saved = (await user.query(
        'saved',
        columns: ['word_id'],
      )).map((r) => r['word_id'] as int).toSet();
      syncError = null;
      notifyListeners();
    } catch (_) {
      syncError = 'Sinxronlash kutilmoqda. Internet tiklanganda davom etadi.';
    } finally {
      syncing = false;
    }
  }

  bool get onboarded =>
      (prefs.getBool('onboarded') ?? false) &&
      validName(name) &&
      name != 'Til o‘rganuvchi';
  static String cleanName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
  static bool validName(String value) {
    final v = cleanName(value);
    return v.runes.length <= 32 &&
        v.isNotEmpty &&
        RegExp(
          r"^[\p{L}\p{M}][\p{L}\p{M} '’‘ʻʼ-]*$",
          unicode: true,
        ).hasMatch(v);
  }

  Future<void> configure({
    String? newMotion,
    String? newTheme,
    String? newLevel,
    int? newGoal,
    String? newName,
    bool finish = false,
  }) async {
    if (newMotion != null && ['auto', 'smooth', 'light'].contains(newMotion)) {
      motion = newMotion;
      await prefs.setString('motion', motion);
    }
    if (newTheme != null) {
      theme = newTheme;
      await prefs.setString('theme', theme);
    }
    if (newLevel != null) {
      level = newLevel;
      await prefs.setString('level', level);
    }
    if (newGoal != null) {
      goal = newGoal;
      await prefs.setInt('goal', goal);
    }
    if (newName != null) {
      if (!validName(newName)) {
        throw ArgumentError('Ism 1–32 harfdan iborat bo‘lsin.');
      }
      name = cleanName(newName);
      await prefs.setString('name', name);
    }
    if (finish) await prefs.setBool('onboarded', true);
    notifyListeners();
  }

  Future<List<Word>> search(
    String query, {
    String lv = '',
    bool reverse = false,
    int offset = 0,
    int limit = 40,
    bool bilingual = false,
  }) async {
    final normalized = normalize(query);
    final q = reverse ? normalized : spellingAliases[normalized] ?? normalized;
    if (q.length > 160) return [];
    final clauses = <String>[];
    final args = <Object?>[];
    if (lv.isNotEmpty) {
      clauses.add('e.level=?');
      args.add(lv);
    }
    if (bilingual) clauses.add("e.translation<>''");
    if (q.isEmpty) {
      return (await dict.rawQuery(
        "SELECT e.* FROM entries e ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'} ORDER BY CASE WHEN e.translation_source='LEXORA original editorial' THEN 0 WHEN e.translation<>'' AND e.level<>'' THEN 1 ELSE 2 END, e.id LIMIT ? OFFSET ?",
        [...args, limit, offset],
      )).map(Word.from).toList();
    }
    final tokens = RegExp(r"[a-z0-9]+(?:'[a-z]+)?")
        .allMatches(q)
        .map((m) => m[0]!)
        .toList();
    if (tokens.isEmpty) return [];
    final fts = tokens.map((s) => '"${s.replaceAll('"', '')}"*').join(' ');
    final bases = reverse
        ? <String>[]
        : (await baseForms(q))
              .map((f) => normalize(f.word.lemma))
              .toSet()
              .toList();
    final rootClause = bases.isEmpty
        ? ''
        : ' OR e.normalized IN (${List.filled(bases.length, '?').join(',')})';
    if (reverse) {
      clauses.add(
        '(e.id IN (SELECT docid FROM search WHERE translation MATCH ?))',
      );
      args.add(fts);
    } else {
      clauses.add(
        '(e.id IN (SELECT docid FROM search WHERE lemma MATCH ?) OR e.normalized=?$rootClause)',
      );
      args.addAll([fts, q, ...bases]);
    }
    var translated = 'lower(e.translation)';
    for (final code in [8216, 8217, 699, 700, 96, 697]) {
      translated = 'replace($translated,char($code),char(39))';
    }
    final rootOrder = bases.isEmpty
        ? ''
        : ' WHEN e.normalized IN (${List.filled(bases.length, '?').join(',')}) THEN 1';
    final order = reverse
        ? 'CASE WHEN $translated=? OR $translated LIKE ? THEN 0 WHEN $translated LIKE ? OR $translated LIKE ? THEN 1 WHEN $translated LIKE ? THEN 2 ELSE 3 END'
        : 'CASE WHEN e.normalized=? THEN 0$rootOrder WHEN e.normalized LIKE ? THEN 2 ELSE 3 END';
    var result = await dict.rawQuery(
      "SELECT e.* FROM entries e WHERE ${clauses.join(' AND ')} ORDER BY $order,CASE WHEN e.translation_source IN ('LEXORA original editorial','Lingoy original editorial') THEN 0 WHEN e.level<>'' THEN 1 ELSE 2 END,CASE WHEN e.translation='' THEN 1 ELSE 0 END,length(e.lemma),e.id LIMIT ? OFFSET ?",
      [
        ...args,
        q,
        if (reverse) ...['$q;%', '$q %', '$q,%'],
        ...bases,
        '$q%',
        limit,
        offset,
      ],
    );
    if (result.isEmpty && offset == 0 && q.length >= 3) {
      final more = <String>[];
      final a = <Object?>[];
      if (lv.isNotEmpty) {
        more.add('e.level=?');
        a.add(lv);
      }
      if (bilingual) more.add("e.translation<>''");
      more.add('${reverse ? translated : 'e.normalized'} LIKE ?');
      a.add('%${q.replaceAll('%', '').replaceAll('_', '')}%');
      result = await dict.rawQuery(
        "SELECT e.* FROM entries e WHERE ${more.join(' AND ')} ORDER BY length(e.lemma),e.id LIMIT ?",
        [...a, limit],
      );
    }
    return _withCached(result.map(Word.from).toList());
  }

  Future<List<Word>> spellingSuggestions(String query) async {
    final q = normalize(query);
    if (!RegExp(r'^[a-z]{3,30}$').hasMatch(q)) {
      return [];
    }
    final rows = await dict.rawQuery(
      "SELECT * FROM entries WHERE length(normalized) BETWEEN ? AND ? AND (normalized LIKE ? OR normalized LIKE ?) ORDER BY CASE WHEN level<>'' THEN 0 ELSE 1 END,abs(length(normalized)-?),id LIMIT 1800",
      [q.length - 2, q.length + 2, '${q[0]}%', '${q[1]}%', q.length],
    );
    final candidates =
        rows
            .map(
              (r) => (Word.from(r), editDistance(q, r['normalized'] as String)),
            )
            .where((x) => x.$2 > 0 && x.$2 <= 2)
            .toList()
          ..sort(
            (a, b) => a.$2.compareTo(b.$2) == 0
                ? a.$1.lemma.compareTo(b.$1.lemma)
                : a.$2.compareTo(b.$2),
          );
    return _withCached(candidates.take(4).map((x) => x.$1).toList());
  }

  Future<Word?> word(int id) async {
    final r = await dict.query('entries', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) {
      if (!ready) return null;
      final cached = await user.query(
        'remote_words',
        where: 'id=?',
        whereArgs: [id],
      );
      return cached.isEmpty
          ? null
          : Word.from(
              (jsonDecode(cached.first['json'] as String) as Map)
                  .cast<String, Object?>(),
            );
    }
    return (await _withCached([Word.from(r.first)])).first;
  }

  Future<Word?> lookup(String lemma) async {
    final r = await dict.query(
      'entries',
      where: 'normalized=?',
      whereArgs: [spellingAliases[normalize(lemma)] ?? normalize(lemma)],
      limit: 1,
    );
    return r.isEmpty ? null : (await _withCached([Word.from(r.first)])).first;
  }

  Future<List<Map<String, Object?>>> senses(int id) async {
    final rows = await dict.rawQuery(
      'SELECT s.*,e.normalized AS entry_key FROM senses s JOIN entry_senses es ON es.sense_id=s.id JOIN entries e ON e.id=es.entry_id WHERE es.entry_id=? ORDER BY es.ordinal',
      [id],
    );
    final groups = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final extra = senseExamples[row['id']] as Map<String, dynamic>?;
      groups.putIfAbsent(row['pos'] as String, () => []).add(<String, Object?>{
        ...row,
        'meaning_uz': extra?['meaning_uz'] ?? '',
        'bilingual_examples': jsonEncode(extra?['examples'] ?? []),
      });
    }
    for (final group in groups.values) {
      final first = group.first;
      final preferred = sensePriority['${first['entry_key']}:${first['pos']}'];
      final index = group.indexWhere((s) => s['id'] == preferred);
      if (index > 0) group.insert(0, group.removeAt(index));
    }
    final orderedGroups = groups.values.toList();
    // Prefer an editorially selected primary meaning over an arbitrary POS group.
    bool reviewed(List<Map<String, Object?>> g) =>
        sensePriority['${g.first['entry_key']}:${g.first['pos']}'] != null;
    return [
      ...orderedGroups.where(reviewed),
      ...orderedGroups.where((g) => !reviewed(g)),
    ].expand((s) => s).toList();
  }

  Future<List<String>> antonyms(List<Map<String, Object?>> ss) async {
    final ids = ss
        .expand(
          (s) => (jsonDecode(s['antonyms'] as String) as List).cast<String>(),
        )
        .toSet()
        .toList();
    if (ids.isEmpty) return [];
    final r = await dict.rawQuery(
      'SELECT words FROM senses WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      ids,
    );
    return r
        .expand(
          (m) => (jsonDecode(m['words'] as String) as List).cast<String>(),
        )
        .toSet()
        .toList();
  }

  Future<List<BaseForm>> baseForms(
    String input, {
    bool includeUnchanged = false,
  }) {
    final q = normalizeFormInput(input);
    if (!RegExp(r"^[a-z]+(?:'[a-z]+)?'?(?: [a-z]+){0,4}$").hasMatch(q)) {
      return Future.value([]);
    }
    if (_formsCache.length >= 256) _formsCache.remove(_formsCache.keys.first);
    final key = '${includeUnchanged ? 'all' : 'changed'}:$q';
    return _formsCache.putIfAbsent(
      key,
      () => _resolveForms(q, includeUnchanged: includeUnchanged),
    );
  }

  Future<List<BaseForm>> _resolveForms(
    String q, {
    required bool includeUnchanged,
  }) async {
    final parts = q.split(' '), head = q.split(' ').first;
    final rules = <FormRule>[];
    final listed = (morphExceptions[q] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (parts.length == 1) {
      for (final e in listed) {
        rules.add(
          FormRule(
            e['lemma'] as String,
            e['pos'] as String,
            'Lug‘atda qayd etilgan o‘zgargan shakl',
          ),
        );
      }
      final exceptionPos = listed.map((e) => e['pos']).toSet();
      rules.addAll(regularForms(q).where((r) => !exceptionPos.contains(r.pos)));
    } else {
      // Inflected phrasal verbs, such as looked after -> look after.
      final heads = <FormRule>[
        ...regularForms(head),
        for (final e
            in (morphExceptions[head] as List? ?? [])
                .cast<Map<String, dynamic>>())
          FormRule(
            e['lemma'] as String,
            e['pos'] as String,
            'Ibora fe’lining asosiy shakli',
          ),
      ];
      for (final h in heads.where((h) => h.pos == 'v')) {
        rules.add(
          FormRule('${h.lemma} ${parts.skip(1).join(' ')}', 'v', h.reason),
        );
      }
      for (final e in listed) {
        rules.add(
          FormRule(
            e['lemma'] as String,
            e['pos'] as String,
            'Lug‘atdagi ibora shakli',
          ),
        );
      }
    }
    rules.removeWhere((r) => r.lemma == q);
    if (includeUnchanged) {
      rules.add(FormRule(q, 'v', 'Fe’lning asosiy shakli (infinitiv)'));
    }
    final names = rules.map((r) => r.lemma).toSet().toList();
    if (names.isEmpty) return [];
    final rows = await dict.rawQuery(
      'SELECT e.*,s.id AS form_sense,s.pos AS form_pos,s.words AS source_words,s.definition AS form_definition FROM entries e JOIN entry_senses es ON es.entry_id=e.id JOIN senses s ON s.id=es.sense_id WHERE e.normalized IN (${List.filled(names.length, '?').join(',')}) ORDER BY e.id,es.ordinal',
      names,
    );
    final out = <BaseForm>[];
    for (final row in rows) {
      final pos = row['form_pos'] as String,
          lemma = row['normalized'] as String;
      final rawWords = (jsonDecode(row['source_words'] as String) as List)
          .cast<String>();
      final typedException = listed.any(
        (e) => normalize(e['lemma'] as String) == lemma && e['pos'] == pos,
      );
      // Regular suffix rules must not pluralize case-sensitive abbreviations:
      // was is not WA+s, and has is not HA+s.
      if (!typedException && !rawWords.contains(lemma)) continue;
      final existing = out.indexWhere(
        (f) => f.word.id == row['id'] && f.pos == pos,
      );
      if (existing >= 0 && row['form_sense'] != sensePriority['$lemma:$pos']) {
        continue;
      }
      final reasons = rules
          .where(
            (r) =>
                r.lemma == lemma &&
                (r.pos == pos || r.pos == 'a' && pos == 's'),
          )
          .map((r) => r.reason)
          .toSet()
          .toList();
      if (reasons.isNotEmpty) {
        final match = BaseForm(
          input: q,
          pos: pos == 's' ? 'a' : pos,
          word: Word.from(row),
          reasons: reasons,
          meaning: baseGlosses['$lemma:$pos'] ?? '',
          definition: row['form_definition'] as String,
        );
        if (existing < 0) {
          out.add(match);
        } else {
          out[existing] = match;
        }
      }
    }
    out.sort((a, b) {
      final v = (a.pos == 'v' ? 0 : 1).compareTo(b.pos == 'v' ? 0 : 1);
      return v != 0 ? v : a.word.lemma.compareTo(b.word.lemma);
    });
    return out;
  }

  Future<List<WordAnalysis>> analyzeText(String text) async {
    final out = <WordAnalysis>[];
    for (final token in englishTokens(text).take(120)) {
      out.add(
        WordAnalysis(
          token,
          await lookup(token),
          await baseForms(token, includeUnchanged: true),
        ),
      );
    }
    return out;
  }

  Future<void> toggleSave(Word w, {int folder = 1}) async {
    final deleting = saved.contains(w.id);
    await user.transaction((tx) async {
      if (deleting) {
        await tx.delete('saved', where: 'word_id=?', whereArgs: [w.id]);
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        await tx.insert('saved', {
          'word_id': w.id,
          'folder_id': folder,
          'added': now,
          'due': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await _queueSaved(w.id, deleting, executor: tx);
    });
    if (deleting) {
      saved.remove(w.id);
    } else {
      saved.add(w.id);
    }
    unawaited(syncSaved());
    notifyListeners();
  }

  Future<void> ensureSaved(int id, {int folder = 1}) async {
    if (saved.contains(id)) return;
    final w = await word(id);
    if (w != null) await toggleSave(w, folder: folder);
  }

  /// Resolve bounded chunks, then save once without replacing existing SRS rows.
  Future<VocabularyImportResult> importVocabulary(
    List<String> lemmas, {
    int folder = 1,
  }) async {
    final normalized = lemmas
        .map(normalize)
        .where((v) => v.isNotEmpty)
        .toList();
    final unique = normalized.toSet().toList();
    final found = <String, int>{};
    for (var start = 0; start < unique.length; start += 250) {
      final chunk = unique.skip(start).take(250).toList();
      final rows = await dict.rawQuery(
        'SELECT id,normalized FROM entries WHERE normalized IN (${List.filled(chunk.length, '?').join(',')})',
        chunk,
      );
      for (final row in rows) {
        found[row['normalized'] as String] = row['id'] as int;
      }
    }
    var added = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    await user.transaction((tx) async {
      final existingFolder = await tx.query(
        'folders',
        columns: ['id'],
        where: 'id=?',
        whereArgs: [folder],
      );
      final destination = existingFolder.isEmpty ? 1 : folder;
      final before = Sqflite.firstIntValue(
        await tx.rawQuery('SELECT count(*) FROM saved'),
      )!;
      final ids = found.values.toList();
      for (var start = 0; start < ids.length; start += 250) {
        final batch = tx.batch();
        for (final id in ids.skip(start).take(250)) {
          batch.rawInsert(
            'INSERT OR IGNORE INTO saved(word_id,folder_id,added,due) VALUES(?,?,?,?)',
            [id, destination, now, now],
          );
        }
        await batch.commit(noResult: true);
      }
      if (accountId != null) {
        for (final id in found.values.where((id) => !saved.contains(id))) {
          await _queueSaved(id, false, executor: tx);
        }
      }
      added =
          Sqflite.firstIntValue(
            await tx.rawQuery('SELECT count(*) FROM saved'),
          )! -
          before;
    });
    saved = (await user.query(
      'saved',
      columns: ['word_id'],
    )).map((r) => r['word_id'] as int).toSet();
    notifyListeners();
    unawaited(syncSaved());
    return VocabularyImportResult(
      added,
      unique.length - found.length,
      normalized.length - unique.length + found.length - added,
    );
  }

  Future<List<Map<String, Object?>>> folders() => user.rawQuery(
    'SELECT f.*,count(s.word_id) AS count FROM folders f LEFT JOIN saved s ON f.id=s.folder_id GROUP BY f.id ORDER BY f.id',
  );
  Future<void> folderAdd(String name) async {
    final n = name.trim();
    if (n.isEmpty || n.length > 60) {
      throw ArgumentError('Papka nomi 1–60 belgi bo‘lsin.');
    }
    await user.insert('folders', {'name': n});
    notifyListeners();
  }

  Future<void> folderRename(int id, String name) async {
    final n = name.trim();
    if (n.isEmpty || n.length > 60) {
      throw ArgumentError('Papka nomi 1–60 belgi bo‘lsin.');
    }
    await user.update('folders', {'name': n}, where: 'id=?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> folderDelete(int id) async {
    if (id == 1) return;
    await user.transaction((tx) async {
      await tx.update(
        'saved',
        {'folder_id': 1},
        where: 'folder_id=?',
        whereArgs: [id],
      );
      await tx.delete('folders', where: 'id=?', whereArgs: [id]);
    });
    notifyListeners();
  }

  Future<void> moveWord(int id, int folder) async {
    await user.update(
      'saved',
      {'folder_id': folder},
      where: 'word_id=?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  Future<List<Word>> savedWords({int? folder, bool due = false}) async {
    final rows = await user.query(
      'saved',
      where:
          [
            if (folder != null) 'folder_id=?',
            if (due) 'due<=?',
          ].join(' AND ').isEmpty
          ? null
          : [
              if (folder != null) 'folder_id=?',
              if (due) 'due<=?',
            ].join(' AND '),
      whereArgs: [?folder, if (due) DateTime.now().millisecondsSinceEpoch],
      orderBy: 'due,added',
    );
    final byId = <int, Word>{};
    for (var start = 0; start < rows.length; start += 250) {
      final ids = rows.skip(start).take(250).map((r) => r['word_id']).toList();
      final words = await dict.query(
        'entries',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
      for (final row in words) {
        final w = Word.from(row);
        byId[w.id] = w;
      }
    }
    for (final row in await user.query('remote_words')) {
      final w = Word.from(
        (jsonDecode(row['json'] as String) as Map).cast<String, Object?>(),
      );
      // Fresh bundled meanings take precedence over older per-account API cache.
      byId.putIfAbsent(w.id, () => w);
    }
    return _withCached(
      rows.map((r) => byId[r['word_id']]).whereType<Word>().toList(),
    );
  }

  Future<Map<int, String>> firstDefinitions(Iterable<int> ids) async {
    final list = ids.toSet().toList(), definitions = <int, String>{};
    for (var start = 0; start < list.length; start += 250) {
      final chunk = list.skip(start).take(250).toList();
      final rows = await dict.rawQuery(
        'SELECT es.entry_id,s.definition FROM entry_senses es JOIN senses s ON s.id=es.sense_id WHERE es.entry_id IN (${List.filled(chunk.length, '?').join(',')}) ORDER BY es.entry_id,es.ordinal',
        chunk,
      );
      for (final row in rows) {
        definitions.putIfAbsent(
          row['entry_id'] as int,
          () => row['definition'] as String,
        );
      }
    }
    return definitions;
  }

  Future<List<Word>> practiceWords({String? lv, int limit = 20}) async {
    final words = await savedWords();
    final meanings = <String>{};
    final usable =
        words
            .where(
              (w) => w.translation.isNotEmpty && meanings.add(w.translation),
            )
            .toList()
          ..shuffle();
    return usable.take(limit).toList();
  }

  Future<void> review(Word w, int grade, {String kind = 'review'}) async {
    await ensureSaved(w.id);
    await user.transaction((tx) async {
      final row = (await tx.query(
        'saved',
        where: 'word_id=?',
        whereArgs: [w.id],
      )).first;
      final now = DateTime.now();
      final s = scheduleReview(
        grade: grade,
        repetitions: row['reps'] as int,
        interval: (row['interval'] as num).toDouble(),
        ease: (row['ease'] as num).toDouble(),
        now: now,
      );
      await tx.update(
        'saved',
        {
          'reps': s.repetitions,
          'interval': s.interval,
          'ease': s.ease,
          'due': s.due.millisecondsSinceEpoch,
        },
        where: 'word_id=?',
        whereArgs: [w.id],
      );
      await tx.insert('events', {
        'word_id': w.id,
        'kind': kind,
        'correct': grade > 0 ? 1 : 0,
        'grade': grade,
        'created': now.millisecondsSinceEpoch,
        'day': dayKey(now),
      });
    });
    notifyListeners();
  }

  /// Early successful play does not push an already scheduled review away.
  Future<void> gameReview(Word w, bool perfect) async {
    final rows = await user.query(
      'saved',
      columns: ['due'],
      where: 'word_id=?',
      whereArgs: [w.id],
    );
    if (!perfect ||
        rows.isEmpty ||
        (rows.first['due'] as int) <= DateTime.now().millisecondsSinceEpoch) {
      await review(w, perfect ? 2 : 0, kind: 'memory_game');
    } else {
      await answer(w, true, kind: 'memory_game');
    }
  }

  Future<void> answer(Word w, bool correct, {String kind = 'quiz'}) async {
    await user.insert('events', {
      'word_id': w.id,
      'kind': kind,
      'correct': correct ? 1 : 0,
      'created': DateTime.now().millisecondsSinceEpoch,
      'day': dayKey(),
    });
    notifyListeners();
  }

  Future<Map<String, int>> stats() {
    _checkDay();
    return _statsCache ??= _stats();
  }

  Future<Map<String, int>> _stats() async {
    final rows = await user.rawQuery(
      'SELECT count(*) total,coalesce(sum(correct),0) correct,coalesce(sum(CASE WHEN day=? THEN 1 ELSE 0 END),0) today FROM events',
      [dayKey()],
    );
    final r = rows.first;
    final due =
        Sqflite.firstIntValue(
          await user.rawQuery('SELECT count(*) FROM saved WHERE due<=?', [
            DateTime.now().millisecondsSinceEpoch,
          ]),
        ) ??
        0;
    final mastered =
        Sqflite.firstIntValue(
          await user.rawQuery(
            'SELECT count(*) FROM saved WHERE interval>=21 AND reps>=3',
          ),
        ) ??
        0;
    final dates = (await user.rawQuery('SELECT DISTINCT day FROM events'))
        .map((e) => e['day'] as String)
        .toSet();
    var d = DateTime.now();
    if (!dates.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    int streak = 0;
    while (dates.contains(dayKey(d))) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return {
      'total': r['total'] as int,
      'correct': (r['correct'] as num).toInt(),
      'today': (r['today'] as num).toInt(),
      'due': due,
      'streak': streak,
      'saved': saved.length,
      'mastered': mastered,
    };
  }

  Future<List<int>> week() {
    _checkDay();
    return _weekCache ??= _week();
  }

  Future<List<int>> _week() async {
    final days = <int>[];
    for (int i = 6; i >= 0; i--) {
      final key = dayKey(DateTime.now().subtract(Duration(days: i)));
      days.add(
        Sqflite.firstIntValue(
              await user.rawQuery('SELECT count(*) FROM events WHERE day=?', [
                key,
              ]),
            ) ??
            0,
      );
    }
    return days;
  }

  Future<void> rememberViewed(Word value) async {
    final db = user;
    await db.insert('viewed_words', {
      'word_id': value.id,
      'viewed_at': DateTime.now().microsecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.execute(
      'DELETE FROM viewed_words WHERE word_id NOT IN (SELECT word_id FROM viewed_words ORDER BY viewed_at DESC LIMIT 30)',
    );
    if (identical(user, db)) notifyListeners();
  }

  Future<List<Word>> recentViewed() async {
    final db = user, owner = accountId;
    final rows = await db.query(
      'viewed_words',
      orderBy: 'viewed_at DESC',
      limit: 20,
    );
    final result = <Word>[];
    for (final row in rows) {
      if (!identical(user, db) || accountId != owner) return [];
      final value = await word(row['word_id'] as int);
      if (value != null) result.add(value);
    }
    return identical(user, db) && accountId == owner ? result : [];
  }

  Future<void> historyAdd(String q) async {
    if (q.trim().isEmpty) return;
    await user.insert('history', {
      'query': q.trim(),
      'created': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await user.execute(
      'DELETE FROM history WHERE query NOT IN (SELECT query FROM history ORDER BY created DESC LIMIT 25)',
    );
  }

  Future<List<String>> history() async => (await user.query(
    'history',
    orderBy: 'created DESC',
    limit: 10,
  )).map((e) => e['query'] as String).toList();
  Future<Word?> daily() async {
    final list = await dict.rawQuery(
      "SELECT * FROM entries WHERE level IN ('A2','B1','B2') AND translation_source='LEXORA original editorial' ORDER BY id",
    );
    if (list.isEmpty) return null;
    final n = DateTime.now().difference(DateTime(2026)).inDays;
    return Word.from(list[n % list.length]);
  }

  Future<void> lessonDone(String id) async {
    await user.insert('lessons', {
      'id': id,
      'completed': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<Set<String>> doneLessons() async =>
      (await user.query('lessons')).map((e) => e['id'] as String).toSet();
  Future<void> clearUserData() async {
    for (final id in saved) {
      await _queueSaved(id, true);
    }
    await user.transaction((tx) async {
      for (final t in [
        'events',
        'saved',
        'lessons',
        'history',
        'viewed_words',
      ]) {
        await tx.delete(t);
      }
      await tx.delete('folders', where: 'id<>1');
    });
    saved.clear();
    unawaited(syncSaved());
    await prefs.remove('essential-bookmarks');
    notifyListeners();
  }
}

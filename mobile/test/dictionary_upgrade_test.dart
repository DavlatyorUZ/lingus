import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/core/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Dictionary revision replaces old content while saved words and review history survive', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('lingoy-upgrade-');
    await databaseFactory.setDatabasesPath(dir.path);
    SharedPreferences.setMockInitialValues({'name': 'Ali'});
    final old = Store();
    await old.init();
    expect(old.ready, true, reason: old.error);
    final word = (await old.lookup('receive'))!;
    await old.ensureSaved(word.id);
    await old.answer(word, true, kind: 'translate');
    final saved = await old.user.query('saved');
    final events = await old.user.query('events');
    await old.cacheRemoteWord({
      'id': word.id,
      'lemma': word.lemma,
      'translation': 'outdated remote translation',
      'translation_source': 'Old remote cache',
      'level': '',
      'ipa': '',
    });
    await old.prefs.setString('dictionary_sha256', 'previous-content-revision');
    await old.dict.close();
    await old.user.close();
    final stale = await openDatabase('${dir.path}/lexora-content-v1.db');
    await stale.update(
      'entries',
      {'translation': 'stale translation'},
      where: 'id=?',
      whereArgs: [word.id],
    );
    await stale.close();
    final upgraded = Store();
    await upgraded.init();
    expect(upgraded.ready, true, reason: upgraded.error);
    expect(
      (await upgraded.lookup('receive'))!.translation,
      'olmoq; qabul qilmoq',
    );
    expect(
      (await upgraded.dict.query(
        'entries',
        where: 'id=?',
        whereArgs: [word.id],
      )).single['translation'],
      isNot('stale translation'),
    );
    expect(await upgraded.user.query('saved'), saved);
    expect(await upgraded.user.query('events'), events);
    expect(upgraded.saved, contains(word.id));
    expect(
      (await upgraded.savedWords()).single.translation,
      'olmoq; qabul qilmoq',
      reason:
          'An old account cache must not overwrite corrected bundled meanings',
    );
    expect(
      await upgraded.user.query('remote_words'),
      isNotEmpty,
      reason: 'Remote-only vocabulary remains available',
    );
    expect(
      upgraded.prefs.getString('dictionary_sha256'),
      isNot('previous-content-revision'),
    );
    await upgraded.dict.close();
    await upgraded.user.close();
    await dir.delete(recursive: true);
  });
}

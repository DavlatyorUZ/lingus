import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/core/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Guest words stay isolated; account import and CSV edits persist in sync queue', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('lingoy-account-');
    await databaseFactory.setDatabasesPath(dir.path);
    SharedPreferences.setMockInitialValues({'name': 'Ali'});
    final s = Store();
    await s.init();
    expect(s.ready, true, reason: s.error);
    final apple = (await s.lookup('apple'))!;
    expect(await s.recentViewed(), isEmpty);
    await s.search('abandoned');
    expect(await s.recentViewed(), isEmpty);
    await s.rememberViewed(apple);
    await s.rememberViewed(apple);
    expect((await s.recentViewed()).map((w) => w.id), [apple.id]);
    expect(s.saved, isEmpty);
    await s.ensureSaved(apple.id);
    await s.bindAccount('test-account-a');
    expect(await s.recentViewed(), isEmpty);
    expect(s.saved, isEmpty);
    expect(await s.importGuestWords(), 1);
    expect(s.saved, contains(apple.id));
    expect((await s.user.query('sync_queue')).single['word_id'], apple.id);
    await s.importVocabulary(['teacher']);
    expect((await s.user.query('sync_queue')).length, 2);
    await s.toggleSave(apple);
    expect(
      (await s.user.query(
        'sync_queue',
        where: 'word_id=?',
        whereArgs: [apple.id],
      )).single['deleted'],
      1,
    );
    final teacher = (await s.lookup('teacher'))!;
    final before = s.saved.toSet();
    await s.user.execute(
      "CREATE TRIGGER fail_sync BEFORE INSERT ON sync_queue BEGIN SELECT RAISE(ABORT,'simulated storage failure'); END",
    );
    await expectLater(s.toggleSave(teacher), throwsA(anything));
    expect(s.saved, before);
    expect(
      await s.user.query('saved', where: 'word_id=?', whereArgs: [teacher.id]),
      hasLength(1),
    );
    await s.user.execute('DROP TRIGGER fail_sync');
    await s.bindAccount('test-account-b');
    expect(s.saved, isEmpty);
    expect(await s.user.query('sync_queue'), isEmpty);
    await s.bindAccount('test-account-a');
    expect(s.saved, isNot(contains(apple.id)));
    expect((await s.user.query('sync_queue')).length, 2);
    await s.bindAccount(null);
    expect(s.saved, {apple.id});
    expect((await s.recentViewed()).single.id, apple.id);
    await s.user.close();
    await s.dict.close();
    await dir.delete(recursive: true);
  }, skip: Platform.isWindows);
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lingoy/core/dictionary_storage.dart';
import 'package:lingoy/core/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test('Corrupt content repairs itself without deleting saved vocabulary or history', () async {
    final dir = await Directory.systemTemp.createTemp('lingoy-recovery-');
    await databaseFactory.setDatabasesPath(dir.path);
    SharedPreferences.setMockInitialValues({'name': 'Ali'});
    final before = Store();
    await before.init();
    expect(before.ready, isTrue, reason: before.error);
    final word = (await before.lookup('start'))!;
    await before.ensureSaved(word.id);
    await before.user.insert('history', {
      'query': 'my history',
      'created': 1234,
    });
    await before.user.close();
    final contentPath = before.dict.path;
    await before.dict.close();
    await File(contentPath).writeAsString('interrupted or corrupt dictionary');
    final after = Store();
    final first = after.init();
    expect(identical(first, after.init()), isTrue);
    await first;
    expect(after.ready, isTrue, reason: after.error);
    expect(after.recovering, isTrue);
    expect(after.saved, contains(word.id));
    expect((await after.user.query('history')).single['query'], 'my history');
    expect((await after.lookup('start'))!.id, word.id);
    await expectLater(
      after.dict.execute('DELETE FROM entries'),
      throwsA(anything),
    );
    await after.user.close();
    await after.dict.close();
    await dir.delete(recursive: true);
  });
  test(
    'A structurally valid database with a missing search entry is repaired',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'lingoy-search-repair-',
      );
      await databaseFactory.setDatabasesPath(dir.path);
      SharedPreferences.setMockInitialValues({'name': 'Ali'});
      final before = Store();
      await before.init();
      expect(before.ready, isTrue, reason: before.error);
      final id = (await before.lookup('start'))!.id;
      final path = before.dict.path;
      await before.dict.close();
      await before.user.close();
      final broken = await openDatabase(path, singleInstance: false);
      await broken.rawDelete('DELETE FROM search WHERE docid=?', [id]);
      expect(
        (await broken.rawQuery('PRAGMA quick_check')).single.values.single,
        'ok',
      );
      await broken.close();
      final after = Store();
      await after.init();
      expect(after.ready, isTrue, reason: after.error);
      expect(after.recovering, isTrue);
      expect((await after.search('start')).any((w) => w.id == id), isTrue);
      await after.dict.close();
      await after.user.close();
      await dir.delete(recursive: true);
    },
  );
  test(
    'Native installer path is used; failed recovery is bounded to one retry',
    () async {
      final dir = await Directory.systemTemp.createTemp('lingoy-install-path-');
      final revision =
          (jsonDecode(
                await rootBundle.loadString('assets/dictionary_revision.json'),
              ) as Map)['sha256']
              as String;
      final actual = File('${dir.path}/native-content.db');
      final payload = await rootBundle.load('assets/dictionary.db');
      await actual.writeAsBytes(
        payload.buffer.asUint8List(
          payload.offsetInBytes,
          payload.lengthInBytes,
        ),
      );
      final db = await openDictionaryWithRecovery(
        file: File('${dir.path}/wrong-path.db'),
        revision: revision,
        needsInstall: true,
        onRecovery: () => fail('Unexpected recovery'),
        install: (_, _) async => actual.path,
      );
      expect(db.path, actual.path);
      await db.close();
      var attempts = 0, installs = 0, recoveries = 0;
      await expectLater(
        openDictionaryWithRecovery(
          file: actual,
          revision: revision,
          needsInstall: false,
          onRecovery: () => recoveries++,
          install: (_, _) async {
            installs++;
            return actual.path;
          },
          check: (_) async {
            attempts++;
            throw StateError('still corrupt');
          },
        ),
        throwsStateError,
      );
      expect((attempts, installs, recoveries), (2, 1, 1));
      await dir.delete(recursive: true);
    },
  );
}

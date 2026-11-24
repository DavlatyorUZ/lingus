import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// Replace only bundled content. Saved vocabulary lives in a separate database.
Future<String> installDictionary(File target, String expectedHash) async {
  if (Platform.isAndroid) {
    final actualPath = await const MethodChannel('uz.lingoy/performance')
        .invokeMethod<String>('installDictionary', {
          'force': true,
          'sha256': expectedHash,
        });
    if (actualPath == null || actualPath.isEmpty) {
      throw StateError('Dictionary installation returned no path');
    }
    return actualPath;
  }
  final data = await rootBundle.load('assets/dictionary.db');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  if (sha256.convert(bytes).toString() != expectedHash) {
    throw StateError('Dictionary asset checksum');
  }
  final temporary = File('${target.path}.tmp');
  try {
    await target.parent.create(recursive: true);
    await temporary.writeAsBytes(bytes, flush: true);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final sidecar = File('${target.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
    await temporary.rename(target.path);
    return target.path;
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

/// Some Android SQLite versions run virtual-table integrity hooks differently
/// on read-only handles. Check a private writable handle, then prohibit writes.
Future<Database> checkDictionary(String path) async {
  final db = await openDatabase(path, singleInstance: false);
  try {
    final rows = await db.rawQuery('PRAGMA quick_check');
    if (rows.length != 1 || rows.first.values.single != 'ok') {
      throw StateError('Dictionary check: ${rows.take(3).toList()}');
    }
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM entries'),
    );
    if (count == null || count < 120000) {
      throw StateError('Dictionary entries missing');
    }
    // Verify the actual lookup path too, not only the SQLite file structure.
    final probe = await db.rawQuery(
      'SELECT id FROM entries WHERE normalized=? LIMIT 1',
      ['start'],
    );
    if (probe.isEmpty) throw StateError('Dictionary lookup failed');
    final searchProbe = await db.rawQuery(
      'SELECT e.id FROM search JOIN entries e ON e.id=search.docid '
      'WHERE search.lemma MATCH ? AND e.normalized=? LIMIT 1',
      ['start', 'start'],
    );
    if (searchProbe.isEmpty) {
      throw StateError('Dictionary search index missing');
    }
    await db.execute('PRAGMA query_only=ON');
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}

Future<Database> openDictionaryWithRecovery({
  required File file,
  required String revision,
  required bool needsInstall,
  required void Function() onRecovery,
  Future<String> Function(File, String) install = installDictionary,
  Future<Database> Function(String) check = checkDictionary,
}) async {
  var path = file.path;
  if (needsInstall || !await file.exists()) {
    path = await install(file, revision);
  }
  try {
    return await check(path);
  } catch (_) {
    onRecovery();
    // One bounded retry. Never erase account databases or preferences.
    path = await install(File(path), revision);
    return await check(path);
  }
}

import 'package:csv/csv.dart';

import 'models.dart';

class VocabularyImport {
  final List<String> lemmas;
  final bool truncated;
  const VocabularyImport(this.lemmas, this.truncated);
}

String csvSafe(String value) =>
    RegExp(r'^[=+@\-\t\r\n]|^\s+[=+@\-]').hasMatch(value) ? "'$value" : value;
String exportVocabulary(List<Word> words) =>
    '\uFEFF${const ListToCsvConverter().convert([
      ['lemma', 'translation', 'level'],
      for (final word in words) [csvSafe(word.lemma), csvSafe(word.translation), word.level],
    ])}';

VocabularyImport parseVocabulary(String text) {
  final input = text
      .replaceFirst('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final rows = const CsvToListConverter(shouldParseNumbers: false)
      .convert(input, eol: '\n');
  if (rows.isEmpty) throw const FormatException('CSV fayli bo‘sh.');
  final column = rows.first.indexWhere(
    (v) => v.toString().trim().toLowerCase() == 'lemma',
  );
  if (column < 0) {
    throw const FormatException(
      'CSV birinchi satrida lemma ustuni bo‘lishi kerak.',
    );
  }
  final lemmas = <String>[];
  for (final row in rows.skip(1).take(10000)) {
    if (row.length <= column) continue;
    var value = row[column].toString().trim();
    // Only undo our spreadsheet formula escape, not an English apostrophe.
    if (value.startsWith("'") &&
        value.length > 1 &&
        RegExp(r'^[=+@\-\t\r\n]|^\s+[=+@\-]').hasMatch(value.substring(1))) {
      value = value.substring(1);
    }
    if (value.isNotEmpty) lemmas.add(value);
  }
  return VocabularyImport(lemmas, rows.length > 10001);
}

class VocabularyImportResult {
  final int added, missing, duplicates;
  const VocabularyImportResult(this.added, this.missing, this.duplicates);
}

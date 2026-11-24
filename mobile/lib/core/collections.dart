import 'dart:convert';

import 'package:flutter/services.dart';

class StudyEntry {
  final String id, kind, group, word, meaning, example, translation;
  final String searchText;
  StudyEntry(
    this.id,
    this.kind,
    this.group,
    this.word,
    this.meaning,
    this.example,
    this.translation,
  ) : searchText = normalizeStudyText('$word $meaning $example $translation');
  factory StudyEntry.fromJson(Map<String, dynamic> r) => StudyEntry(
    r['id'],
    r['kind'],
    r['group'],
    r['word'],
    r['meaning'],
    r['example'],
    r['translation'],
  );
}

Future<List<StudyEntry>>? _loaded;
Future<List<StudyEntry>> loadEssentials() => _loaded ??= _read();
Future<List<StudyEntry>> _read() async => (jsonDecode(
  await rootBundle.loadString('assets/collections/essentials.json'),
) as List).map((r) => StudyEntry.fromJson(r)).toList(growable: false);

final _studyApostrophes = RegExp(r"[‘’ʻʼ`´]");
final _studySpaces = RegExp(r'\s+');
String normalizeStudyText(String text) => text
    .toLowerCase()
    .replaceAll(_studyApostrophes, "'")
    .replaceAll(_studySpaces, ' ')
    .trim();

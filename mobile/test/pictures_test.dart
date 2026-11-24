import 'package:flutter_test/flutter_test.dart';
import 'package:lingoy/core/illustrations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPictureCatalog);
  test('Ambiguous picture labels retain the depicted sense', () {
    const senses = {
      'bank': 'n8420278',
      'bow': 'n2880308',
      'date': 'n15159583',
      'plane': 'n3954731',
      'spring': 'n15237044',
      'diamond': 'n13882961',
      'iron': 'n3584829',
      'crane': 'n3126707',
      'mole': 'n4693804',
      'tissue': 'n15074962',
      'scale': 'n4141975',
      'style': 'n7066659',
    };
    for (final entry in senses.entries) {
      expect(pictureFor(entry.key)!.senseId, entry.value, reason: entry.key);
    }
  });
  test(
    'Illustrated words are unique and each uses a distinct valid atlas cell',
    () {
      expect(pictureWords.length, 10000);
      expect(pictureWords.map((p) => p.word).toSet().length, 10000);
      expect(
        starterPictureWords.map((p) => '${p.sheet}:${p.cell}').toSet().length,
        192,
      );
      for (final p in pictureWords) {
        expect(p.cell, inInclusiveRange(0, p.grid * p.grid - 1));
        expect(p.meaning, isNotEmpty);
        expect(p.category, isNotEmpty);
      }
    },
  );
  test(
    'Curated meanings reference the inspected water, bird and bus pictures',
    () {
      expect(pictureFor('water')!.sheet, 'food_v2');
      expect(pictureFor('water')!.cell, 5);
      expect(pictureFor('bird')!.cell, 2);
      expect(pictureFor('bus')!.cell, 1);
      expect(pictureFor('orange')!.meaning, 'apelsin');
      expect(pictureFor('abstract-unmapped-word'), isNull);
      expect(pictureFor('green river'), isNull);
      expect(pictureFor('ravisher'), isNull);
    },
  );
}

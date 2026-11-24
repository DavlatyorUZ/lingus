import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;

import '../ui/app_icons.dart';

/// Curated semantic image mappings. These illustrate the labeled meaning only.
class PictureWord {
  final String word, meaning, category, sheet;
  final int cell, grid;
  final String senseId, visualLabel;
  const PictureWord(
    this.word,
    this.meaning,
    this.category,
    this.sheet,
    this.cell, {
    this.grid = 4,
    this.senseId = '',
    this.visualLabel = '',
  });
  String get asset {
    final photo = photoFor(word);
    if (photo != null) return photo.asset;
    final id = grid == 4 ? _starterVectors[word] ?? word : sheet;
    return 'assets/pictures/vectors/${id.split('/').last}.svg.vec';
  }
}

class WordPhoto {
  final String asset, credit, license, source;
  const WordPhoto(this.asset, this.credit, this.license, this.source);
}

final Map<String, WordPhoto> _photos = {};
WordPhoto? photoFor(String word) => _photos[word.trim().toLowerCase()];
int get photographicWordCount => _photos.length;

const starterPictureWords = <PictureWord>[
  PictureWord("apple", "olma", "Mevalar", 'fruit_v2', 0),
  PictureWord("banana", "banan", "Mevalar", 'fruit_v2', 1),
  PictureWord("orange", "apelsin", "Mevalar", 'fruit_v2', 2),
  PictureWord("pear", "nok", "Mevalar", 'fruit_v2', 3),
  PictureWord("peach", "shaftoli", "Mevalar", 'fruit_v2', 4),
  PictureWord("grape", "uzum", "Mevalar", 'fruit_v2', 5),
  PictureWord("strawberry", "qulupnay", "Mevalar", 'fruit_v2', 6),
  PictureWord("watermelon", "tarvuz", "Mevalar", 'fruit_v2', 7),
  PictureWord("pineapple", "ananas", "Mevalar", 'fruit_v2', 8),
  PictureWord("lemon", "limon", "Mevalar", 'fruit_v2', 9),
  PictureWord("cherry", "gilos", "Mevalar", 'fruit_v2', 10),
  PictureWord("mango", "mango", "Mevalar", 'fruit_v2', 11),
  PictureWord("coconut", "kokos", "Mevalar", 'fruit_v2', 12),
  PictureWord("kiwi", "kivi", "Mevalar", 'fruit_v2', 13),
  PictureWord("apricot", "o‘rik", "Mevalar", 'fruit_v2', 14),
  PictureWord("plum", "olxo‘ri", "Mevalar", 'fruit_v2', 15),
  PictureWord("bread", "non", "Taomlar", 'food_v2', 0),
  PictureWord("rice", "guruch", "Taomlar", 'food_v2', 1),
  PictureWord("cheese", "pishloq", "Taomlar", 'food_v2', 2),
  PictureWord("egg", "tuxum", "Taomlar", 'food_v2', 3),
  PictureWord("milk", "sut", "Taomlar", 'food_v2', 4),
  PictureWord("water", "suv", "Taomlar", 'food_v2', 5),
  PictureWord("coffee", "qahva", "Taomlar", 'food_v2', 6),
  PictureWord("tea", "choy", "Taomlar", 'food_v2', 7),
  PictureWord("soup", "sho‘rva", "Taomlar", 'food_v2', 8),
  PictureWord("cake", "tort", "Taomlar", 'food_v2', 9),
  PictureWord("pizza", "pitsa", "Taomlar", 'food_v2', 10),
  PictureWord("sandwich", "sendvich", "Taomlar", 'food_v2', 11),
  PictureWord("carrot", "sabzi", "Taomlar", 'food_v2', 12),
  PictureWord("potato", "kartoshka", "Taomlar", 'food_v2', 13),
  PictureWord("tomato", "pomidor", "Taomlar", 'food_v2', 14),
  PictureWord("cucumber", "bodring", "Taomlar", 'food_v2', 15),
  PictureWord("cat", "mushuk", "Hayvonlar", 'animals_v2', 0),
  PictureWord("dog", "it", "Hayvonlar", 'animals_v2', 1),
  PictureWord("bird", "qush", "Hayvonlar", 'animals_v2', 2),
  PictureWord("fish", "baliq", "Hayvonlar", 'animals_v2', 3),
  PictureWord("horse", "ot", "Hayvonlar", 'animals_v2', 4),
  PictureWord("cow", "sigir", "Hayvonlar", 'animals_v2', 5),
  PictureWord("sheep", "qo‘y", "Hayvonlar", 'animals_v2', 6),
  PictureWord("goat", "echki", "Hayvonlar", 'animals_v2', 7),
  PictureWord("chicken", "tovuq", "Hayvonlar", 'animals_v2', 8),
  PictureWord("duck", "o‘rdak", "Hayvonlar", 'animals_v2', 9),
  PictureWord("pig", "cho‘chqa", "Hayvonlar", 'animals_v2', 10),
  PictureWord("rabbit", "quyon", "Hayvonlar", 'animals_v2', 11),
  PictureWord("lion", "sher", "Hayvonlar", 'animals_v2', 12),
  PictureWord("elephant", "fil", "Hayvonlar", 'animals_v2', 13),
  PictureWord("monkey", "maymun", "Hayvonlar", 'animals_v2', 14),
  PictureWord("tiger", "yo‘lbars", "Hayvonlar", 'animals_v2', 15),
  PictureWord("tree", "daraxt", "Tabiat", 'nature_v2', 0),
  PictureWord("flower", "gul", "Tabiat", 'nature_v2', 1),
  PictureWord("sun", "quyosh", "Tabiat", 'nature_v2', 2),
  PictureWord("moon", "oy", "Tabiat", 'nature_v2', 3),
  PictureWord("star", "yulduz", "Tabiat", 'nature_v2', 4),
  PictureWord("mountain", "tog‘", "Tabiat", 'nature_v2', 5),
  PictureWord("river", "daryo", "Tabiat", 'nature_v2', 6),
  PictureWord("sea", "dengiz", "Tabiat", 'nature_v2', 7),
  PictureWord("lake", "ko‘l", "Tabiat", 'nature_v2', 8),
  PictureWord("rain", "yomg‘ir", "Tabiat", 'nature_v2', 9),
  PictureWord("snow", "qor", "Tabiat", 'nature_v2', 10),
  PictureWord("cloud", "bulut", "Tabiat", 'nature_v2', 11),
  PictureWord("leaf", "barg", "Tabiat", 'nature_v2', 12),
  PictureWord("grass", "maysa", "Tabiat", 'nature_v2', 13),
  PictureWord("rock", "qoyatosh", "Tabiat", 'nature_v2', 14),
  PictureWord("island", "orol", "Tabiat", 'nature_v2', 15),
  PictureWord("house", "uy", "Uy", 'home_v2', 0),
  PictureWord("door", "eshik", "Uy", 'home_v2', 1),
  PictureWord("window", "deraza", "Uy", 'home_v2', 2),
  PictureWord("roof", "tom", "Uy", 'home_v2', 3),
  PictureWord("room", "xona", "Uy", 'home_v2', 4),
  PictureWord("bed", "karavot", "Uy", 'home_v2', 5),
  PictureWord("chair", "stul", "Uy", 'home_v2', 6),
  PictureWord("table", "stol", "Uy", 'home_v2', 7),
  PictureWord("sofa", "divan", "Uy", 'home_v2', 8),
  PictureWord("cupboard", "shkaf", "Uy", 'home_v2', 9),
  PictureWord("lamp", "chiroq", "Uy", 'home_v2', 10),
  PictureWord("mirror", "ko‘zgu", "Uy", 'home_v2', 11),
  PictureWord("carpet", "gilam", "Uy", 'home_v2', 12),
  PictureWord("clock", "soat", "Uy", 'home_v2', 13),
  PictureWord("key", "kalit", "Uy", 'home_v2', 14),
  PictureWord("umbrella", "soyabon", "Uy", 'home_v2', 15),
  PictureWord("book", "kitob", "Maktab", 'school_v2', 0),
  PictureWord("notebook", "daftar", "Maktab", 'school_v2', 1),
  PictureWord("pen", "ruchka", "Maktab", 'school_v2', 2),
  PictureWord("pencil", "qalam", "Maktab", 'school_v2', 3),
  PictureWord("ruler", "chizg‘ich", "Maktab", 'school_v2', 4),
  PictureWord("eraser", "o‘chirg‘ich", "Maktab", 'school_v2', 5),
  PictureWord("backpack", "ryukzak", "Maktab", 'school_v2', 6),
  PictureWord("paper", "qog‘oz", "Maktab", 'school_v2', 7),
  PictureWord("scissors", "qaychi", "Maktab", 'school_v2', 8),
  PictureWord("glue", "yelim", "Maktab", 'school_v2', 9),
  PictureWord("school", "maktab", "Maktab", 'school_v2', 10),
  PictureWord("teacher", "o‘qituvchi", "Maktab", 'school_v2', 11),
  PictureWord("student", "o‘quvchi", "Maktab", 'school_v2', 12),
  PictureWord("classroom", "sinfxona", "Maktab", 'school_v2', 13),
  PictureWord("computer", "kompyuter", "Maktab", 'school_v2', 14),
  PictureWord("phone", "telefon", "Maktab", 'school_v2', 15),
  PictureWord("shirt", "ko‘ylak", "Kiyim va tana", 'clothes_v2', 0),
  PictureWord("tie", "galstuk", "Kiyim va tana", 'clothes_v2', 1),
  PictureWord(
    "dress",
    "ko‘ylak (ayollar kiyimi)",
    "Kiyim va tana",
    'clothes_v2',
    2,
  ),
  PictureWord("skirt", "yubka", "Kiyim va tana", 'clothes_v2', 3),
  PictureWord("coat", "palto", "Kiyim va tana", 'clothes_v2', 4),
  PictureWord("jacket", "kurtka", "Kiyim va tana", 'clothes_v2', 5),
  PictureWord("shoe", "tufli", "Kiyim va tana", 'clothes_v2', 6),
  PictureWord("sock", "paypoq", "Kiyim va tana", 'clothes_v2', 7),
  PictureWord("hat", "shlyapa", "Kiyim va tana", 'clothes_v2', 8),
  PictureWord("cap", "kepka", "Kiyim va tana", 'clothes_v2', 9),
  PictureWord("glove", "qo‘lqop", "Kiyim va tana", 'clothes_v2', 10),
  PictureWord("belt", "kamar", "Kiyim va tana", 'clothes_v2', 11),
  PictureWord("hand", "qo‘l panjasi", "Kiyim va tana", 'clothes_v2', 12),
  PictureWord("foot", "oyoq panjasi", "Kiyim va tana", 'clothes_v2', 13),
  PictureWord("eye", "ko‘z", "Kiyim va tana", 'clothes_v2', 14),
  PictureWord("ear", "quloq", "Kiyim va tana", 'clothes_v2', 15),
  PictureWord("car", "avtomobil", "Transport", 'transport_v2', 0),
  PictureWord("bus", "avtobus", "Transport", 'transport_v2', 1),
  PictureWord("train", "poyezd", "Transport", 'transport_v2', 2),
  PictureWord("airplane", "samolyot", "Transport", 'transport_v2', 3),
  PictureWord("bicycle", "velosiped", "Transport", 'transport_v2', 4),
  PictureWord("motorcycle", "mototsikl", "Transport", 'transport_v2', 5),
  PictureWord("boat", "qayiq", "Transport", 'transport_v2', 6),
  PictureWord("ship", "kema", "Transport", 'transport_v2', 7),
  PictureWord("truck", "yuk mashinasi", "Transport", 'transport_v2', 8),
  PictureWord("taxi", "taksi", "Transport", 'transport_v2', 9),
  PictureWord("helicopter", "vertolyot", "Transport", 'transport_v2', 10),
  PictureWord("bridge", "ko‘prik", "Transport", 'transport_v2', 11),
  PictureWord("road", "yo‘l", "Transport", 'transport_v2', 12),
  PictureWord("airport", "aeroport", "Transport", 'transport_v2', 13),
  PictureWord("station", "temiryo‘l bekati", "Transport", 'transport_v2', 14),
  PictureWord("wheel", "g‘ildirak", "Transport", 'transport_v2', 15),
  PictureWord("mother", "ona", "Odamlar", 'people_v2', 0),
  PictureWord("father", "ota", "Odamlar", 'people_v2', 1),
  PictureWord("baby", "chaqaloq", "Odamlar", 'people_v2', 2),
  PictureWord("boy", "o‘g‘il bola", "Odamlar", 'people_v2', 3),
  PictureWord("girl", "qiz bola", "Odamlar", 'people_v2', 4),
  PictureWord("family", "oila", "Odamlar", 'people_v2', 5),
  PictureWord("doctor", "shifokor", "Odamlar", 'people_v2', 6),
  PictureWord("nurse", "hamshira", "Odamlar", 'people_v2', 7),
  PictureWord("hospital", "shifoxona", "Odamlar", 'people_v2', 8),
  PictureWord("dentist", "tish shifokori", "Odamlar", 'people_v2', 9),
  PictureWord("firefighter", "o‘t o‘chiruvchi", "Odamlar", 'people_v2', 10),
  PictureWord("chef", "oshpaz", "Odamlar", 'people_v2', 11),
  PictureWord("farmer", "fermer", "Odamlar", 'people_v2', 12),
  PictureWord("artist", "rassom", "Odamlar", 'people_v2', 13),
  PictureWord("singer", "qo‘shiqchi", "Odamlar", 'people_v2', 14),
  PictureWord("driver", "haydovchi", "Odamlar", 'people_v2', 15),
  PictureWord("bag", "sumka", "Buyumlar", 'everyday_v2', 0),
  PictureWord("cup", "piyola", "Buyumlar", 'everyday_v2', 1),
  PictureWord("plate", "likopcha", "Buyumlar", 'everyday_v2', 2),
  PictureWord("bowl", "kosa", "Buyumlar", 'everyday_v2', 3),
  PictureWord("spoon", "qoshiq", "Buyumlar", 'everyday_v2', 4),
  PictureWord("fork", "sanchqi", "Buyumlar", 'everyday_v2', 5),
  PictureWord("knife", "pichoq", "Buyumlar", 'everyday_v2', 6),
  PictureWord("bottle", "shisha idish", "Buyumlar", 'everyday_v2', 7),
  PictureWord("box", "quti", "Buyumlar", 'everyday_v2', 8),
  PictureWord("gift", "sovg‘a", "Buyumlar", 'everyday_v2', 9),
  PictureWord("ball", "to‘p", "Buyumlar", 'everyday_v2', 10),
  PictureWord("kite", "varrak", "Buyumlar", 'everyday_v2', 11),
  PictureWord("guitar", "gitara", "Buyumlar", 'everyday_v2', 12),
  PictureWord("violin", "skripka", "Buyumlar", 'everyday_v2', 13),
  PictureWord("camera", "fotoapparat", "Buyumlar", 'everyday_v2', 14),
  PictureWord("watch", "qo‘l soati", "Buyumlar", 'everyday_v2', 15),
  PictureWord("run", "yugurmoq", "Harakatlar", 'actions_v2', 0),
  PictureWord("walk", "piyoda yurmoq", "Harakatlar", 'actions_v2', 1),
  PictureWord("read", "o‘qimoq", "Harakatlar", 'actions_v2', 2),
  PictureWord("write", "yozmoq", "Harakatlar", 'actions_v2', 3),
  PictureWord("eat", "yemoq", "Harakatlar", 'actions_v2', 4),
  PictureWord("drink", "ichmoq", "Harakatlar", 'actions_v2', 5),
  PictureWord("sleep", "uxlamoq", "Harakatlar", 'actions_v2', 6),
  PictureWord("swim", "suzmoq", "Harakatlar", 'actions_v2', 7),
  PictureWord("jump", "sakramoq", "Harakatlar", 'actions_v2', 8),
  PictureWord("dance", "raqsga tushmoq", "Harakatlar", 'actions_v2', 9),
  PictureWord("sing", "kuylamoq", "Harakatlar", 'actions_v2', 10),
  PictureWord("cook", "ovqat pishirmoq", "Harakatlar", 'actions_v2', 11),
  PictureWord("draw", "rasm chizmoq", "Harakatlar", 'actions_v2', 12),
  PictureWord("listen", "tinglamoq", "Harakatlar", 'actions_v2', 13),
  PictureWord("speak", "gapirmoq", "Harakatlar", 'actions_v2', 14),
  PictureWord("laugh", "kulmoq", "Harakatlar", 'actions_v2', 15),
  PictureWord("head", "bosh", "Atrofimizda", 'more_v2', 0),
  PictureWord("hair", "soch", "Atrofimizda", 'more_v2', 1),
  PictureWord("nose", "burun", "Atrofimizda", 'more_v2', 2),
  PictureWord("mouth", "og‘iz", "Atrofimizda", 'more_v2', 3),
  PictureWord("tooth", "tish", "Atrofimizda", 'more_v2', 4),
  PictureWord("arm", "qo‘l", "Atrofimizda", 'more_v2', 5),
  PictureWord("leg", "oyoq", "Atrofimizda", 'more_v2', 6),
  PictureWord("finger", "barmoq", "Atrofimizda", 'more_v2', 7),
  PictureWord("keyboard", "klaviatura", "Atrofimizda", 'more_v2', 8),
  PictureWord("mouse", "kompyuter sichqonchasi", "Atrofimizda", 'more_v2', 9),
  PictureWord("television", "televizor", "Atrofimizda", 'more_v2', 10),
  PictureWord("refrigerator", "muzlatkich", "Atrofimizda", 'more_v2', 11),
  PictureWord(
    "washing machine",
    "kir yuvish mashinasi",
    "Atrofimizda",
    'more_v2',
    12,
  ),
  PictureWord("fan", "ventilyator", "Atrofimizda", 'more_v2', 13),
  PictureWord("beach", "plyaj", "Atrofimizda", 'more_v2', 14),
  PictureWord("garden", "bog‘", "Atrofimizda", 'more_v2', 15),
];
final Map<String, String> _starterVectors = {};
final List<PictureWord> pictureWords = List.of(starterPictureWords);
final Map<String, PictureWord> _pictureIndex = {
  for (final p in starterPictureWords) p.word: p,
};
final List<String> pictureCategories = [];
final Map<String, List<PictureWord>> picturesByCategory = {};
Future<void>? _catalogLoading;
List<dynamic> _decodeCatalog(String text) => jsonDecode(text) as List<dynamic>;
Future<void> loadPictureCatalog() => _catalogLoading ??= _loadCatalog();
Future<void> _loadCatalog() async {
  try {
    final photos = jsonDecode(
      await rootBundle.loadString('assets/photo_index.json'),
    ) as Map;
    final assets = photos['assets'] as Map;
    for (final entry in (photos['words'] as Map).entries) {
      final p = assets[entry.value] as Map;
      _photos[entry.key] = WordPhoto(
        p['asset'],
        p['credit'],
        p['license'],
        p['source'],
      );
    }
    _starterVectors.addAll(
      (jsonDecode(
        await rootBundle.loadString('assets/starter_vectors.json'),
      ) as Map).cast<String, String>(),
    );
    final rows = await compute(
      _decodeCatalog,
      await rootBundle.loadString('assets/picture_index.json'),
    );
    for (final raw in rows) {
      final r = raw as List<dynamic>;
      final p = PictureWord(
        r[0] as String,
        r[1] as String,
        r[3] as String,
        r[2] as String,
        0,
        grid: 1,
        senseId: r[4] as String,
        visualLabel: r[5] as String,
      );
      if (_pictureIndex.containsKey(p.word)) continue;
      pictureWords.add(p);
      _pictureIndex[p.word] = p;
    }
    picturesByCategory.clear();
    for (final p in pictureWords) {
      picturesByCategory.putIfAbsent(p.category, () => []).add(p);
    }
    pictureCategories
      ..clear()
      ..addAll(picturesByCategory.keys);
  } catch (_) {
    _catalogLoading = null;
    rethrow;
  }
}

PictureWord? pictureFor(String lemma) =>
    _pictureIndex[lemma.trim().toLowerCase()];

class WordArt extends StatefulWidget {
  final PictureWord picture;
  final double? width, height;
  final double radius;
  const WordArt(
    this.picture, {
    super.key,
    this.width,
    this.height,
    this.radius = 20,
  });
  @override
  State<WordArt> createState() => _WordArtState();
}

class _WordArtState extends State<WordArt> {
  late vg.AssetBytesLoader loader;
  bool active = true;
  @override
  void initState() {
    super.initState();
    loader = vg.AssetBytesLoader(widget.picture.asset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    active = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(covariant WordArt old) {
    super.didUpdateWidget(old);
    if (old.picture.asset != widget.picture.asset) {
      loader = vg.AssetBytesLoader(widget.picture.asset);
    }
  }

  @override
  Widget build(BuildContext c) => Semantics(
    image: true,
    label: '${widget.picture.word}: ${widget.picture.meaning}',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: !active
              ? const Center(child: AppIcon(AppIcons.imageOutlined, size: 24))
              : RepaintBoundary(
                  child: widget.picture.asset.endsWith('.webp')
                      ? LayoutBuilder(
                          builder: (c, box) {
                            final target = box.maxWidth.isFinite
                                ? box.maxWidth
                                : 240.0;
                            return Image.asset(
                              widget.picture.asset,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              cacheWidth:
                                  (target * MediaQuery.devicePixelRatioOf(c))
                                      .ceil()
                                      .clamp(64, 1200),
                              excludeFromSemantics: true,
                            );
                          },
                        )
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture(
                            loader,
                            key: ValueKey(widget.picture.asset),
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            errorBuilder: (_, error, stack) => const Center(
                              child: Text(
                                'Rasm ochilmadi',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                ),
        ),
      ),
    ),
  );
}

/// Broad American transcriptions for the illustrated starter pack.
const picturePhonetics = <String, String>{
  'apple': '/ˈæpəl/',
  'bread': '/brɛd/',
  'water': '/ˈwɔtɚ/',
  'milk': '/mɪlk/',
  'rice': '/raɪs/',
  'banana': '/bəˈnænə/',
  'orange': '/ˈɔrɪndʒ/',
  'egg': '/ɛɡ/',
  'cheese': '/tʃiːz/',
  'cat': '/kæt/',
  'dog': '/dɔɡ/',
  'bird': '/bɝd/',
  'fish': '/fɪʃ/',
  'tree': '/triː/',
  'flower': '/ˈflaʊɚ/',
  'sun': '/sʌn/',
  'moon': '/muːn/',
  'mountain': '/ˈmaʊntən/',
  'house': '/haʊs/',
  'car': '/kɑɹ/',
  'bus': '/bʌs/',
  'airplane': '/ˈɛɹpleɪn/',
  'train': '/tɹeɪn/',
  'computer': '/kəmˈpjuːtɚ/',
  'phone': '/foʊn/',
  'chair': '/tʃɛɹ/',
  'table': '/ˈteɪbəl/',
  'book': '/bʊk/',
  'teacher': '/ˈtiːtʃɚ/',
  'student': '/ˈstuːdənt/',
  'school': '/skuːl/',
  'doctor': '/ˈdɑktɚ/',
  'hospital': '/ˈhɑspɪtəl/',
  'clock': '/klɑk/',
  'pen': '/pɛn/',
  'pencil': '/ˈpɛnsəl/',
  'coffee': '/ˈkɔfi/',
  'tea': '/tiː/',
  'shoe': '/ʃuː/',
  'bag': '/bæɡ/',
  'key': '/kiː/',
  'umbrella': '/ʌmˈbrɛlə/',
};

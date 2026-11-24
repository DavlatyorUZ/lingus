import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../ui/design.dart';
import '../ui/tab_motion.dart';
import '../core/models.dart';
import '../core/illustrations.dart';
import 'vocabulary.dart';
import 'account.dart';
import '../core/account_api.dart';
import 'home.dart';
import '../core/store.dart';
import '../core/support.dart';
import '../core/release.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext c) => ListView(
    padding: EdgeInsets.fromLTRB(
      18,
      16,
      18,
      30 + MediaQuery.paddingOf(c).bottom,
    ),
    children:
        [
              Row(
                children: [Expanded(child: Text('Profil', style: display(22)))],
              ),
              const SizedBox(height: 16),
              const AccountCard(),
              const SizedBox(height: 16),
              if (!accountApi.signedIn)
                Glass(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: palette(c).elevated,
                        child: Text(
                          store.name.characters.first.toUpperCase(),
                          style: display(21),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.name, style: display(21)),
                            const SizedBox(height: 8),
                            LevelBadge(store.level),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ismni o‘zgartirish',
                        icon: const AppIcon(AppIcons.editOutlined, size: 20),
                        onPressed: () async {
                          final name = await askText(
                            c,
                            'Ismingiz',
                            initial: store.name,
                          );
                          if (name == null) return;
                          if (!Store.validName(name)) {
                            if (c.mounted) {
                              toast(c, 'Ismingizni 1–32 harf bilan kiriting.');
                            }
                            return;
                          }
                          await store.configure(newName: name);
                        },
                      ),
                    ],
                  ),
                ),
              const _ProfileTitle('Natijalar'),
              FutureBuilder<Map<String, int>>(
                future: store.stats(),
                builder: (c, s) {
                  final st = s.data ?? {};
                  final total = st['total'] ?? 0;
                  final accuracy = total == 0
                      ? '—'
                      : '${((st['correct'] ?? 0) / total * 100).round()}%';
                  final values = <String, String>{
                    'Saqlangan so‘z': '${st['saved'] ?? 0}',
                    'Jami mashq': '$total',
                    'To‘g‘ri javob': accuracy,
                    'Ketma-ket kun': '${st['streak'] ?? 0}',
                  };
                  return LayoutBuilder(
                    builder: (c, box) {
                      final columns = MediaQuery.textScalerOf(c).scale(14) > 21
                          ? 1
                          : 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final e in values.entries)
                            SizedBox(
                              width:
                                  (box.maxWidth - (columns - 1) * 12) / columns,
                              child: _result(c, e.key, e.value),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              const _ProfileTitle('Oxirgi 7 kun'),
              FutureBuilder<List<int>>(
                future: store.week(),
                builder: (c, s) {
                  final v = s.data ?? List.filled(7, 0);
                  final max = math.max(1, v.reduce(math.max));
                  if (v.every((n) => n == 0)) {
                    return Glass(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppIcon(AppIcons.trackChangesOutlined, size: 25),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Birinchi qadam sizdan',
                                  style: display(15),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'O‘yindan keyin haftalik natijalar shu yerda ko‘rinadi.',
                                  style: TextStyle(
                                    color: muted(c),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Glass(
                    child: Column(
                      children: [
                        SizedBox(
                          height:
                              104 + MediaQuery.textScalerOf(c).scale(10) * 3,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final date = DateTime.now().subtract(
                                Duration(days: 6 - i),
                              );
                              return Expanded(
                                child: Semantics(
                                  label:
                                      '${date.day}.${date.month}: ${v[i]} mashq',
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${v[i]}',
                                        style: TextStyle(
                                          color: muted(c),
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedContainer(
                                        duration: motionDuration(c, 600),
                                        curve: Curves.easeOutCubic,
                                        width: 22,
                                        height: math.max(3, v[i] / max * 74),
                                        decoration: BoxDecoration(
                                          color: i == 6
                                              ? sage
                                              : gold.withValues(alpha: .65),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          color: muted(c),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const _ProfileTitle('O‘zingizga moslang'),
              Glass(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row(
                      'Harakat va tezlik',
                      store.motion == 'light'
                          ? 'Yengil rejim'
                          : store.motion == 'smooth'
                          ? 'To‘liq animatsiya'
                          : 'Avtomatik',
                      AppIcons.settingsBrightnessOutlined,
                      () => showMotionSettings(c),
                    ),
                    _Row(
                      'Mening lug‘atim',
                      'So‘zlar, papkalar va CSV',
                      AppIcons.bookmarksOutlined,
                      () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => const VocabularyScreen(),
                        ),
                      ),
                    ),
                    _Row(
                      'O‘quv darajasi',
                      store.level,
                      AppIcons.stairsOutlined,
                      () => chooseLevel(c),
                    ),
                    _Row(
                      'Kunlik maqsad',
                      '${store.goal} ta mashq',
                      AppIcons.trackChangesOutlined,
                      () => chooseGoal(c),
                    ),

                    _Row(
                      'Baza va manbalar',
                      'Qamrov, litsenziyalar, versiya',
                      AppIcons.offlinePinOutlined,
                      () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => const DataInfoScreen(),
                        ),
                      ),
                    ),
                    _Row(
                      'Maxfiylik',
                      'Qanday ma’lumotlar saqlanadi?',
                      AppIcons.privacyTipOutlined,
                      () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _ProfileTitle('Yordam'),
              Glass(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    MenuRow(
                      'Telegram',
                      '@davlatyoruz',
                      AppIcons.send,
                      () => contact(c, SupportContact.telegram),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    MenuRow(
                      'Qo‘ng‘iroq',
                      '+998934920107',
                      AppIcons.phone,
                      () => contact(c, SupportContact.phone),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => deleteData(c),
                child: Text(
                  'O‘quv ma’lumotlarini tozalash',
                  style: TextStyle(color: palette(c).error, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lingoy $appVersion · Barcha imkoniyatlar bepul',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted(c), fontSize: 10),
              ),
            ].indexed
            .map(
              (e) =>
                  SceneItem(delay: (e.$1 * .025).clamp(0.0, .35), child: e.$2),
            )
            .toList(),
  );
  Widget _result(BuildContext c, String label, String value) => Glass(
    padding: const EdgeInsets.all(14),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: display(22, color: Theme.of(c).colorScheme.primary),
          ),
          const SizedBox(height: 7),
          Text(label, style: TextStyle(color: muted(c), fontSize: 12)),
        ],
      ),
    ),
  );
  Future<void> contact(BuildContext c, Uri uri) async {
    final ok = await SupportContact.open(uri);
    if (!ok && c.mounted) {
      toast(c, 'Ochib bo‘lmadi. Kerakli ilova o‘rnatilganini tekshiring.');
    }
  }

  Future<void> chooseLevel(BuildContext c) async {
    final v = await showModalBottomSheet<String>(
      context: c,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: levels
              .asMap()
              .entries
              .map(
                (e) => ListTile(
                  leading: LevelBadge(e.value),
                  title: Text(levelNames[e.key]),
                  trailing: store.level == e.value
                      ? AppIcon(AppIcons.check, color: muted(c))
                      : null,
                  onTap: () => Navigator.pop(c, e.value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (v != null) await store.configure(newLevel: v);
  }

  Future<void> chooseGoal(BuildContext c) async {
    final v = await showModalBottomSheet<int>(
      context: c,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 20, 30]
              .map(
                (g) => ListTile(
                  title: Text('$g ta mashq'),
                  trailing: store.goal == g
                      ? AppIcon(AppIcons.check, color: muted(c))
                      : null,
                  onTap: () => Navigator.pop(c, g),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (v != null) await store.configure(newGoal: v);
  }

  Future<void> chooseTheme(BuildContext c) async {
    final v = await showModalBottomSheet<String>(
      context: c,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              {'light': 'Yorug‘', 'dark': 'Tungi', 'system': 'Tizim bo‘yicha'}
                  .entries
                  .map(
                    (e) => ListTile(
                      title: Text(e.value),
                      trailing: store.theme == e.key
                          ? AppIcon(AppIcons.check, color: muted(c))
                          : null,
                      onTap: () => Navigator.pop(c, e.key),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
    if (v != null) await store.configure(newTheme: v);
  }

  Future<void> deleteData(BuildContext c) async {
    final ok = await showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        title: Text('O‘quv ma’lumotlari o‘chirilsinmi?', style: display(24)),
        content: Text(
          'Saqlangan so‘zlar, papkalar, mashq natijalari bu telefondan o‘chadi. Oflayn lug‘at saqlanadi. Bu amalni ortga qaytarib bo‘lmaydi. Avval CSV eksport qilishingiz mumkin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('O‘chirish', style: TextStyle(color: palette(c).error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.clearUserData();
      if (c.mounted) toast(c, 'O‘quv ma’lumotlari tozalandi.');
    }
  }
}

class _Row extends StatelessWidget {
  final String title, caption;
  final String icon;
  final VoidCallback tap;
  const _Row(this.title, this.caption, this.icon, this.tap);
  @override
  Widget build(BuildContext c) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 19, vertical: 7),
    leading: AppIcon(icon, color: muted(c), size: 21),
    title: Text(
      title,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(caption, style: TextStyle(fontSize: 10, color: muted(c))),
    trailing: AppIcon(AppIcons.chevronRight, color: muted(c), size: 18),
    onTap: tap,
  );
}

class DataInfoScreen extends StatelessWidget {
  const DataInfoScreen({super.key});
  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Baza va manbalar',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Lug‘at qamrovi', style: display(24)),
        const SizedBox(height: 23),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _info(
                c,
                'Inglizcha so‘z va iboralar',
                displayCount(store.coverage['entries'] as int),
              ),
              _info(
                c,
                'O‘zbekcha ma’nosi bor yozuvlar',
                displayCount(store.coverage['translated_entries'] as int),
              ),
              _info(
                c,
                'Manbali CEFR darajalari',
                displayCount(store.coverage['leveled_entries'] as int),
              ),
              _info(
                c,
                'CMU asosidagi fonemik yozuv',
                displayCount(store.coverage['phonetic_entries'] as int),
              ),
              _info(c, 'Rasmli so‘z va iboralar', '${pictureWords.length}'),
              _info(
                c,
                'Inglizcha ma’no guruhlari',
                displayCount(store.coverage['senses'] as int),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Lug‘at inglizcha so‘zlar va iboralarni qamrab oladi. Bularning hammasida o‘zbekcha tarjima bor degani emas. Noma’lum darajalarga sun’iy CEFR bahosi qo‘yilmagan.',
          style: TextStyle(color: muted(c), fontSize: 13),
        ),
        const SizedBox(height: 12),
        Text(
          '10 000 ta yozuv rasmli: 7 651 ta alohida so‘z va 2 349 ta ibora. Bir ma’nodagi sinonimlar bitta tasvirdan foydalanadi. Tasvir so‘zning ko‘rsatilgan ma’nosiga tegishli. Shulardan $photographicWordCount ta yozuvda yuqori aniqlikdagi fotosurat yoki foto uslubidagi yangi tasvir ishlatiladi, qolganlarida vektor tasvir va belgilar bor. Yangi to‘plamda kalit so‘zlar bilan bog‘langan belgilar ham bor; ular barcha ma’nolar uchun aynan bir xil tasvir degani emas. Fotosuratlarning muallifi va litsenziyasi alohida berilgan. Manbalar: Lingoy, Wikimedia Commons, Mulberry, OpenMoji, Tabler, Material Design Icons va Font Awesome; litsenziyalar quyida. O‘yinlar faqat siz saqlagan so‘zlardan tuziladi.',
          style: TextStyle(color: muted(c), fontSize: 13),
        ),
        const _ProfileTitle('Qayerdan olingan?'),
        Text(
          '• Princeton WordNet 3.0: inglizcha izohlar, misollar, sinonimlar va antonimlar.\n\n• UzWordnet 1.0, LDKR Group / Inha University in Tashkent: WordNet ma’no identifikatorlari orqali moslangan o‘zbekcha ma’nolar. Manba sifati turlicha; ayrim tarjimalar qo‘shimcha tahrirga muhtoj.\n\n• CEFR-J Vocabulary Profile 1.5, Yukio Tono / TUFS: A1–B2.\n\n• Octanove Vocabulary Profile 1.0: C1–C2.\n\n• CMU Pronouncing Dictionary: AQSH inglizcha ARPAbet talaffuzi keng fonemik yozuvga o‘girilgan. Bo‘g‘in chegaralari hisoblanmagan.\n\n• LINGOY: original boshlang‘ich tarjimalar va grammatika darslari.',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 24),
        TactileButton(
          'To‘liq litsenziyalar',
          secondary: true,
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const LicensesScreen()),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Ushbu ilova Wisdom bilan bog‘liq emas. Uning ma’lumotlar bazasi, brendi yoki interfeysi ko‘chirilmagan.',
          style: TextStyle(color: muted(c), fontSize: 10),
        ),
      ],
    ),
  );
  Widget _info(BuildContext c, String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 11, color: muted(c))),
        ),
        const SizedBox(width: 12),
        Text(value, style: display(20)),
      ],
    ),
  );
}

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});
  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Litsenziyalar',
    child: FutureBuilder<String>(
      future: Future.wait([
        rootBundle.loadString('assets/licenses.txt'),
        rootBundle.loadString('assets/photo_credits.txt'),
      ]).then((parts) => parts.join('\n\n')),
      builder: (c, s) => SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: SelectableText(
          s.data ?? 'Yuklanmoqda…',
          style: TextStyle(fontSize: 11, height: 1.6),
        ),
      ),
    ),
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext c) => const PageFrame(
    title: 'Maxfiylik',
    child: SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: SelectableText(
        'LINGOY $appVersion — oflayn lug‘at va ixtiyoriy onlayn xizmatlar\n\nOddiy lug‘at, saqlangan so‘zlar va mashqlar akkauntsiz ham ishlaydi. Mehmon ma’lumotlari qurilmangizda qoladi. Akkauntga kirganda email, ism va saqlangan so‘zlar Lingoy serverida saqlanadi; Google bilan kirsangiz profil rasmi ham olinadi. Mehmon so‘zlarini akkauntga ko‘chirish alohida tugma orqali bajariladi. Papkalar, mashq tarixi va takrorlash jadvali shu qurilmada saqlanadi.\n\nOnlayn tarjima yoki grammatika tugmasini bosganingizda matn, rasm tarjimasida esa tanlangan siqilgan rasm Lingoy serveri orqali Google Gemini xizmatiga yuboriladi. Lug‘atda tarjimasi yetishmagan so‘zni ochish yoki ma’nosini aniqlash ham onlayn tarjimadan foydalanadi. Javoblar Lingoy serverida 24 soat kesh qilinadi; lug‘atga qo‘shilgan so‘z ma’nolari qayta foydalanish uchun saqlanadi. Maxfiy ma’lumotni lug‘at qidiruviga kiritmang.\n\nOflayn grammatika matnni qurilmada sodda qoidalar bilan tekshiradi va barcha xatolarni qamrab olmaydi. AI natijalari ham xato qilishi mumkin. Talaffuz qurilmada mavjud inglizcha TTS ovoziga bog‘liq. Ovozli qidiruv faqat mikrofon tugmasi bosilganda Android nutqni tanish xizmatini ochadi. Bu xizmat internetdan foydalanishi mumkin. Lingoy audio yozuvni saqlamaydi.\n\nEmail kodi 10 daqiqa amal qiladi. Parol almashtirilganda eski sessiyalar bekor bo‘ladi. Kod va parolni boshqa odamga bermang. Akkaunt ma’lumotlari yoki saqlangan so‘zlar bo‘yicha yordam kerak bo‘lsa Profil → Yordam orqali murojaat qiling.\n\nCSV eksporti tizim ulashish oynasi orqali o‘zingiz tanlagan ilovaga yuboriladi; u so‘zlar ro‘yxatini saqlaydi, takrorlash tarixini emas. Telegram va telefon tugmalari faqat bosilganda tashqi aloqa oynasini ochadi.\n\nIlovani o‘chirish mahalliy ma’lumotlarni yo‘qotadi. Akkauntga sinxronlangan so‘zlar qayta kirganda tiklanadi. Android avtomatik backup xizmati o‘chirilgan. Ma’lumot manbalari va litsenziyalar “Baza va manbalar” bo‘limida.',
        style: TextStyle(fontSize: 13, height: 1.85),
      ),
    ),
  );
}

class _ProfileTitle extends StatelessWidget {
  final String text;
  const _ProfileTitle(this.text);
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Text(text, style: display(17)),
  );
}

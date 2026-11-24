import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'ui/design.dart';
import 'ui/tab_motion.dart';
import 'ui/motion_nav.dart';
import 'screens/home.dart';
import 'screens/dictionary.dart';
import 'screens/learn.dart';
import 'screens/profile.dart';
import 'screens/account.dart';
import 'core/store.dart';
import 'core/account_api.dart';
import 'core/photo_input.dart';
import 'core/release.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Lingoy photos',
    ], await rootBundle.loadString('assets/photo_credits.txt'));
  });
  WidgetsBinding.instance.addObserver(_MemoryObserver());
  PaintingBinding.instance.imageCache.maximumSize = 80;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 24 * 1024 * 1024;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LingoyApp());
  // Recover camera results without delaying the offline dictionary startup.
  recoverPhotoAtStartup();
  await store.init();
  await initializeAccount();
}

bool _accountStarted = false;
Future<void> initializeAccount() async {
  if (store.ready && !_accountStarted) {
    _accountStarted = true;
    accountApi.onAccount = store.bindAccount;
    accountApi.addListener(() {
      store.syncSaved();
      store.notifyListeners();
    });
    try {
      await accountApi.initialize();
    } catch (_) {
      /* Offline mode remains available. */
    }
  }
}

class _MemoryObserver extends WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    store.syncSaved();
    final before = (DeviceBudget.lowMemory, DeviceBudget.batterySaver);
    DeviceBudget.inspect().then((_) {
      if (store.ready &&
          before != (DeviceBudget.lowMemory, DeviceBudget.batterySaver)) {
        store.notifyListeners();
      }
    });
  }
}

class LingoyApp extends StatelessWidget {
  final DateTime? referenceTime;
  const LingoyApp({super.key, this.referenceTime});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) => MaterialApp(
      title: 'LINGOY',
      debugShowCheckedModeBanner: false,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
      theme: appTheme(false),
      darkTheme: appTheme(true),
      themeMode: store.theme == 'dark'
          ? ThemeMode.dark
          : store.theme == 'system'
          ? ThemeMode.system
          : ThemeMode.light,
      builder: (context, child) {
        final light =
            store.motion == 'light' ||
            (store.motion == 'auto' &&
                (DeviceBudget.lowMemory || DeviceBudget.batterySaver));
        PaintingBinding.instance.imageCache.maximumSizeBytes =
            (light ? 16 : 24) * 1024 * 1024;
        return MotionPolicy(light: light, child: child!);
      },
      home: AnimatedSwitcher(
        duration:
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        child: !store.ready
            ? const LoadingScreen(key: ValueKey('startup'))
            : !store.onboarded
            ? const Onboarding(key: ValueKey('onboarding'))
            : Shell(key: const ValueKey('shell'), referenceTime: referenceTime),
      ),
    ),
  );
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: store,
    builder: (c, _) => Scaffold(
      body: CanvasBg(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(c)
                        ? Duration.zero
                        : const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (c, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - value)),
                        child: Transform.scale(
                          scale: .94 + value * .06,
                          child: child,
                        ),
                      ),
                    ),
                    child: const BrandMark(size: 96),
                  ),
                  const SizedBox(height: 24),
                  Text('LINGOY', style: display(40)),
                  const SizedBox(height: 8),
                  Text(
                    'Har bir so‘z — yangi imkoniyat',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (store.error == null) ...[
                    CircularProgressIndicator(strokeWidth: 2, color: muted(c)),
                    const SizedBox(height: 16),
                    Text(
                      store.recovering
                          ? 'Lug‘at tiklanmoqda…\nSaqlangan so‘zlaringiz joyida qoladi.'
                          : '${store.startupStage}\nBirinchi ochilish biroz vaqt olishi mumkin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: muted(c)),
                    ),
                  ] else ...[
                    Text(store.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await store.init();
                        await initializeAccount();
                      },
                      child: const Text('Qayta urinish'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lingoy $appVersion · $appBuild',
                      style: TextStyle(fontSize: 12, color: muted(c)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 48});
  @override
  Widget build(BuildContext c) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .29),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6A2FC8), Color(0xFF9D71E8)],
      ),
      border: Border.all(color: gold.withValues(alpha: .6)),
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: .16),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .29),
      child: Image.asset(
        'assets/lingoy_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(c)).ceil().clamp(
          128,
          1024,
        ),
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> start() async {
    if (saving || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    try {
      await store.configure(newName: name.text, finish: true);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, 'Ismni saqlab bo‘lmadi. Qayta urinib ko‘ring.');
      }
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: CanvasBg(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 64),
                ),
                const SizedBox(height: 32),
                MotionIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lingoy’ga xush kelibsiz', style: display(28)),
                      const SizedBox(height: 12),
                      Text(
                        'Sizga qanday murojaat qilaylik?',
                        style: TextStyle(color: muted(c), fontSize: 15),
                      ),
                      const SizedBox(height: 28),
                      Form(
                        key: form,
                        child: TextFormField(
                          key: const ValueKey('name-input'),
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          maxLength: 32,
                          onFieldSubmitted: (_) => start(),
                          validator: (v) => Store.validName(v ?? '')
                              ? null
                              : 'Ismingizni harflar bilan kiriting.',
                          decoration: const InputDecoration(
                            labelText: 'Ismingiz',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: TactileButton(
                          saving ? 'Saqlanmoqda…' : 'Boshlash',
                          icon: AppIcons.arrowForward,
                          onTap: saving ? null : start,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Ismingiz faqat shu qurilmada saqlanadi.',
                        style: TextStyle(color: muted(c), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  final DateTime? referenceTime;
  const Shell({super.key, this.referenceTime});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0, direction = 1;
  final visited = <int>{0};
  void select(int value) {
    if (value == index) return;
    setState(() {
      direction = value > index ? 1 : -1;
      visited.add(value);
      index = value;
    });
  }

  @override
  Widget build(BuildContext c) {
    final pages = [
      HomeScreen(onTab: select, referenceTime: widget.referenceTime),
      const DictionaryScreen(),
      const LearnScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: CanvasBg(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(c).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    const BrandMark(size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lingoy',
                        style: display(21),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const ThemeToggle(),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: accountApi.signedIn
                          ? () => select(3)
                          : () => requireAccount(c),
                      child: Text(accountApi.signedIn ? 'Profil' : 'Kirish'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: List.generate(
                    pages.length,
                    (i) => !visited.contains(i)
                        ? const SizedBox.shrink()
                        : TickerMode(
                            enabled: i == index,
                            child: TabMotion(
                              active: i == index,
                              direction: direction,
                              child: pages[i],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(c).bottom > 0
          ? null
          : MotionNav(index: index, onSelect: select),
    );
  }
}

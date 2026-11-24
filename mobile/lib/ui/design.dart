import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'palette.dart';
import 'liquid_glass.dart';
export 'liquid_glass.dart';
import 'app_icons.dart';
export 'palette.dart';
export 'app_icons.dart';
import '../core/models.dart';
import '../core/illustrations.dart';
import '../core/store.dart';
import 'motion_policy.dart';
export 'motion_policy.dart';
import 'press_feedback.dart';
export 'press_feedback.dart';

const ink = Color(0xFF0B0720),
    sage = Color(0xFF9D71E8),
    gold = Color(0xFFFFC94D),
    ivory = Color(0xFFF2E9FF),
    coral = Color(0xFFFF7BAC);
final Store store = Store();
final FlutterTts tts = FlutterTts();
bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color surface(BuildContext c) => Theme.of(c).colorScheme.surface;
TextStyle display(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w700,
}) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: weight,
  height: 1.28,
  letterSpacing: -.2,
  color: color,
);
ThemeData appTheme(bool isDark) {
  final p = isDark ? LingoyPalette.night : LingoyPalette.day;
  final primary = isDark ? p.brandLight : p.brand;
  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    extensions: [p],
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.brand,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: isDark ? p.bg : Colors.white,
      secondary: p.cta,
      onSecondary: p.onCta,
      inverseSurface: p.cta,
      onInverseSurface: p.onCta,
      surfaceContainerHighest: p.elevated,
      secondaryContainer: p.elevated,
      onSecondaryContainer: p.text,
      tertiaryContainer: p.elevated,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      outline: p.border,
      error: p.error,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: p.text, fontSize: 14, height: 1.5),
      bodyLarge: TextStyle(color: p.text, fontSize: 16, height: 1.5),
      bodySmall: TextStyle(color: p.textMuted, fontSize: 11, height: 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    iconTheme: IconThemeData(color: primary, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.elevated,
      contentTextStyle: TextStyle(color: p.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
    ),
    dividerColor: p.border,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: p.border),
      showCheckmark: false,
      labelStyle: TextStyle(fontFamily: 'Manrope', fontSize: 11, color: p.text),
      selectedColor: p.elevated,
      backgroundColor: p.surface,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: LingoyPageTransitions(),
        TargetPlatform.iOS: LingoyPageTransitions(),
      },
    ),
    useMaterial3: true,
  );
}

class CanvasBg extends StatelessWidget {
  final Widget child;
  const CanvasBg({super.key, required this.child});
  @override
  Widget build(BuildContext c) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark(c) ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Theme.of(c).scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: dark(c)
          ? Brightness.light
          : Brightness.dark,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(color: palette(c).bg),
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final bool blur;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.radius = 22,
    this.blur = false,
  });
  @override
  Widget build(BuildContext c) {
    return LiquidSurface(
      radius: radius,
      padding: padding,
      tint: color,
      blur: blur,
      child: child,
    );
  }
}

class TactileButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final bool secondary;
  const TactileButton(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.secondary = false,
  });
  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool pressed = false, hovered = false;
  @override
  Widget build(BuildContext c) {
    final p = palette(c);
    final enabled = widget.onTap != null;
    final fg = widget.secondary ? p.text : p.onCta;
    final bg = widget.secondary
        ? p.surface
        : pressed
        ? p.ctaPressed
        : hovered
        ? p.ctaHover
        : p.cta;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => pressed = true) : null,
        onPointerUp: (_) => setState(() => pressed = false),
        onPointerCancel: (_) => setState(() => pressed = false),
        child: AnimatedScale(
          scale: pressed ? .955 : 1,
          duration: motionDuration(c, pressed ? 100 : 420),
          curve: pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: Semantics(
            button: true,
            enabled: enabled,
            child: AnimatedContainer(
              duration: motionDuration(c, 160),
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.secondary
                      ? p.border
                      : p.cta.withValues(alpha: .6),
                ),
                boxShadow: widget.secondary
                    ? []
                    : [
                        BoxShadow(
                          color: p.cta.withValues(alpha: pressed ? .04 : .13),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: enabled
                      ? () {
                          HapticFeedback.selectionClick();
                          widget.onTap!();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Opacity(
                    opacity: enabled ? 1 : .5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            AppIcon(widget.icon!, size: 18, color: fg),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class LevelBadge extends StatelessWidget {
  final String level;
  const LevelBadge(this.level, {super.key});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: level.isEmpty
          ? Colors.grey.withValues(alpha: .1)
          : sage.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: muted(c).withValues(alpha: .15)),
    ),
    child: Text(
      level.isEmpty ? 'CEFR —' : level,
      style: TextStyle(
        color: Theme.of(c).colorScheme.primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext c) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.25,
      color: color ?? muted(c),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Row(
      children: [
        Expanded(child: Text(title, style: display(21))),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 12,
                color: muted(c),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title, subtitle;
  final Widget? action;
  const EmptyState(
    this.title,
    this.subtitle, {
    super.key,
    this.icon = AppIcons.autoStoriesOutlined,
    this.action,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: muted(c).withValues(alpha: .1),
          ),
          child: AppIcon(icon, size: 32, color: muted(c)),
        ),
        const SizedBox(height: 20),
        Text(title, style: display(24), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted(c), fontSize: 13),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

void toast(BuildContext c, String text) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
  );
}

Future<void> pronounce(
  BuildContext c,
  String text, {
  String accent = 'en-US',
}) async {
  if (text.trim().isEmpty) return;
  try {
    await tts.stop();
    final voices = await tts.getVoices;
    final offline = (voices as List)
        .where(
          (v) =>
              v is Map &&
              v['network_required']?.toString() == '0' &&
              v['locale']?.toString().replaceAll('_', '-').toLowerCase() ==
                  accent.toLowerCase(),
        )
        .toList();
    if (offline.isEmpty) {
      if (c.mounted) {
        toast(
          c,
          '$accent uchun oflayn ovoz paketi o‘rnatilmagan. Android TTS sozlamalaridan inglizcha ovozni oldindan o‘rnating.',
        );
      }
      return;
    }
    await tts.setVoice({
      'name': offline.first['name'] as String,
      'locale': offline.first['locale'] as String,
    });
    await tts.setSpeechRate(.42);
    final result = await tts.speak(text);
    if (result != 1 && c.mounted) {
      toast(
        c,
        'Oflayn ovoz ishga tushmadi. Android TTS sozlamalarini tekshiring.',
      );
    }
  } catch (_) {
    if (c.mounted) toast(c, 'Qurilmada kerakli oflayn ovoz mavjud emas.');
  }
}

class AudioButton extends StatelessWidget {
  final String word, accent;
  const AudioButton(this.word, {super.key, this.accent = 'en-US'});
  @override
  Widget build(BuildContext c) => IconButton(
    tooltip: accent == 'en-GB' ? 'Britancha o‘qish' : 'Amerikacha o‘qish',
    onPressed: () => pronounce(c, word, accent: accent),
    style: IconButton.styleFrom(
      backgroundColor: sage.withValues(alpha: .12),
      minimumSize: const Size(48, 48),
    ),
    icon: AppIcon(AppIcons.volumeUpOutlined, color: muted(c), size: 21),
  );
}

class WordTile extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;
  const WordTile(this.word, {super.key, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final pic = pictureFor(word.lemma);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PressFeedback(
        child: Material(
          color: palette(c).surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (pic != null &&
                      MediaQuery.textScalerOf(c).scale(14) < 24) ...[
                    WordArt(pic, width: 42, height: 42, radius: 10),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.lemma,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          store.editorialMeaning(word) ??
                              pic?.meaning ??
                              (word.translation.isEmpty
                                  ? 'Inglizcha izoh va ma’nolar'
                                  : word.translation),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: muted(c)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: store.saved.contains(word.id)
                        ? 'Lug‘atdan olib tashlash'
                        : 'Lug‘atga saqlash',
                    onPressed: () async {
                      await store.toggleSave(word);
                    },
                    icon: AppIcon(
                      store.saved.contains(word.id)
                          ? AppIcons.bookmarkRounded
                          : AppIcons.bookmarkBorderRounded,
                      size: 20,
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
}

class PageFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: Navigator.of(c).canPop()
          ? IconButton(
              tooltip: 'Orqaga',
              onPressed: () => Navigator.maybePop(c),
              icon: AppIcon(AppIcons.arrowBack),
            )
          : null,
      toolbarHeight: 56 + (MediaQuery.textScalerOf(c).scale(20) - 20),
      title: Text(title, style: display(20), maxLines: 2),
      backgroundColor: palette(c).bg,
      actions: actions,
    ),
    body: CanvasBg(child: SafeArea(top: false, child: child)),
  );
}

Future<String?> askText(
  BuildContext c,
  String title, {
  String initial = '',
  String hint = '',
}) async {
  var value = initial;
  final result = await showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: display(24)),
      content: TextFormField(
        initialValue: initial,
        onChanged: (v) => value = v,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Bekor qilish'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, value.trim()),
          child: Text('Saqlash'),
        ),
      ],
    ),
  );
  return result;
}

Color muted(BuildContext c) => palette(c).textMuted;
Duration motionDuration(BuildContext c, int ms) =>
    MediaQuery.disableAnimationsOf(c)
    ? Duration.zero
    : Duration(
        milliseconds: MotionPolicy.lightOf(c)
            ? (ms * .65).round().clamp(80, 180)
            : ms,
      );

class LingoyPageTransitions extends PageTransitionsBuilder {
  const LingoyPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(.16, .025),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: animation.drive(CurveTween(curve: const Interval(0, .6))),
        child: ScaleTransition(
          scale: Tween(begin: .96, end: 1.0).animate(curved),
          alignment: Alignment.centerRight,
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }
}

class MotionIn extends StatelessWidget {
  final Widget child;
  const MotionIn({super.key, required this.child});
  @override
  Widget build(BuildContext c) => TweenAnimationBuilder<double>(
    tween: Tween(begin: MediaQuery.disableAnimationsOf(c) ? 1 : 0, end: 1),
    duration: motionDuration(c, 550),
    curve: Curves.easeOutCubic,
    builder: (c, v, child) => Transform.translate(
      offset: Offset(0, 28 * (1 - v)),
      child: Transform.scale(scale: .94 + .06 * v, child: child),
    ),
    child: RepaintBoundary(child: child),
  );
}

/// A single 48px control. The cutout moon turns into a sun without bitmaps.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});
  @override
  Widget build(BuildContext c) {
    final night = dark(c);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: night ? 1 : 0, end: night ? 1 : 0),
      duration: motionDuration(c, 620),
      curve: Curves.easeInOutCubicEmphasized,
      builder: (_, value, _) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette(c).surface,
          border: Border.all(color: palette(c).border),
        ),
        child: IconButton(
          key: ValueKey(night ? 'theme-light' : 'theme-dark'),
          tooltip: night ? 'Yorug‘ mavzu' : 'Tungi mavzu',
          onPressed: () {
            HapticFeedback.selectionClick();
            final selectedDark = store.theme == 'system'
                ? dark(c)
                : store.theme == 'dark';
            store.configure(newTheme: selectedDark ? 'light' : 'dark');
          },
          icon: CustomPaint(
            size: const Size(26, 26),
            painter: _ThemeDial(value, Theme.of(c).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _ThemeDial extends CustomPainter {
  final double night;
  final Color color;
  const _ThemeDial(this.night, this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((1 - night) * -math.pi * .5);
    final disc = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: 6 + night * 3));
    final cutout = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(17 - night * 11, -5), radius: 8),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, cutout),
      Paint()..color = color,
    );
    final ray = Paint()
      ..color = color.withValues(alpha: 1 - night)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(math.cos(a) * 9, math.sin(a) * 9),
        Offset(math.cos(a) * 12, math.sin(a) * 12),
        ray,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThemeDial old) =>
      old.night != night || old.color != color;
}

Future<void> showMotionSettings(BuildContext c) => showModalBottomSheet<void>(
  context: c,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Harakat va tezlik', style: display(22)),
          const SizedBox(height: 10),
          Text(
            'Avtomatik rejim telefon xotirasi va quvvat tejash holatiga moslashadi. Rasm tiniqligi barcha rejimlarda bir xil.',
            style: TextStyle(color: muted(context), fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final option in const {
            'auto': ('Avtomatik', 'Telefoningizga mos harakatlar'),
            'smooth': ('To‘liq animatsiya', 'Barcha sahna va o‘yin effektlari'),
            'light': ('Yengil', 'Qisqa, sodda o‘tishlar'),
          }.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(option.value.$1),
              subtitle: Text(option.value.$2),
              trailing: store.motion == option.key
                  ? AppIcon(AppIcons.checkCircleOutline)
                  : null,
              onTap: () async {
                await store.configure(newMotion: option.key);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  ),
);

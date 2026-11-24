import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// Changes to [trigger] play one feedback animation, never a looping effect.
class AnswerMotion extends StatelessWidget {
  final int trigger;
  final bool success;
  final Widget child;
  const AnswerMotion({
    super.key,
    required this.trigger,
    required this.success,
    required this.child,
  });
  @override
  Widget build(BuildContext c) =>
      trigger == 0 || MediaQuery.disableAnimationsOf(c)
      ? child
      : TweenAnimationBuilder<double>(
          key: ValueKey(trigger),
          tween: Tween(begin: 0, end: 1),
          duration: motionDuration(c, success ? 680 : 460),
          builder: (c, v, child) {
            final wave = math.sin(v * math.pi);
            final wrong = math.sin(v * math.pi * 5) * (1 - v);
            return CustomPaint(
              foregroundPainter: success && !MotionPolicy.lightOf(c)
                  ? _AnswerBurst(v, palette(c).success)
                  : null,
              child: Transform.translate(
                offset: Offset(
                  success ? 0 : wrong * 9,
                  success ? -7 * wave : 0,
                ),
                child: Transform.rotate(
                  angle: success ? -.018 * wave : wrong * .025,
                  child: Transform.scale(
                    scale: success ? 1 + wave * .055 : 1,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: RepaintBoundary(child: child),
        );
}

class _AnswerBurst extends CustomPainter {
  final double value;
  final Color color;
  const _AnswerBurst(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (value == 0 || value == 1) return;
    final p = Paint()
      ..color = color.withValues(alpha: (1 - value) * .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(value * 14),
      Radius.circular(16 + value * 8),
    );
    canvas.drawRRect(r, p);
    p.style = PaintingStyle.fill;
    for (var i = 0; i < 10; i++) {
      final x = size.width * (i / 9);
      final y = i.isEven ? 0.0 : size.height;
      final d = (i.isEven ? -1 : 1) * 22 * Curves.easeOutCubic.transform(value);
      canvas.save();
      canvas.translate(x, y + d);
      canvas.rotate(value * 3 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -4, 4, 8),
          const Radius.circular(1),
        ),
        p,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AnswerBurst old) =>
      old.value != value || old.color != color;
}

class GameFinish extends StatelessWidget {
  final int correct, total, points;
  final VoidCallback replay;
  final Widget? review;
  const GameFinish({
    super.key,
    required this.correct,
    required this.total,
    required this.points,
    required this.replay,
    this.review,
  });
  @override
  Widget build(BuildContext c) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 24),
        const _FinishArt(),
        Text(
          'Ajoyib, yakunladingiz!',
          textAlign: TextAlign.center,
          style: display(26),
        ),
        const SizedBox(height: 12),
        Text(
          '$total ta so‘z qaytarildi. $correct tasi birinchi urinishda topildi.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted(c), fontSize: 14),
        ),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: points.toDouble()),
          duration: motionDuration(c, 420),
          builder: (c, v, _) => Text('${v.round()} ball', style: display(32)),
        ),
        if (review != null) ...[const SizedBox(height: 20), review!],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: TactileButton(
            'Yana o‘ynash',
            icon: AppIcons.replay,
            onTap: replay,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.maybePop(c),
          child: const Text('Tugatish'),
        ),
      ],
    ),
  );
}

class _FinishArt extends StatefulWidget {
  const _FinishArt();
  @override
  State<_FinishArt> createState() => _FinishArtState();
}

class _FinishArtState extends State<_FinishArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this);
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      controller.value = 1;
      started = true;
    } else if (!started) {
      started = true;
      controller.duration = motionDuration(context, 1100);
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SizedBox(
    height: 180,
    width: 260,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _Celebrate(
          controller,
          palette(c).cta,
          palette(c).brandSoft,
          particles:
              MotionPolicy.lightOf(c) || MediaQuery.disableAnimationsOf(c)
              ? 0
              : 28,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: controller,
            child: Container(
              width: 114,
              height: 114,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette(c).cta,
                border: Border.all(color: palette(c).ctaHover, width: 5),
                boxShadow: MotionPolicy.lightOf(c)
                    ? []
                    : [
                        BoxShadow(
                          color: palette(c).cta.withValues(alpha: .18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: const Center(
                child: AppIcon(AppIcons.trophy, size: 54, color: ink),
              ),
            ),
            builder: (c, child) {
              final t = Curves.easeOutBack.transform(
                (controller.value / .65).clamp(0.0, 1.0),
              );
              return Transform.translate(
                offset: Offset(0, 32 * (1 - t)),
                child: Transform.rotate(
                  angle: -.3 * (1 - t),
                  child: Transform.scale(scale: .35 + .65 * t, child: child),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _Celebrate extends CustomPainter {
  final Animation<double> animation;
  final int particles;
  final Color a, b;
  _Celebrate(this.animation, this.a, this.b, {required this.particles})
    : super(repaint: animation);
  @override
  void paint(Canvas canvas, Size s) {
    final value = animation.value;
    if (value == 0 || value == 1) return;
    canvas.save();
    canvas.clipRect(Offset.zero & s);
    final paint = Paint();
    if (particles > 0) {
      paint
        ..color = a.withValues(alpha: (1 - value) * .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawOval(
        Rect.fromCenter(
          center: s.center(Offset.zero),
          width: 90 + value * 150,
          height: 80 + value * 80,
        ),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }
    for (int i = 0; i < particles; i++) {
      final angle = i * math.pi * 2 / particles;
      final d =
          28 + Curves.easeOutCubic.transform(value) * (i.isEven ? 104 : 80);
      final p = Offset(
        s.width / 2 + math.cos(angle) * d,
        s.height / 2 + math.sin(angle) * d * .52 + value * value * 12,
      );
      paint.color = (i.isEven ? a : b).withValues(alpha: 1 - value);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + value * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -5, 6, 10),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Celebrate old) =>
      old.a != a || old.b != b || old.particles != particles;
}

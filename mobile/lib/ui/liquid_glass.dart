import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'palette.dart';
import 'motion_policy.dart';

class LiquidSurface extends StatefulWidget {
  final Widget child;
  final double radius, opacity;
  final EdgeInsets padding;
  final Color? tint;
  final bool blur;
  const LiquidSurface({
    super.key,
    required this.child,
    this.radius = 26,
    this.opacity = 1,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.blur = false,
  });
  @override
  State<LiquidSurface> createState() => _LiquidSurfaceState();
}

class _LiquidSurfaceState extends State<LiquidSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController light = AnimationController(
    vsync: this,
    value: 1,
  );
  final point = ValueNotifier(Offset.zero);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      light.stop();
      light.value = 1;
    }
  }

  @override
  void dispose() {
    point.dispose();
    light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final night = Theme.of(c).brightness == Brightness.dark;
    final p = palette(c), budget = MotionPolicy.lightOf(c);
    final base = widget.tint == null
        ? p.surface
        : Color.alphaBlend(widget.tint!, p.surface);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: (night ? .79 : .86) * widget.opacity),
            base.withValues(alpha: (night ? .52 : .62) * widget.opacity),
          ],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _LiquidLight(light, point, widget.radius, night),
        child: Padding(
          padding: widget.padding,
          child: Material(type: MaterialType.transparency, child: widget.child),
        ),
      ),
    );
    if (widget.blur) {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: budget ? 4 : 14,
          sigmaY: budget ? 4 : 14,
        ),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: budget
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF16072E)
                      .withValues(alpha: night ? .12 : .035),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Listener(
          onPointerDown: (e) {
            if (MediaQuery.disableAnimationsOf(c)) return;
            point.value = e.localPosition;
            light.duration = Duration(milliseconds: budget ? 150 : 680);
            light.forward(from: 0);
          },
          child: content,
        ),
      ),
    );
  }
}

class _LiquidLight extends CustomPainter {
  final Animation<double> animation;
  final ValueNotifier<Offset> point;
  final double radius;
  final bool night;
  _LiquidLight(this.animation, this.point, this.radius, this.night)
    : super(repaint: Listenable.merge([animation, point]));
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    // One closed contour: no independent highlight with a visible endpoint.
    final outer = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(radius, s.shortestSide / 2)),
    );
    final rim = outer.deflate(.65);
    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: night ? .27 : .88),
            const Color(0xFFC4B1F5).withValues(alpha: night ? .13 : .28),
            Colors.white.withValues(alpha: night ? .15 : .70),
          ],
        ).createShader(rect),
    );
    final t = animation.value;
    if (t > 0 && t < 1) {
      final r =
          15 +
          Curves.easeOutCubic.transform(t) * math.max(s.width, s.height) * .65;
      canvas.drawRRect(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(
                alpha: math.sin(t * math.pi) * (night ? .14 : .3),
              ),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: point.value, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_LiquidLight old) =>
      old.point != point || old.radius != radius || old.night != night;
}

class AmbientLight extends CustomPainter {
  final bool night;
  const AmbientLight(this.night);
  @override
  void paint(Canvas canvas, Size s) {
    final spots = <(Offset, double, Color)>[
      (
        Offset(s.width * .95, s.height * .16),
        s.width * .9,
        Color(night ? 0xFF6A2FC8 : 0xFFD3B8F0),
      ),
      (
        Offset(-s.width * .1, s.height * .58),
        s.width * .9,
        Color(night ? 0xFF71335D : 0xFFFFDDA5),
      ),
      (
        Offset(s.width * .9, s.height * .98),
        s.width * .8,
        Color(night ? 0xFF58329B : 0xFFE6C9F1),
      ),
    ];
    for (final item in spots) {
      canvas.drawCircle(
        item.$1,
        item.$2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              item.$3.withValues(alpha: night ? .30 : .52),
              item.$3.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: item.$1, radius: item.$2)),
      );
    }
  }

  @override
  bool shouldRepaint(AmbientLight old) => old.night != night;
}

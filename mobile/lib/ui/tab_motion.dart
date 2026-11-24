import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// One clock choreographs the scene. Hidden tabs retain data and stop ticking.
class SceneClock extends InheritedWidget {
  final Animation<double> animation;
  const SceneClock({super.key, required this.animation, required super.child});
  static Animation<double>? of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<SceneClock>()?.animation;
  @override
  bool updateShouldNotify(SceneClock old) => animation != old.animation;
}

class SceneItem extends StatelessWidget {
  final Widget child;
  final double delay;
  const SceneItem({super.key, required this.child, this.delay = 0});
  @override
  Widget build(BuildContext c) {
    final clock = SceneClock.of(c);
    if (clock == null || MediaQuery.disableAnimationsOf(c)) return child;
    final light = MotionPolicy.lightOf(c);
    return AnimatedBuilder(
      animation: clock,
      child: RepaintBoundary(child: child),
      builder: (_, child) {
        final t =
            ((clock.value - (light ? 0 : delay)) / (1 - (light ? 0 : delay)))
                .clamp(0.0, 1.0);
        final move = Curves.easeOutCubic.transform(t);

        return Opacity(
          opacity: (t * 4).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (light ? 3 : 8) * (1 - move)),
            child: child,
          ),
        );
      },
    );
  }
}

class TabMotion extends StatefulWidget {
  final bool active;
  final int direction;
  final Widget child;
  const TabMotion({
    super.key,
    required this.active,
    required this.child,
    this.direction = 1,
  });
  @override
  State<TabMotion> createState() => _TabMotionState();
}

class _TabMotionState extends State<TabMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this);
  bool initialized = false;
  void reveal() {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else {
      controller.duration = motionDuration(context, 220);
      controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      controller.value = 1;
    } else if (!initialized && widget.active) {
      reveal();
    }
    initialized = true;
  }

  @override
  void didUpdateWidget(covariant TabMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) reveal();
    if (!widget.active) {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SceneClock(
    animation: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (_, child) => Transform.translate(
        key: const ValueKey('tab-entry-transform'),
        offset: Offset(
          10 *
              widget.direction *
              (1 - Curves.easeOutQuart.transform(controller.value)),
          0,
        ),
        child: Opacity(opacity: .86 + .14 * controller.value, child: child),
      ),
      child: RepaintBoundary(child: widget.child),
    ),
  );
}

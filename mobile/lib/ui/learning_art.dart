import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'tab_motion.dart';

/// A single detailed asset; the entrance stops with the page scene clock.
class LearningDeck extends StatelessWidget {
  final double width;
  const LearningDeck({super.key, this.width = 160});
  @override
  Widget build(BuildContext c) {
    final animation = SceneClock.of(c) ?? const AlwaysStoppedAnimation(1.0);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        child: Image.asset(
          'assets/art/learning_still.png',
          width: width,
          height: width * .8,
          fit: BoxFit.contain,
          cacheWidth: (width * MediaQuery.devicePixelRatioOf(c)).ceil(),
        ),
        builder: (c, child) {
          final t = MediaQuery.disableAnimationsOf(c)
              ? 1.0
              : Curves.easeOutCubic.transform(animation.value);
          return Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Transform.rotate(
              angle: -.06 * (1 - t),
              child: Opacity(opacity: t, child: child),
            ),
          );
        },
      ),
    );
  }
}

class PracticeHero extends StatelessWidget {
  final VoidCallback onTap;
  final bool game;
  const PracticeHero({super.key, required this.onTap, this.game = false});
  @override
  Widget build(BuildContext c) => LiquidSurface(
    radius: 24,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rasmni top', style: display(22)),
                  const SizedBox(height: 6),
                  Text(
                    '10 savol · ko‘ring va eslang',
                    style: TextStyle(fontSize: 12, color: muted(c)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Boshlash',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette(c).brandSoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AppIcon(AppIcons.arrowForward, size: 16),
                    ],
                  ),
                ],
              ),
            ),
            if (MediaQuery.textScalerOf(c).scale(14) < 21)
              const LearningDeck(width: 110),
          ],
        ),
      ),
    ),
  );
}

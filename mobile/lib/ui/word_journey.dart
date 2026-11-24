import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A small local illustration; no repeating animation or network images.
class WordJourney extends StatelessWidget {
  final double size;
  const WordJourney({super.key, this.size = 108});
  @override
  Widget build(BuildContext c) => ExcludeSemantics(
    child: MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.noScaling),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: motionDuration(c, 700),
        curve: Curves.easeOutCubic,
        builder: (c, t, _) => SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -.14 * t,
                child: Container(
                  width: size * .76,
                  height: size * .8,
                  decoration: BoxDecoration(
                    color: palette(c).brandSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(5 * t, -4 * t),
                child: Transform.rotate(
                  angle: .065 * t,
                  child: Container(
                    width: size * .76,
                    height: size * .8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E5B5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFFFFF).withValues(alpha: .55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B0720).withValues(alpha: .14),
                          offset: const Offset(0, 6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppIcon(
                          AppIcons.autoStoriesOutlined,
                          color: Color(0xFF6A2FC8),
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text('hello', style: display(size * .18, color: ink)),
                        Text(
                          'salom',
                          style: TextStyle(
                            color: const Color(0xFF625044),
                            fontSize: size * .11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: size * .02,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: palette(c).surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette(c).border),
                  ),
                  child: const AppIcon(
                    'assets/icons/sparkles.svg',
                    size: 16,
                    color: Color(0xFF6A2FC8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class JourneyWelcome extends StatelessWidget {
  final bool account;
  const JourneyWelcome({super.key, this.account = false});
  @override
  Widget build(BuildContext c) => LayoutBuilder(
    builder: (c, constraints) {
      final largeText = MediaQuery.textScalerOf(c).scale(14) > 20;
      return Container(
        key: ValueKey(account ? 'account-welcome' : 'home-welcome'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: dark(c) ? const Color(0xFF292235) : const Color(0xFFF0ECE4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette(c).border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account ? 'LINGOY' : 'HAR KUNI YANGI QADAM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: dark(c) ? palette(c).brandLight : palette(c).brand,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    account
                        ? 'So‘zlaringiz\nshu yerda.'
                        : 'So‘zdan\nsuhbatgacha.',
                    style: display(account ? 21 : 24),
                  ),
                  if (!account) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Toping. Saqlang. Eslab qoling.',
                      style: TextStyle(fontSize: 12, color: muted(c)),
                    ),
                  ],
                ],
              ),
            ),
            if (!largeText && constraints.maxWidth >= 270) ...[
              const SizedBox(width: 8),
              if (account)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/lingoy_icon.png',
                    width: 72,
                    height: 72,
                    cacheWidth: 216,
                  ),
                )
              else
                const WordJourney(size: 106),
            ],
          ],
        ),
      );
    },
  );
}

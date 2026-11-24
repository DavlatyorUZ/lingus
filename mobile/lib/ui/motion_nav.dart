import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'design.dart';

/// A quiet moving selection. The page keeps its own scroll and data state.
class MotionNav extends StatefulWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const MotionNav({super.key, required this.index, required this.onSelect});
  @override
  State<MotionNav> createState() => _MotionNavState();
}

class _MotionNavState extends State<MotionNav>
    with SingleTickerProviderStateMixin {
  late final lens = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 3,
    value: widget.index.toDouble(),
  );
  bool dragging = false;
  void settle(int target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      lens.value = target.toDouble();
      return;
    }
    lens.animateTo(
      target.toDouble(),
      duration: motionDuration(context, 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      lens.stop();
      lens.value = widget.index.toDouble();
    }
  }

  @override
  void didUpdateWidget(covariant MotionNav old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !dragging) settle(widget.index);
  }

  @override
  void dispose() {
    lens.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: palette(c).surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: palette(c).border.withValues(alpha: .6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (c, box) {
                final cell = (box.maxWidth - 12) / 4;
                return GestureDetector(
                  onHorizontalDragStart: (_) {
                    dragging = true;
                    lens.stop();
                  },
                  onHorizontalDragUpdate: (d) => lens.value =
                      ((d.localPosition.dx - 6) / cell - .5).clamp(0, 3),
                  onHorizontalDragCancel: () {
                    dragging = false;
                    settle(widget.index);
                  },
                  onHorizontalDragEnd: (_) {
                    final i = lens.value.round().clamp(0, 3);
                    dragging = false;
                    HapticFeedback.selectionClick();
                    widget.onSelect(i);
                    settle(i);
                  },
                  child: SizedBox(
                    height: 60,
                    child: Stack(
                      children: [
                        AnimatedBuilder(
                          animation: lens,
                          builder: (c, _) => Positioned(
                            key: const ValueKey('nav-selection'),
                            left: 6 + cell * lens.value,
                            top: 6,
                            width: cell,
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(c).colorScheme.primary
                                    .withValues(alpha: dark(c) ? .13 : .08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: List.generate(4, (i) {
                              const icons = [
                                    AppIcons.homeOutlined,
                                    AppIcons.searchRounded,
                                    AppIcons.gamepad,
                                    AppIcons.personOutlineRounded,
                                  ],
                                  names = [
                                    'Asosiy',
                                    'Lug‘at',
                                    'O‘yin',
                                    'Profil',
                                  ];
                              final active = widget.index == i;
                              return Expanded(
                                child: Semantics(
                                  label: names[i],
                                  selected: active,
                                  button: true,
                                  child: Tooltip(
                                    message: names[i],
                                    excludeFromSemantics: true,
                                    child: PressFeedback(
                                      child: InkWell(
                                        key: ValueKey('nav-$i'),
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          widget.onSelect(i);
                                        },
                                        child: SizedBox(
                                          height: 60,
                                          child: Center(
                                            child: ExcludeSemantics(
                                              child: AppIcon(
                                                icons[i],
                                                size: 24,
                                                color: active
                                                    ? Theme.of(c)
                                                          .colorScheme
                                                          .primary
                                                    : muted(c),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

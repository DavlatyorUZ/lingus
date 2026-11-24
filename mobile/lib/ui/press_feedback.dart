import 'package:material_ui/material_ui.dart';

/// Pointer feedback preserves the child's own tap, scroll and accessibility actions.
class PressFeedback extends StatefulWidget {
  final Widget child;
  const PressFeedback({super.key, required this.child});
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool pressed = false;
  void update(bool value) {
    if (mounted && pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => update(true),
      onPointerUp: (_) => update(false),
      onPointerCancel: (_) => update(false),
      child: AnimatedScale(
        scale: pressed && !reduced ? .965 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

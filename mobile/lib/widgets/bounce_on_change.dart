import 'package:flutter/material.dart';

/// Pops [child] in with a playful overshoot (0.7 → 1.0, elasticOut) every
/// time [trigger] changes value — e.g. a selection toggling on/off, or a
/// step counter advancing. Purely visual; wrap around a widget that already
/// has its own tap/selection logic.
class BounceOnChange extends StatelessWidget {
  const BounceOnChange({super.key, required this.trigger, required this.child});

  final Object trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

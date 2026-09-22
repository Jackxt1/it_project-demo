import 'package:flutter/material.dart';

/// Wraps a button [child] with a quick press-down/release scale bounce.
/// Uses [Listener] (not [GestureDetector]) so it never intercepts the tap —
/// the wrapped button's own onPressed still fires exactly as before.
class BouncyButton extends StatefulWidget {
  const BouncyButton({super.key, required this.child});

  final Widget child;

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _scale = 0.96),
      onPointerUp: (_) => setState(() => _scale = 1),
      onPointerCancel: (_) => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

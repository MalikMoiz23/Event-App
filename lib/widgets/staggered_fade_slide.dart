import 'package:flutter/material.dart';

/// Wraps [child] with a one-time fade + upward slide entrance, delayed by
/// [index] so a list of these staggers in rather than popping in at once.
class StaggeredFadeSlide extends StatelessWidget {
  const StaggeredFadeSlide({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 12) * 40);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

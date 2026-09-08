import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// Heart toggle used on cards and the detail screen.
///
/// Two variants because it has to work in two very different places: over a
/// photo it needs its own dark disc to be visible at all, whereas on a card
/// surface that disc would be a blob of chrome, so there it is a bare icon.
class FavoriteHeartButton extends StatefulWidget {
  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 20,
    this.onSurface = false,
  });

  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;

  /// `true` when sitting on a card, `false` when over an image.
  final bool onSurface;

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.quick,
    lowerBound: 0.82,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Fire first, animate second: the write is optimistic, so the heart
    // should respond on the same frame as the tap.
    widget.onToggle();
    await _controller.reverse();
    if (mounted) await _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.isFavorite;
    final Color iconColor;
    if (active) {
      iconColor = widget.onSurface ? scheme.primary : const Color(0xFFFF5A6E);
    } else {
      iconColor = widget.onSurface ? scheme.onSurfaceVariant : Colors.white;
    }

    return Semantics(
      button: true,
      selected: active,
      label: active ? 'Remove from saved' : 'Save event',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Keeps the tap target at 40px even though the icon is 18-22px.
          padding: const EdgeInsets.all(Gap.sm),
          child: DecoratedBox(
            decoration: widget.onSurface
                ? const BoxDecoration()
                : BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
            child: Padding(
              padding: EdgeInsets.all(widget.onSurface ? 0 : 6),
              child: ScaleTransition(
                scale: _controller,
                child: Icon(
                  active
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: iconColor,
                  size: widget.size,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

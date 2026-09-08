import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// A shimmering placeholder rectangle.
///
/// Skeletons rather than a centred spinner, because the list that is loading
/// has a known shape: showing that shape means the layout does not jump when
/// the data lands, and the wait reads as "nearly there" instead of "stuck".
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.height = 14,
    this.width,
    this.borderRadius = Corner.xs,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHigh;
    final highlight = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.06),
      base,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dx = -1.5 + 3.0 * _controller.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx + 1, 0),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton rows matching the real event card's geometry - 88px thumbnail on
/// the left, three lines of text on the right.
class EventListShimmer extends StatelessWidget {
  const EventListShimmer({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: Gap.listInsets,
      itemCount: itemCount,
      separatorBuilder: (_, _) => Gap.h12,
      itemBuilder: (context, index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(
                  height: 88,
                  width: 88,
                  borderRadius: Corner.md,
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(height: 15, width: 180),
                      Gap.h12,
                      const ShimmerBox(height: 11, width: 130),
                      Gap.h8,
                      const ShimmerBox(height: 11, width: 96),
                      Gap.h12,
                      Row(
                        children: [
                          const ShimmerBox(height: 11, width: 64),
                          const Spacer(),
                          const ShimmerBox(height: 11, width: 44),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for the Discover carousel, so the hero row reserves its height
/// before the first image arrives.
class FeaturedShimmer extends StatelessWidget {
  const FeaturedShimmer({super.key, this.width = 300});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: width * 10 / 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: Gap.pageInsets,
        itemCount: 2,
        separatorBuilder: (_, _) => Gap.w12,
        itemBuilder: (_, _) => ShimmerBox(
          width: width,
          height: width * 10 / 16,
          borderRadius: Corner.lg,
        ),
      ),
    );
  }
}

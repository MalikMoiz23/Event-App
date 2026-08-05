import 'package:flutter/material.dart';

/// A single shimmering placeholder rectangle, used to build skeleton loading
/// states instead of a bare spinner.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = 8,
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
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.white12 : Colors.black.withValues(alpha: 0.06);
    final highlight = dark
        ? Colors.white24
        : Colors.black.withValues(alpha: 0.12);

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

/// Skeleton list mimicking [EventCard]'s layout, shown while events load.
class EventListShimmer extends StatelessWidget {
  const EventListShimmer({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 140, width: double.infinity, borderRadius: 10),
                const SizedBox(height: 14),
                const ShimmerBox(height: 16, width: 180),
                const SizedBox(height: 10),
                const ShimmerBox(height: 12, width: 120),
                const SizedBox(height: 10),
                const ShimmerBox(height: 12, width: 90),
              ],
            ),
          ),
        );
      },
    );
  }
}

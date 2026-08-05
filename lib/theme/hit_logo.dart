import 'package:flutter/material.dart';

/// The HIT (Heavy Industries Taxila) crest, shown on the login screen and
/// app bars.
class HitLogo extends StatelessWidget {
  const HitLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

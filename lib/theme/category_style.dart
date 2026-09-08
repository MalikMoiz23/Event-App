import 'package:flutter/material.dart';

import '../models/event.dart';

/// Icon and tint per event category.
///
/// This mapping is presentation, so it lives in the theme layer rather than
/// on [EventCategory] itself - the model stays free of a Flutter import.
///
/// The tints are deliberately low-chroma. They tag a category at a glance on
/// a dense list; they are not a data palette and nothing is encoded by them
/// alone - the label is always there too.
class CategoryStyle {
  const CategoryStyle._();

  static IconData iconOf(EventCategory category) => switch (category) {
    EventCategory.family => Icons.family_restroom_rounded,
    EventCategory.kids => Icons.toys_rounded,
    EventCategory.corporate => Icons.business_center_rounded,
    EventCategory.general => Icons.celebration_rounded,
    EventCategory.vip => Icons.workspace_premium_rounded,
  };

  static Color tintOf(EventCategory category, Brightness brightness) {
    final light = brightness == Brightness.light;
    return switch (category) {
      EventCategory.family =>
        light ? const Color(0xFF1D5FBF) : const Color(0xFF7FADF5),
      EventCategory.kids =>
        light ? const Color(0xFFB4690E) : const Color(0xFFF0A33C),
      EventCategory.corporate =>
        light ? const Color(0xFF4A4C6B) : const Color(0xFFA3A6CC),
      EventCategory.general =>
        light ? const Color(0xFF0A9396) : const Color(0xFF12A79A),
      EventCategory.vip =>
        light ? const Color(0xFF7B3FA0) : const Color(0xFFC59BE0),
    };
  }
}

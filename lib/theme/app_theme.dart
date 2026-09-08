import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Assembles the light and dark [ThemeData].
///
/// Everything visual is configured here, once, so that screens contain
/// layout and no styling. Two decisions are worth calling out:
///
/// 1. The colour scheme starts from `fromSeed` for the tonal tokens but then
///    overrides the ones that matter. Left to itself the seed algorithm walks
///    HIT red towards a pink and paints the whole surface ramp with it; the
///    overrides put the crest red back and keep the surfaces a warm neutral.
///
/// 2. App bars are surface-coloured with dark text, not slabs of brand red.
///    A red bar on every screen leaves nowhere for a primary button to stand
///    out, and it is the single thing that most makes an app look templated.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(_scheme(Brightness.light));

  static ThemeData dark() => _build(_scheme(Brightness.dark));

  static ColorScheme _scheme(Brightness brightness) {
    // `fidelity` keeps the generated tones closer to the seed than the
    // default `tonalSpot`, which matters when the seed is a specific crest
    // colour rather than an arbitrary accent.
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.hitRed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    if (brightness == Brightness.light) {
      return base.copyWith(
        primary: AppColors.hitRed,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFFFE0E3),
        onPrimaryContainer: AppColors.hitRedDark,
        secondary: AppColors.ink,
        onSecondary: Colors.white,
        tertiary: AppColors.teal,
        onTertiary: Colors.white,
        error: AppColors.danger,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.inkMuted,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: AppColors.canvas,
        surfaceContainer: AppColors.surfaceAlt,
        surfaceContainerHigh: AppColors.surfaceAltHigh,
        surfaceContainerHighest: const Color(0xFFE6E1E0),
        outline: AppColors.border,
        outlineVariant: AppColors.hairline,
      );
    }

    return base.copyWith(
      primary: AppColors.hitRedBright,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF5C0715),
      onPrimaryContainer: const Color(0xFFFFD5DA),
      secondary: AppColors.darkInk,
      onSecondary: AppColors.darkCanvas,
      tertiary: AppColors.tealBright,
      onTertiary: const Color(0xFF00201D),
      error: AppColors.dangerDark,
      onError: const Color(0xFF3A0906),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      onSurfaceVariant: AppColors.darkInkMuted,
      surfaceContainerLowest: AppColors.darkCanvas,
      surfaceContainerLow: AppColors.darkSurface,
      surfaceContainer: AppColors.darkSurfaceAlt,
      surfaceContainerHigh: AppColors.darkSurfaceAltHigh,
      surfaceContainerHighest: const Color(0xFF302A2B),
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkHairline,
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final text = AppTypography.apply(base.textTheme);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surfaceContainerLow,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // A hairline only once content has scrolled under the bar, so a
        // stationary screen has no chrome at all.
        scrolledUnderElevation: 0.5,
        shadowColor: scheme.shadow.withValues(alpha: 0.25),
        centerTitle: false,
        titleSpacing: Gap.page,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),

      // Filled is the default action style: it carries the brand colour
      // without the drop shadow that dates an elevated button.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: Corner.mdAll),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.10),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: Corner.mdAll),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: const RoundedRectangleBorder(borderRadius: Corner.mdAll),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          highlightColor: scheme.primary.withValues(alpha: 0.08),
        ),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // Cards are separated by a hairline border rather than a shadow. On
        // a warm off-white canvas a shadow turns muddy, and in dark mode it
        // is invisible - a border works in both.
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corner.lgAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? scheme.surface : scheme.surfaceContainer,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        border: _fieldBorder(scheme.outlineVariant),
        enabledBorder: _fieldBorder(scheme.outlineVariant),
        focusedBorder: _fieldBorder(scheme.primary, width: 1.6),
        errorBorder: _fieldBorder(scheme.error),
        focusedErrorBorder: _fieldBorder(scheme.error, width: 1.6),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.12 : 0.22),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: Corner.pillAll,
        ),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.06),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isLight ? scheme.surface : scheme.surfaceContainer,
        selectedColor: scheme.primary.withValues(alpha: isLight ? 0.12 : 0.24),
        checkmarkColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: Corner.pillAll),
        showCheckmark: false,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Corner.smAll),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
        shape: const RoundedRectangleBorder(borderRadius: Corner.mdAll),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: Corner.sheet),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        clipBehavior: Clip.antiAlias,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: Corner.lgAll),
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        insetPadding: const EdgeInsets.all(Gap.lg),
        shape: const RoundedRectangleBorder(borderRadius: Corner.smAll),
        elevation: 3,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Corner.smAll),
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outlineVariant,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: Corner.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: Corner.smAll),
        textStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
      ),

      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        textStyle: text.labelSmall?.copyWith(letterSpacing: 0),
      ),

      // The stock page transition on Android is a vertical slide that fights
      // the horizontal push used everywhere else in the app.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: Corner.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

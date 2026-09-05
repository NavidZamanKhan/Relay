import 'package:flutter/material.dart';

import 'relay_colors.dart';

abstract final class RelayTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? RelayColors.night : RelayColors.porcelain;
    final surface = isDark ? RelayColors.nightRaised : RelayColors.paper;
    final foreground = isDark ? RelayColors.moon : RelayColors.ink;
    final muted = isDark ? RelayColors.moonMuted : RelayColors.inkSoft;
    final line = isDark ? RelayColors.nightLine : RelayColors.line;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: RelayColors.coral,
      onPrimary: RelayColors.ink,
      secondary: RelayColors.coral,
      onSecondary: RelayColors.ink,
      error: const Color(0xFFE94B4B),
      onError: Colors.white,
      surface: surface,
      onSurface: foreground,
    );

    const baseRadius = BorderRadius.all(Radius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: line,
      splashFactory: InkRipple.splashFactory,
      textTheme: _textTheme(foreground, muted),
      iconTheme: IconThemeData(color: foreground, size: 22),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? RelayColors.nightSoft : RelayColors.paperRaised,
        hintStyle: TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        border: const OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: line.withValues(alpha: .72)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: RelayColors.coral, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: foreground,
        contentTextStyle: TextStyle(
          color: background,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static TextTheme _textTheme(Color foreground, Color muted) {
    TextStyle base(double size, FontWeight weight, {double spacing = 0}) =>
        TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: const ['Roboto', 'sans-serif'],
          fontSize: size,
          fontWeight: weight,
          height: 1.18,
          letterSpacing: spacing,
          color: foreground,
        );

    return TextTheme(
      displayLarge: base(40, FontWeight.w700, spacing: -1.4),
      displayMedium: base(32, FontWeight.w700, spacing: -1),
      headlineLarge: base(28, FontWeight.w700, spacing: -.7),
      headlineMedium: base(24, FontWeight.w700, spacing: -.5),
      titleLarge: base(19, FontWeight.w700, spacing: -.25),
      titleMedium: base(16, FontWeight.w600, spacing: -.1),
      bodyLarge: base(16, FontWeight.w400),
      bodyMedium: base(14, FontWeight.w400),
      bodySmall: base(12, FontWeight.w500).copyWith(color: muted),
      labelLarge: base(14, FontWeight.w700, spacing: .05),
      labelMedium: base(12, FontWeight.w600, spacing: .05),
      labelSmall: base(10, FontWeight.w700, spacing: .3),
    );
  }
}

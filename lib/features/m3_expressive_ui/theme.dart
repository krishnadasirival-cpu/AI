import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpressiveTheme {
  static const Color primarySeed = Color(0xFF6750A4);
  static const Color accentCyan = Color(0xFF00E5FF);

  static ThemeData darkTheme([ColorScheme? dynamicScheme]) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.dark,
        );

    final baseTextTheme = Typography.material2021().white;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFF121316),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1B1F),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2B2930), width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  /// High-contrast focus border decoration for Android TV D-Pad focus rings.
  static BoxDecoration tvFocusDecoration({required bool isFocused, required ColorScheme colors}) {
    if (!isFocused) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.3)),
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accentCyan, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: accentCyan.withOpacity(0.35),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ],
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'theme_provider.dart';

class AppTheme {
  AppTheme._();

  /// Aktif temaya göre uygun başlık (Heading) TextStyle üretir:
  /// - Edebi Günlük: Cormorant Garamond
  /// - Kadim Mistik: Cinzel
  /// - Safir Minimal: Playfair Display / Plus Jakarta Sans
  static TextStyle headingStyle({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    Color? color,
    double? height,
  }) {
    final mode = AppColors.currentThemeMode;
    final effectiveColor = color ?? AppColors.moonlight;
    switch (mode) {
      case OneiroThemeMode.editorialJournal:
        return GoogleFonts.cormorantGaramond(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing ?? 1.0,
          color: effectiveColor,
          height: height,
        );
      case OneiroThemeMode.ancientMystic:
        return GoogleFonts.cinzel(
          fontSize: (fontSize * 0.88).clamp(11.0, 32.0),
          fontWeight: fontWeight,
          letterSpacing: letterSpacing ?? 1.4,
          color: effectiveColor,
          height: height,
        );
      case OneiroThemeMode.minimalistChic:
        return GoogleFonts.plusJakartaSans(
          fontSize: (fontSize * 0.88).clamp(11.0, 32.0),
          fontWeight: FontWeight.w700,
          letterSpacing: letterSpacing ?? 0.6,
          color: effectiveColor,
          height: height,
        );
    }
  }

  static ThemeData get darkTheme => getTheme(AppColors.currentThemeMode);

  static ThemeData getTheme(OneiroThemeMode mode) {
    AppColors.setThemeMode(mode);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.charcoalBlack,
      primaryColor: AppColors.moonlight,
      colorScheme: ColorScheme.dark(
        primary: AppColors.moonlight,
        secondary: AppColors.warmSand,
        surface: AppColors.charcoalBlack,
        surfaceContainerHighest: AppColors.charcoalSurface,
        onPrimary: AppColors.charcoalBlack,
        onSecondary: AppColors.charcoalBlack,
        onSurface: AppColors.textPrimary,
        outline: AppColors.borderSubtle,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.charcoalBlack,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: headingStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.moonlight,
        ),
        iconTheme: IconThemeData(color: AppColors.moonlight),
      ),
      textTheme: TextTheme(
        displayLarge: headingStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.moonlight,
          letterSpacing: 1.2,
        ),
        displayMedium: headingStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 1.0,
        ),
        titleLarge: headingStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.moonlight,
          letterSpacing: 0.8,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
          height: 1.8,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
          height: 1.7,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textDim,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.charcoalBlack,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.charcoalSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.charcoalInput,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textDim,
          fontSize: 14.5,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderMoonlight, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 32,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.charcoalElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.charcoalElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
    );
  }
}

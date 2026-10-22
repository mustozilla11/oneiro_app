import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.charcoalBlack,
      primaryColor: AppColors.moonlight,
      colorScheme: const ColorScheme.dark(
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
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.moonlight,
        ),
        iconTheme: const IconThemeData(color: AppColors.moonlight),
      ),
      textTheme: TextTheme(
        // Başlıklar için edebi Cormorant Garamond fontu
        displayLarge: GoogleFonts.cormorantGaramond(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.moonlight,
          letterSpacing: 1.2,
        ),
        displayMedium: GoogleFonts.cormorantGaramond(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 1.0,
        ),
        titleLarge: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.moonlight,
          letterSpacing: 0.8,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        // Gövde metinleri ve okuma için modern, ferah Plus Jakarta Sans
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
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
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
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderMoonlight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
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
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.charcoalElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
    );
  }
}

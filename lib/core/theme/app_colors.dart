import 'package:flutter/material.dart';

/// Oneiro mistik renk paleti
class AppColors {
  // Temel Arka Plan (OLED Black)
  static const Color oledBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF0A0814);
  static const Color surfaceCard = Color(0xFF120E24);
  static const Color surfaceCardElevated = Color(0xFF1A1433);
  static const Color surfaceInput = Color(0xFF0E0B1A);

  // Vurgular & Işıltılar (Neon Mor & Lila)
  static const Color neonPurple = Color(0xFF9D4EDD);
  static const Color deepViolet = Color(0xFF7B2CBF);
  static const Color lightLilac = Color(0xFFC77DFF);
  static const Color electricLavender = Color(0xFFE0AAFF);

  // Kadim Mistik Vurgular (Altın & Kehribar)
  static const Color ancientGold = Color(0xFFFFD166);
  static const Color mysticalAmber = Color(0xFFFFB703);
  static const Color antiqueBronze = Color(0xFFD4A373);

  // Metin & Tipografi Renkleri
  static const Color textPureWhite = Color(0xFFFFFFFF);
  static const Color textSilver = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);

  // Kenarlık & Çizgiler
  static const Color borderSubtle = Color(0xFF261D45);
  static const Color borderGlow = Color(0xFF5A2A94);
  static const Color borderGold = Color(0x66FFD166);

  // Gradyanlar
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9D4EDD),
      Color(0xFF7B2CBF),
      Color(0xFF5A189A),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFD166),
      Color(0xFFFFB703),
    ],
  );

  static const LinearGradient mysticalSurfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF16102D),
      Color(0xFF0A0814),
      Color(0xFF000000),
    ],
  );

  static const LinearGradient glowCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF181333),
      Color(0xFF0F0B21),
    ],
  );
}

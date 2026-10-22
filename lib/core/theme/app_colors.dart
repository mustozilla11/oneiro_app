import 'package:flutter/material.dart';

/// Oneiro - Minimalist Edebi Rüya Günlüğü (Editorial Journal) Renk Paleti
class AppColors {
  AppColors._();

  // 1. Zemin ve Yüzeyler (Derin Kömür Siyahı)
  static const Color charcoalBlack = Color(0xFF0A0A0C); // Ana derin kömür zemin
  static const Color charcoalSurface = Color(0xFF111216); // Kart ve yüzey zemini
  static const Color charcoalElevated = Color(0xFF16181E); // Yükseltilmiş kart
  static const Color charcoalInput = Color(0xFF0F1014); // Girdi alanı zemini

  // 2. Vurgular (Mat Ay Işığı / Sıcak Kum ve Sis Grisi)
  static const Color moonlight = Color(0xFFE6DEC8); // Mat ay ışığı / kum tonu
  static const Color warmSand = Color(0xFFF4E8C1); // Soluk parşömen kum
  static const Color mistGrey = Color(0xFF9EA3AE); // Soluk sis grisi
  static const Color dimMist = Color(0xFF6B7280); // Çok soluk kılavuz grisi

  // 3. Tipografi ve Metin Renkleri
  static const Color textPrimary = Color(0xFFF5F3EF); // Edebi kemik beyazı
  static const Color textSecondary = Color(0xFFD6D1C7); // Yumuşak kağıt okuma metni
  static const Color textMuted = Color(0xFF9EA3AE); // Sis grisi ikincil metin
  static const Color textDim = Color(0xFF6B7280); // Pasif meta veriler

  // 4. İnce Çizgi ve Ayırıcılar (Sadece Colors.white.withValues(alpha: 0.06))
  static const Color borderSubtle = Color(0x0FFFFFFF); // 0.06 beyaz çizgi
  static const Color borderLight = Color(0x1AFFFFFF); // 0.10 hafif çizgi
  static const Color borderMoonlight = Color(0x33E6DEC8); // %20 ay ışığı bordürü

  // 5. Geriye Dönük Uyumluluk (Tüm neon/mor/cyan tonları mat ay ışığı ve kömüre dönüştürüldü)
  static const Color oledBlack = charcoalBlack;
  static const Color surfaceDark = charcoalBlack;
  static const Color surfaceCard = charcoalSurface;
  static const Color surfaceCardElevated = charcoalElevated;
  static const Color surfaceInput = charcoalInput;

  static const Color ancientGold = moonlight;
  static const Color mysticalAmber = warmSand;
  static const Color antiqueBronze = moonlight;

  static const Color neonPurple = moonlight;
  static const Color deepViolet = charcoalElevated;
  static const Color lightLilac = moonlight;
  static const Color electricLavender = warmSand;

  static const Color mediterraneanAzure = mistGrey;
  static const Color mediterraneanSky = moonlight;
  static const Color mediterraneanDeep = charcoalElevated;

  static const Color subconsciousIndigo = mistGrey;
  static const Color subconsciousViolet = moonlight;
  static const Color subconsciousDark = charcoalElevated;

  static const Color islamicGold = moonlight;
  static const Color islamicAmber = warmSand;

  static const Color textPureWhite = textPrimary;
  static const Color textSilver = textSecondary;
  static const Color textCreamWhite = textPrimary;
  static const Color textWarmMuted = textMuted;

  static const Color borderGlow = borderSubtle;
  static const Color borderGold = borderMoonlight;

  static const Color amazonDarkSlate = charcoalBlack;
  static const Color amazonBoxFill = charcoalSurface;
  static const Color amazonBoxFocused = charcoalElevated;
  static const Color amazonAmber = moonlight;
  static const Color amazonAmberLight = warmSand;
  static const Color amazonAmberGlow = Color(0x1AE6DEC8);
  static const Color dawnIndigo = charcoalElevated;
  static const Color dawnViolet = charcoalSurface;

  // Minimalist, Mat Edebi Gradyanlar (Parlak neon içermez)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6DEC8),
      Color(0xFFD8CFB5),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6DEC8),
      Color(0xFFF4E8C1),
    ],
  );

  static const LinearGradient mysticalSurfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF111216),
      Color(0xFF0A0A0C),
    ],
  );

  static const LinearGradient glowCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF131418),
      Color(0xFF0F1014),
    ],
  );

  static const LinearGradient antigravityBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33E6DEC8),
      Color(0x0FFFFFFF),
      Color(0x0FFFFFFF),
      Color(0x33E6DEC8),
    ],
  );

  static const LinearGradient amazonButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6DEC8),
      Color(0xFFDDD4BD),
    ],
  );
}

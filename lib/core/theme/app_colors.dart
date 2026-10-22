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

  // Kadim Ekoller Özel Renk Paleti
  // 1. Antik Akdeniz Bilgeliği (Deniz & Gökyüzü Mavisi)
  static const Color mediterraneanAzure = Color(0xFF0284C7);
  static const Color mediterraneanSky = Color(0xFF38BDF8);
  static const Color mediterraneanDeep = Color(0xFF0C4A6E);

  // 2. Derinlik Psikolojisi (Bilinçaltı Koyu İndigo / Gece Moru)
  static const Color subconsciousIndigo = Color(0xFF6366F1);
  static const Color subconsciousViolet = Color(0xFF4F46E5);
  static const Color subconsciousDark = Color(0xFF1E1B4B);

  // 3. Doğu & İslam Geleneği (Kadim Altın & Sıcak Kehribar)
  static const Color islamicGold = Color(0xFFFFD166);
  static const Color islamicAmber = Color(0xFFFF9900);

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

  // --- Amazon & Sabah Konforu Paleti (Morning-Comfort Antigravity) ---
  // Gözü yormayan derin kömür zemin (saf zifiri siyah veya beyaz değil)
  static const Color amazonDarkSlate = Color(0xFF0D1117);
  // Kutunun içi: Zeminden ayrışan, derin mat gece safiri
  static const Color amazonBoxFill = Color(0xFF151C28);
  // Odaklandığında kutu içi
  static const Color amazonBoxFocused = Color(0xFF1A2332);
  // Amazon sıcak kehribarı (gözü yakmayan sıcak vurgu)
  static const Color amazonAmber = Color(0xFFFF9900);
  static const Color amazonAmberLight = Color(0xFFFFB84D);
  static const Color amazonAmberGlow = Color(0x33FF9900);
  // Şafak indigosu & lavanta (border geçişi için)
  static const Color dawnIndigo = Color(0xFF4F46E5);
  static const Color dawnViolet = Color(0xFF7C3AED);
  // Sabah gözünü yormayan yumuşak ipeksi krem metinler
  static const Color textCreamWhite = Color(0xFFECEFF4);
  static const Color textWarmMuted = Color(0xFF8C96A5);

  // Değişen / Akan Kutu Kenarlık Gradyanı (Antigravity Floating Border)
  static const LinearGradient antigravityBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF9900), // Amazon Kehribar
      Color(0xFFFFB84D), // Sıcak Altın
      Color(0xFF818CF8), // İpeksi İndigo
      Color(0xFF4F46E5), // Gece Mavisi
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  // Amazon Sıcak Kehribar Buton Gradyanı
  static const LinearGradient amazonButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF9900),
      Color(0xFFFF8500),
      Color(0xFFE67300),
    ],
  );
}

import 'package:flutter/material.dart';
import 'theme_provider.dart';

/// Oneiro Çoklu Tema & Ekol Renk Sistemi
/// 1. Edebi Günlük (Gemini Editorial Journal)
/// 2. Kadim Mistik (Orijinal Astral Gece & Mor-Altın)
/// 3. Safir Minimal (Antigravity Gece Safiri & Gümüş Zen)
class AppColors {
  AppColors._();

  static OneiroThemeMode _currentMode = OneiroThemeMode.editorialJournal;
  static OneiroThemeMode get currentThemeMode => _currentMode;

  static void setThemeMode(OneiroThemeMode mode) {
    _currentMode = mode;
  }

  // ===========================================================================
  // EKOL (GELENEK) ÖZEL RENKLERİ (Doğu & İslam: Altın, Akdeniz: Mavi, Psikoloji: Mor)
  // ===========================================================================
  static const Color islamGold = Color(0xFFE5A93C);
  static const Color islamAmber = Color(0xFFF59E0B);

  static const Color mediterraneanBlue = Color(0xFF38BDF8);
  static const Color mediterraneanDeepBlue = Color(0xFF0EA5E9);

  static const Color psychologyPurple = Color(0xFFA855F7);
  static const Color psychologyDeepPurple = Color(0xFF9D4EDD);

  /// Seçilen ekole (traditionId) göre ana vurgu rengini döndürür
  static Color traditionColor(String? traditionId) {
    final id = (traditionId ?? '').toLowerCase();
    if (id.contains('akdeniz') || id.contains('artemidorus')) {
      return mediterraneanBlue;
    }
    if (id.contains('psikoloji') || id.contains('jung') || id.contains('bilinç')) {
      return psychologyPurple;
    }
    if (id.contains('islam') || id.contains('doğu') || id.contains('dogu') || id.contains('sirin')) {
      return islamGold;
    }
    return moonlight;
  }

  /// Seçilen ekole göre ikincil (daha derin) vurgu rengini döndürür
  static Color traditionSecondaryColor(String? traditionId) {
    final id = (traditionId ?? '').toLowerCase();
    if (id.contains('akdeniz') || id.contains('artemidorus')) {
      return mediterraneanDeepBlue;
    }
    if (id.contains('psikoloji') || id.contains('jung') || id.contains('bilinç')) {
      return psychologyDeepPurple;
    }
    return islamAmber;
  }

  /// Seçilen ekole göre sayfa arka planına yayılan hafif ambiyans gradyanı
  static LinearGradient traditionAmbientGradient(String? traditionId) {
    final primary = traditionColor(traditionId);
    final bg = charcoalBlack;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.38, 1.0],
      colors: [
        Color.alphaBlend(primary.withValues(alpha: 0.16), bg),
        Color.alphaBlend(primary.withValues(alpha: 0.05), bg),
        bg,
      ],
    );
  }

  // ===========================================================================
  // 1. ZEMİN VE YÜZEYLER (Aktif Temaya Göre Dinamik)
  // ===========================================================================
  static Color get charcoalBlack {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFF0A0A0C); // Derin kömür siyahı
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFF090612); // Obsidyen astral gece moru
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF070B12); // Saf gece safiri / arduvaz
    }
  }

  static Color get charcoalSurface {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFF111216);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFF140E24);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF0E1522);
    }
  }

  static Color get charcoalElevated {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFF16181E);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFF1E1535);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF151F30);
    }
  }

  static Color get charcoalInput {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFF0F1014);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFF110C1F);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF0B111C);
    }
  }

  // ===========================================================================
  // 2. VURGULAR (Aktif Temaya Göre Dinamik, Okunaklı ve Belirgin)
  // ===========================================================================
  static Color get moonlight {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFFE5A93C); // Tok, belirgin kehribar-altın sarısı
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFFEDB545); // Parlak kadim altın
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF7DD3FC); // Kuzey safir buz mavisi
    }
  }

  static Color get warmSand {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFFE8B85C); // Sıcak bal-altın sarısı
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFFC77DFF); // Astral lavanta-mor ışıltı
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFFE5C17B); // Şampanya altın tonu
    }
  }

  static Color get mistGrey {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFF9EA3AE);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFFB8AED2);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF94A3B8);
    }
  }

  static Color get dimMist {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFF6B7280);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFF7E729B);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF64748B);
    }
  }

  // ===========================================================================
  // 3. TİPOGRAFİ VE METİN RENKLERİ
  // ===========================================================================
  static Color get textPrimary {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFFF5F3EF);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFFFDFBF7);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFFF8FAFC);
    }
  }

  static Color get textSecondary {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFFD6D1C7);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFFE2DCF0);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFFCBD5E1);
    }
  }

  static Color get textMuted => mistGrey;
  static Color get textDim => dimMist;

  // ===========================================================================
  // 4. ÇİZGİ VE AYIRICILAR
  // ===========================================================================
  static Color get borderSubtle {
    switch (_currentMode) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0x14FFFFFF); // İnce beyaz çizgi
      case OneiroThemeMode.ancientMystic:
        return const Color(0x2E9D4EDD); // Mistik mor ışıltılı sınır
      case OneiroThemeMode.minimalistChic:
        return const Color(0x1F7DD3FC); // İnce kristal safir sınır
    }
  }

  static Color get borderLight => const Color(0x22FFFFFF);

  static Color get borderMoonlight => moonlight.withValues(alpha: 0.35);

  // ===========================================================================
  // 5. GERİYE DÖNÜK UYUMLULUK & EKOL ALIAS'LARI
  // ===========================================================================
  static Color get oledBlack => charcoalBlack;
  static Color get surfaceDark => charcoalBlack;
  static Color get surfaceCard => charcoalSurface;
  static Color get surfaceCardElevated => charcoalElevated;
  static Color get surfaceInput => charcoalInput;

  static Color get ancientGold =>
      _currentMode == OneiroThemeMode.minimalistChic ? const Color(0xFFE5A93C) : moonlight;
  static Color get mysticalAmber => warmSand;
  static Color get antiqueBronze => moonlight;

  static Color get neonPurple =>
      _currentMode == OneiroThemeMode.ancientMystic ? const Color(0xFF9D4EDD) : psychologyPurple;
  static Color get deepViolet => charcoalElevated;
  static Color get lightLilac => psychologyPurple;
  static Color get electricLavender =>
      _currentMode == OneiroThemeMode.ancientMystic ? const Color(0xFFC77DFF) : warmSand;

  static Color get mediterraneanAzure => mediterraneanDeepBlue;
  static Color get mediterraneanSky => mediterraneanBlue;
  static Color get mediterraneanDeep => charcoalElevated;

  static Color get subconsciousIndigo => psychologyDeepPurple;
  static Color get subconsciousViolet => psychologyPurple;
  static Color get subconsciousDark => charcoalElevated;

  static Color get islamicGold => islamGold;
  static Color get islamicAmber => islamAmber;

  static Color get textPureWhite => textPrimary;
  static Color get textSilver => textSecondary;
  static Color get textCreamWhite => textPrimary;
  static Color get textWarmMuted => textMuted;

  static Color get borderGlow => borderSubtle;
  static Color get borderGold => borderMoonlight;

  static Color get amazonDarkSlate => charcoalBlack;
  static Color get amazonBoxFill => charcoalSurface;
  static Color get amazonBoxFocused => charcoalElevated;
  static Color get amazonAmber => moonlight;
  static Color get amazonAmberLight => warmSand;
  static Color get amazonAmberGlow => moonlight.withValues(alpha: 0.12);
  static Color get dawnIndigo => charcoalElevated;
  static Color get dawnViolet => charcoalSurface;

  // Dinamik Gradyanlar
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          moonlight,
          warmSand,
        ],
      );

  static LinearGradient get goldGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE5A93C),
          Color(0xFFE8B85C),
        ],
      );

  static LinearGradient get mysticalSurfaceGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          charcoalSurface,
          charcoalBlack,
        ],
      );

  static LinearGradient get glowCardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          charcoalElevated,
          charcoalSurface,
        ],
      );

  static LinearGradient get antigravityBorderGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          moonlight.withValues(alpha: 0.25),
          borderSubtle,
          borderSubtle,
          moonlight.withValues(alpha: 0.25),
        ],
      );

  static LinearGradient get amazonButtonGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          moonlight,
          warmSand,
        ],
      );
}

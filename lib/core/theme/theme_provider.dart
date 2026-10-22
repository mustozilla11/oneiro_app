import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

/// Uygulamadaki 3 Ana Tema Seçeneği:
/// 1. editorialJournal: Gemini'nin önerdiği "Edebi Günlük" (Kömür siyahı, kehribar altın, edebi serif)
/// 2. ancientMystic: Eski orijinal "Kadim Mistik" (Obsidyen gece moru, neon eflatun & altın ışıltı, Cinzel)
/// 3. minimalistChic: Antigravity'nin özel "Safir Minimal" teması (Gece safiri, buz gümüşü & şampanya, modern şık)
enum OneiroThemeMode {
  editorialJournal,
  ancientMystic,
  minimalistChic;

  String get id => name;

  String get title {
    switch (this) {
      case OneiroThemeMode.editorialJournal:
        return 'Edebi Günlük';
      case OneiroThemeMode.ancientMystic:
        return 'Kadim Mistik';
      case OneiroThemeMode.minimalistChic:
        return 'Safir Minimal';
    }
  }

  String get subtitle {
    switch (this) {
      case OneiroThemeMode.editorialJournal:
        return 'Kömür siyahı & kehribar defter';
      case OneiroThemeMode.ancientMystic:
        return 'Astral mor & altın mabed';
      case OneiroThemeMode.minimalistChic:
        return 'Gece safiri & gümüş zen';
    }
  }

  IconData get icon {
    switch (this) {
      case OneiroThemeMode.editorialJournal:
        return Icons.menu_book_rounded;
      case OneiroThemeMode.ancientMystic:
        return Icons.auto_awesome_rounded;
      case OneiroThemeMode.minimalistChic:
        return Icons.nights_stay_outlined;
    }
  }

  Color get previewPrimaryColor {
    switch (this) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFFE5A93C);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFF9D4EDD);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF7DD3FC);
    }
  }

  Color get previewBgColor {
    switch (this) {
      case OneiroThemeMode.editorialJournal:
        return const Color(0xFF0A0A0C);
      case OneiroThemeMode.ancientMystic:
        return const Color(0xFF0D0818);
      case OneiroThemeMode.minimalistChic:
        return const Color(0xFF070B12);
    }
  }

  static OneiroThemeMode fromId(String? id) {
    for (final mode in OneiroThemeMode.values) {
      if (mode.name == id) return mode;
    }
    return OneiroThemeMode.editorialJournal;
  }
}

class ThemeNotifier extends StateNotifier<OneiroThemeMode> {
  static const String _prefThemeKey = 'oneiro_selected_theme_mode_v1';

  ThemeNotifier(super.initialMode);

  static Future<OneiroThemeMode> loadInitialTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefThemeKey);
      final mode = OneiroThemeMode.fromId(saved);
      AppColors.setThemeMode(mode);
      return mode;
    } catch (_) {
      return OneiroThemeMode.editorialJournal;
    }
  }

  Future<void> setTheme(OneiroThemeMode mode) async {
    AppColors.setThemeMode(mode);
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeKey, mode.id);
    } catch (_) {}
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, OneiroThemeMode>((ref) {
  return ThemeNotifier(AppColors.currentThemeMode);
});

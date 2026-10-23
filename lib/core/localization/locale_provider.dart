import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class LocaleNotifier extends StateNotifier<String> {
  static const String _prefLanguageKey = 'dreamapp_selected_language_code_v1';

  LocaleNotifier(super.initialLocale);

  static Future<String> loadInitialLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefLanguageKey);
      if (savedCode != null && _isSupported(savedCode)) {
        return savedCode;
      }

      // Cihazın sistem dilini otomatik algıla
      final deviceCode = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      if (_isSupported(deviceCode)) {
        return deviceCode;
      }
    } catch (_) {}
    return 'tr'; // Varsayılan: Türkçe
  }

  static bool _isSupported(String code) {
    return AppStrings.supportedLanguages.any((lang) => lang['code'] == code);
  }

  Future<void> setLanguage(String code) async {
    if (!_isSupported(code)) return;
    state = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLanguageKey, code);
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier('tr');
});

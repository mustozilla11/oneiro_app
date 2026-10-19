import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user_subscription_state.dart';

class UserSubscriptionNotifier extends StateNotifier<UserSubscriptionState> {
  UserSubscriptionNotifier() : super(const UserSubscriptionState()) {
    _loadFromPrefs();
  }

  static const _keyIsPremium = 'oneiro_is_premium';
  static const _keyCredits = 'oneiro_dream_credits';
  static const _keyDailyUsed = 'oneiro_daily_used';
  static const _keyLastDate = 'oneiro_last_date';

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool(_keyIsPremium) ?? false;
      final credits = prefs.getInt(_keyCredits) ?? 3;
      final dailyUsed = prefs.getInt(_keyDailyUsed) ?? 0;
      final lastDate = prefs.getString(_keyLastDate) ?? '';

      state = UserSubscriptionState(
        isPremium: isPremium,
        dreamCredits: credits,
        dailyFreeDreamsUsed: dailyUsed,
        lastFreeDreamDate: lastDate,
      );
    } catch (e) {
      debugPrint('[UserSubscriptionNotifier] Prefs yükleme hatası: $e');
    }
  }

  Future<void> setPremium(bool isPrem) async {
    state = state.copyWith(isPremium: isPrem);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, isPrem);
    } catch (_) {}
  }

  Future<void> addCredits(int count) async {
    final updated = state.dreamCredits + count;
    state = state.copyWith(dreamCredits: updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCredits, updated);
    } catch (_) {}
  }

  /// Rüya yorumlama hakkı tüketildiğinde çağrılır
  Future<bool> consumeDreamAttempt() async {
    if (state.isPremium) return true;

    final today = _getTodayString();

    // Eğer bugün henüz ücretsiz hakkını kullanmadıysa, ücretsiz hakkı tüket
    if (state.lastFreeDreamDate != today || state.dailyFreeDreamsUsed < 1) {
      state = state.copyWith(
        dailyFreeDreamsUsed: 1,
        lastFreeDreamDate: today,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyDailyUsed, 1);
        await prefs.setString(_keyLastDate, today);
      } catch (_) {}
      return true;
    }

    // Ücretsiz hak bitmişse jetondan düş
    if (state.dreamCredits > 0) {
      final updated = state.dreamCredits - 1;
      state = state.copyWith(dreamCredits: updated);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyCredits, updated);
      } catch (_) {}
      return true;
    }

    return false;
  }

  /// Kilitli geleneği jetonla açmak için
  Future<bool> useCreditForTradition() async {
    if (state.isPremium) return true;
    if (state.dreamCredits > 0) {
      final updated = state.dreamCredits - 1;
      state = state.copyWith(dreamCredits: updated);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyCredits, updated);
      } catch (_) {}
      return true;
    }
    return false;
  }

  String _getTodayString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}

final userSubscriptionProvider =
    StateNotifierProvider<UserSubscriptionNotifier, UserSubscriptionState>((ref) {
  return UserSubscriptionNotifier();
});

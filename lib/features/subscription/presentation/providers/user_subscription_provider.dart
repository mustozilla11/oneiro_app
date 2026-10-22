import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/subscription_service.dart';
import '../../domain/models/user_subscription_state.dart';

class UserSubscriptionNotifier extends StateNotifier<UserSubscriptionState> {
  StreamSubscription? _firestoreSub;

  UserSubscriptionNotifier() : super(const UserSubscriptionState()) {
    _loadFromPrefs();
    _initRevenueCatHooks();
    _listenAuthAndFirestore();
  }

  static const _keyIsPremium = 'oneiro_is_premium';
  static const _keyCredits = 'oneiro_dream_credits';
  static const _keyDailyUsed = 'oneiro_daily_used';
  static const _keyLastDate = 'oneiro_last_date';

  void _initRevenueCatHooks() {
    SubscriptionService.instance.onPremiumStatusChanged = (isPrem) {
      setPremium(isPrem);
    };
    SubscriptionService.instance.onCreditsPurchased = (count) {
      addCredits(count);
    };
  }

  void _listenAuthAndFirestore() {
    AuthService.instance.authStateChanges.listen((user) {
      _firestoreSub?.cancel();
      if (user != null && !user.isGuest) {
        _firestoreSub = FirestoreService.instance.streamUserData(user.uid).listen((data) {
          if (data != null) {
            syncWithFirestore(data);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }

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

  Future<void> syncWithFirestore(Map<String, dynamic> data) async {
    final isPrem = data['isPremium'] as bool? ?? state.isPremium;
    final credits = data['dreamCredits'] as int? ?? state.dreamCredits;
    final lastDate = data['dailyFreeDreamDate'] as String? ?? state.lastFreeDreamDate;

    state = state.copyWith(
      isPremium: isPrem,
      dreamCredits: credits,
      lastFreeDreamDate: lastDate,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, isPrem);
      await prefs.setInt(_keyCredits, credits);
      await prefs.setString(_keyLastDate, lastDate);
    } catch (_) {}
  }

  Future<void> setPremium(bool isPrem) async {
    state = state.copyWith(isPremium: isPrem);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, isPrem);

      final user = AuthService.instance.currentUser;
      if (user != null) {
        unawaited(FirestoreService.instance.updatePremiumStatus(user.uid, isPrem));
      }
    } catch (_) {}
  }

  Future<void> addCredits(int count) async {
    final updated = state.dreamCredits + count;
    state = state.copyWith(dreamCredits: updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCredits, updated);

      final user = AuthService.instance.currentUser;
      if (user != null) {
        unawaited(FirestoreService.instance.incrementCredits(user.uid, count));
      }
    } catch (_) {}
  }

  /// Rüya yorumlama hakkı tüketildiğinde çağrılır (Önce yerel hafızaya yazar, asla bloklamaz)
  Future<bool> consumeDreamAttempt() async {
    if (state.isPremium) return true;

    final today = _getTodayString();
    final user = AuthService.instance.currentUser;

    if (user != null) {
      unawaited(FirestoreService.instance.deductCreditOrUseDaily(user.uid));
    }

    // 1. Eğer bugün henüz ücretsiz hakkını kullanmadıysa, ücretsiz hakkı tüket
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

    // 2. Ücretsiz hak bitmişse jetondan düş
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

        final user = AuthService.instance.currentUser;
        if (user != null) {
          unawaited(FirestoreService.instance.incrementCredits(user.uid, -1));
        }
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

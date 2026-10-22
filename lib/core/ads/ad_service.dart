import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  RewardedAd? _rewardedAd;
  Completer<RewardedAd?>? _loadCompleter;
  bool _isInitialized = false;

  // Google Test Ad Unit IDs (Rewarded Video)
  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android Test Rewarded ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Rewarded ID
    }
    return '';
  }

  /// AdMob SDK'sını başlatır ve arka planda ilk ödüllü reklamı önceden yükler (Preload)
  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[AdService] Platform Google Mobile Ads desteklemiyor, simülasyon moduna geçildi.');
      _isInitialized = true;
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] MobileAds başarıyla başlatıldı.');
      preloadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] Başlatma hatası: $e');
    }
  }

  /// Ödüllü reklamı arka planda hazır bekletir (Race-condition korumalı)
  Future<RewardedAd?> preloadRewardedAd() async {
    if (!_isInitialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;
    if (_rewardedAd != null) return _rewardedAd;
    if (_loadCompleter != null) return _loadCompleter!.future;

    final completer = Completer<RewardedAd?>();
    _loadCompleter = completer;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Ödüllü video reklam yüklendi ve hazır bekliyor.');
          _rewardedAd = ad;
          _loadCompleter = null;
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[AdService] Ödüllü reklam yükleme başarısız: $error');
          _rewardedAd = null;
          _loadCompleter = null;
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    return completer.future;
  }

  /// Ödüllü Video Reklamı gösterir.
  /// İlk tıkta hemen açılması için var olan veya yüklenmekte olan reklamı bekler.
  Future<void> showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailed,
    Duration maxTimeout = const Duration(seconds: 8),
  }) async {
    bool hasRewarded = false;

    void grantRewardOnce() {
      if (!hasRewarded) {
        hasRewarded = true;
        onUserEarnedReward();
      }
    }

    // Platform desteği yoksa (Desktop/Web/Simülasyon)
    if (!_isInitialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[AdService] Simülasyon: Reklam simüle ediliyor, 1.5s sonra kilit açılıyor.');
      await Future.delayed(const Duration(milliseconds: 1500));
      grantRewardOnce();
      onAdClosed?.call();
      return;
    }

    RewardedAd? adToShow = _rewardedAd;

    // Hazırda reklam yoksa ama şu an yükleniyorsa o yüklemeyi bekle
    if (adToShow == null) {
      debugPrint('[AdService] Hazır reklam yok, yükleme tamamlanması bekleniyor...');
      try {
        adToShow = await preloadRewardedAd().timeout(maxTimeout, onTimeout: () {
          debugPrint('[AdService] Reklam yükleme zaman aşımına uğradı, kullanıcı mağdur olmasın diye kilit açılıyor.');
          return null;
        });
      } catch (e) {
        debugPrint('[AdService] Reklam bekleme istisnası: $e');
        adToShow = null;
      }
    }

    if (adToShow == null) {
      // Reklam ağı arızasında veya zaman aşımında kullanıcıyı bekletme, ödülü ver
      debugPrint('[AdService] Reklam temin edilemedi; otomatik kilit açılıyor.');
      grantRewardOnce();
      onAdClosed?.call();
      return;
    }

    // Reklam bulundu, göster
    _rewardedAd = null; // Kullanıldı

    adToShow.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[AdService] Ödüllü video tam ekranda başladı.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] Ödüllü video kapatıldı.');
        ad.dispose();
        preloadRewardedAd(); // Bir sonraki tıklama için arka planda hemen yenisini hazırla
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Ödüllü video gösterim hatası: $error');
        ad.dispose();
        grantRewardOnce(); // Hata olduysa kullanıcıyı mağdur etme
        preloadRewardedAd();
        onAdClosed?.call();
      },
    );

    try {
      await adToShow.show(onUserEarnedReward: (ad, reward) {
        debugPrint('[AdService] Kullanıcı ödüllü videoyu tamamladı: ${reward.amount} ${reward.type}');
        grantRewardOnce();
      });
    } catch (e) {
      debugPrint('[AdService] ad.show istisnası: $e');
      grantRewardOnce();
      onAdClosed?.call();
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}

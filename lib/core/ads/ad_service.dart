import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
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

  /// Ödüllü reklamı arka planda hazır bekletir
  void preloadRewardedAd() {
    if (!_isInitialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (_rewardedAd != null || _isRewardedAdLoading) return;

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Ödüllü video reklam önceden yüklendi ve hazır.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[AdService] Ödüllü reklam önyükleme başarısız: $error');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
        },
      ),
    );
  }

  /// Ödüllü Video Reklamı (Rewarded Ad) gösterir.
  /// Kullanıcı videoyu tamamladığında `onUserEarnedReward` tetiklenir.
  /// Reklam yüklenemezse veya maxTimeout (örneğin 10 saniye) aşılırsa fallback devreye girer
  /// ve kullanıcının rüya tabiri kilidi açılmaya devam eder.
  Future<void> showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailed,
    Duration maxTimeout = const Duration(seconds: 10),
  }) async {
    bool hasRewarded = false;

    void grantRewardOnce() {
      if (!hasRewarded) {
        hasRewarded = true;
        onUserEarnedReward();
      }
    }

    // Platform desteği yoksa (Desktop/Web/Emülatör internetsiz) simülasyon yap
    if (!_isInitialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[AdService] Simülasyon: 2 saniye sonra ödül veriliyor.');
      await Future.delayed(const Duration(milliseconds: 2000));
      grantRewardOnce();
      onAdClosed?.call();
      return;
    }

    // Eğer hazırda yüklü reklam varsa doğrudan göster
    if (_rewardedAd != null) {
      final ad = _rewardedAd!;
      _rewardedAd = null; // Tüketildi

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('[AdService] Ödüllü video tam ekranda başladı.');
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('[AdService] Ödüllü video kapatıldı.');
          ad.dispose();
          preloadRewardedAd(); // Bir sonraki için yenisini hazırla
          onAdClosed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('[AdService] Ödüllü video gösterim hatası: $error');
          ad.dispose();
          grantRewardOnce(); // Kullanıcı mağdur olmasın
          preloadRewardedAd();
          onAdClosed?.call();
        },
      );

      await ad.show(onUserEarnedReward: (ad, reward) {
        debugPrint('[AdService] Kullanıcı ödüllü videoyu tamamladı: ${reward.amount} ${reward.type}');
        grantRewardOnce();
      });
      return;
    }

    // Hazırda reklam yoksa anlık yüklemeyi dene, timeout ile emniyete al
    Timer? timeoutTimer = Timer(maxTimeout, () {
      debugPrint('[AdService] Reklam yükleme zaman aşımına uğradı ($maxTimeout). Fallback ile kilit açılıyor.');
      grantRewardOnce();
      onAdClosed?.call();
    });

    try {
      _isRewardedAdLoading = true;
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            timeoutTimer.cancel();
            _isRewardedAdLoading = false;

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                preloadRewardedAd();
                onAdClosed?.call();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                grantRewardOnce();
                preloadRewardedAd();
                onAdClosed?.call();
              },
            );

            ad.show(onUserEarnedReward: (ad, reward) {
              debugPrint('[AdService] Ödül kazanıldı.');
              grantRewardOnce();
            });
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('[AdService] Anlık reklam yüklenemedi: $error');
            timeoutTimer.cancel();
            _isRewardedAdLoading = false;
            grantRewardOnce(); // Reklam ağı arızasında kullanıcıyı bekletme, ödülü ver
            onAdClosed?.call();
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdService] Reklam çalıştırma istisnası: $e');
      timeoutTimer.cancel();
      _isRewardedAdLoading = false;
      grantRewardOnce();
      onAdClosed?.call();
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}

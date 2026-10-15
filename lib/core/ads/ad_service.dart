import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;
  bool _isInitialized = false;

  // Test Ad Unit IDs
  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Google Android Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Google iOS Test ID
    }
    return '';
  }

  /// AdMob SDK'sını başlatır
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
    } catch (e) {
      debugPrint('[AdService] Başlatma hatası: $e');
    }
  }

  /// Interstitial reklam gösterimi.
  /// Reklam yüklenemezse veya maxTimeout (örneğin 15 saniye) aşılırsa fallback devreye girer
  /// ve kullanıcı asla kilitli kalmaz.
  Future<void> showInterstitialWithFallback({
    required VoidCallback onCompleted,
    Duration maxTimeout = const Duration(seconds: 15),
  }) async {
    bool hasCompleted = false;

    void completeOnce() {
      if (!hasCompleted) {
        hasCompleted = true;
        onCompleted();
      }
    }

    // Platform desteklemiyorsa veya simülasyondaysa direkt tamamla
    if (!_isInitialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[AdService] Simülasyon: 2.5 saniye mistik bekleme sonrası sonuç ekranına geçiliyor.');
      await Future.delayed(const Duration(milliseconds: 2500));
      completeOnce();
      return;
    }

    // 15 saniyelik zaman aşımı emniyet sübabı (Fallback)
    Timer? timeoutTimer = Timer(maxTimeout, () {
      debugPrint('[AdService] Reklam yükleme zaman aşımına uğradı ($maxTimeout). Fallback devreye giriyor.');
      completeOnce();
    });

    try {
      _isAdLoading = true;
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isAdLoading = false;

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                debugPrint('[AdService] Reklam tam ekranda gösteriliyor.');
              },
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('[AdService] Reklam kullanıcı tarafından kapatıldı.');
                ad.dispose();
                timeoutTimer.cancel();
                completeOnce();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('[AdService] Reklam gösterim hatası: $error');
                ad.dispose();
                timeoutTimer.cancel();
                completeOnce();
              },
            );

            // Reklamı göster
            ad.show();
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('[AdService] Reklam yüklenemedi: $error');
            _isAdLoading = false;
            timeoutTimer.cancel();
            completeOnce();
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdService] Reklam yükleme istisnası: $e');
      _isAdLoading = false;
      timeoutTimer.cancel();
      completeOnce();
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'firestore_service.dart';

class PurchaseResult {
  final bool success;
  final String message;
  final bool isConfigured;

  const PurchaseResult({
    required this.success,
    required this.message,
    this.isConfigured = true,
  });
}

class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService instance = SubscriptionService._internal();

  // Test / Canlı RevenueCat Anahtarları (RevenueCat Dashboard -> Project Settings -> API Keys)
  static const String _revenueCatApiKeyApple = "appl_oneiro_live_key_placeholder";
  static const String _revenueCatApiKeyGoogle = "goog_oneiro_live_key_placeholder";

  static const String entitlementPremium = "premium";
  static const String identifierMonthly = "\$rc_monthly";
  static const String identifierCredits10 = "credits_10";

  bool _isConfigured = false;
  String? _currentUserId;
  bool _isPremiumUser = false;

  // UI ve State için dinleyici geri çağırımı (Riverpod senkronizasyonu)
  Function(bool isPremium)? onPremiumStatusChanged;
  Function(int creditsAdded)? onCreditsPurchased;

  bool get isConfigured => _isConfigured;
  bool get isPremiumUser => _isPremiumUser;

  /// RevenueCat SDK'sını başlatır ve kullanıcı UID'si ile eşleştirir
  Future<void> initialize({String? uid}) async {
    _currentUserId = uid;

    try {
      final apiKey = (!kIsWeb && Platform.isIOS)
          ? _revenueCatApiKeyApple
          : _revenueCatApiKeyGoogle;

      if (apiKey.contains("placeholder")) {
        debugPrint('[SubscriptionService] RevenueCat API anahtarı henüz tanımlanmamış (placeholder). Gerçek mağaza ödemeleri için geçerli anahtar bekleniyor.');
        _isConfigured = false;
        return;
      }

      final configuration = PurchasesConfiguration(apiKey);
      if (uid != null && uid.isNotEmpty) {
        configuration.appUserID = uid;
      }

      await Purchases.configure(configuration);
      _isConfigured = true;
      debugPrint('[SubscriptionService] RevenueCat başarıyla başlatıldı. UID: $uid');

      // Satın alım ve abonelik durumu dinleyicisi
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _handleCustomerInfoUpdate(customerInfo);
      });

      // İlk durumu kontrol et
      final customerInfo = await Purchases.getCustomerInfo();
      _handleCustomerInfoUpdate(customerInfo);
    } catch (e) {
      debugPrint('[SubscriptionService] RevenueCat başlatma hatası: $e');
      _isConfigured = false;
    }
  }

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    try {
      final isPremium = customerInfo.entitlements.all[entitlementPremium]?.isActive ?? false;
      _isPremiumUser = isPremium;
      debugPrint('[SubscriptionService] Müşteri bilgisi güncellendi. Aktif Premium: $isPremium');

      if (onPremiumStatusChanged != null) {
        onPremiumStatusChanged!(isPremium);
      }

      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        FirestoreService.instance.updatePremiumStatus(_currentUserId!, isPremium);
      }
    } catch (e) {
      debugPrint('[SubscriptionService] CustomerInfo ayrıştırma hatası: $e');
    }
  }

  /// Kullanıcı giriş yaptığında RevenueCat hesabıyla eşleştirir
  Future<void> logIn(String uid) async {
    _currentUserId = uid;
    if (!_isConfigured) return;

    try {
      final logInResult = await Purchases.logIn(uid);
      _handleCustomerInfoUpdate(logInResult.customerInfo);
      debugPrint('[SubscriptionService] RevenueCat kullanıcısı $uid olarak bağlandı.');
    } catch (e) {
      debugPrint('[SubscriptionService] Purchases.logIn hatası: $e');
    }
  }

  /// Kullanıcı çıkış yaptığında RevenueCat anonim oturumuna döner
  Future<void> logOut() async {
    _currentUserId = null;
    _isPremiumUser = false;
    if (!_isConfigured) return;

    try {
      final customerInfo = await Purchases.logOut();
      _handleCustomerInfoUpdate(customerInfo);
      debugPrint('[SubscriptionService] RevenueCat anonim moda döndü.');
    } catch (e) {
      debugPrint('[SubscriptionService] Purchases.logOut hatası: $e');
    }
  }

  /// Aylık Premium Abonelik Satın Alma Akışı (Google Play / App Store)
  Future<PurchaseResult> purchaseMonthlySubscription() async {
    if (!_isConfigured) {
      debugPrint('[SubscriptionService] RevenueCat henüz canlı anahtarla yapılandırılmamış.');
      return const PurchaseResult(
        success: false,
        isConfigured: false,
        message: 'Google Play ödeme penceresini açmak için RevenueCat Public API anahtarı (goog_...) gereklidir.',
      );
    }

    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering != null && currentOffering.monthly != null) {
        final customerInfo = await Purchases.purchasePackage(currentOffering.monthly!);
        final isPremium = customerInfo.entitlements.all[entitlementPremium]?.isActive ?? false;
        _handleCustomerInfoUpdate(customerInfo);
        return PurchaseResult(
          success: isPremium,
          message: isPremium ? 'Kadim Gezgin Plus aboneliği başarıyla başlatıldı!' : 'Satın alma tamamlanamadı.',
        );
      } else {
        return const PurchaseResult(
          success: false,
          message: 'Aylık abonelik paketi Google Play / RevenueCat konsolunda henüz aktif edilmemiş.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[SubscriptionService] Satın alma iptali veya hatası: ${e.code} - ${e.message}');
      if (e.code == '1' || e.message?.contains('cancelled') == true) {
        return const PurchaseResult(success: false, message: 'Ödeme işlemi iptal edildi.');
      }
      return PurchaseResult(success: false, message: 'Ödeme hatası: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('[SubscriptionService] Satın alma sırasında beklenmeyen hata: $e');
      return PurchaseResult(success: false, message: 'Ödeme tamamlanamadı: $e');
    }
  }

  /// Tek Seferlik 10 Rüya Jetonu Paketi Satın Alma Akışı
  Future<PurchaseResult> purchaseCreditPack() async {
    if (!_isConfigured) {
      return const PurchaseResult(
        success: false,
        isConfigured: false,
        message: 'Google Play ödeme penceresini açmak için RevenueCat Public API anahtarı (goog_...) gereklidir.',
      );
    }

    try {
      final offerings = await Purchases.getOfferings();
      Package? creditPackage;

      if (offerings.current != null) {
        for (final pkg in offerings.current!.availablePackages) {
          if (pkg.identifier == identifierCredits10 || pkg.identifier.contains('credits')) {
            creditPackage = pkg;
            break;
          }
        }
      }

      if (creditPackage != null) {
        await Purchases.purchasePackage(creditPackage);
        if (_currentUserId != null) {
          await FirestoreService.instance.incrementCredits(_currentUserId!, 10);
        }
        if (onCreditsPurchased != null) {
          onCreditsPurchased!(10);
        }
        return const PurchaseResult(
          success: true,
          message: '10 Rüya Jetonu hesabınıza tanımlandı!',
        );
      } else {
        return const PurchaseResult(
          success: false,
          message: 'Jeton paketi mağaza konsolunda henüz aktif edilmemiş.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[SubscriptionService] Jeton satın alma hatası: ${e.code} - ${e.message}');
      if (e.code == '1' || e.message?.contains('cancelled') == true) {
        return const PurchaseResult(success: false, message: 'Ödeme işlemi iptal edildi.');
      }
      return PurchaseResult(success: false, message: 'Ödeme hatası: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('[SubscriptionService] Kredi paketi satın alma hatası: $e');
      return PurchaseResult(success: false, message: 'Ödeme tamamlanamadı: $e');
    }
  }

  /// Satın Alımları Geri Yükle (Apple Guideline 3.1.1 Zorunluluğu)
  Future<PurchaseResult> restorePurchases() async {
    if (!_isConfigured) {
      return const PurchaseResult(
        success: true,
        message: 'Satın alımlarınız geri yüklendi.',
        isConfigured: false,
      );
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremium = customerInfo.entitlements.all[entitlementPremium]?.isActive ?? false;
      _isPremiumUser = isPremium;

      if (onPremiumStatusChanged != null) {
        onPremiumStatusChanged!(isPremium);
      }

      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        await FirestoreService.instance.updatePremiumStatus(_currentUserId!, isPremium);
      }

      return PurchaseResult(
        success: true,
        message: isPremium
            ? 'Plus aboneliğiniz başarıyla geri yüklendi!'
            : 'Aktif bir abonelik bulunamadı veya geri yüklendi.',
      );
    } catch (e) {
      debugPrint('[SubscriptionService] restorePurchases hatası: $e');
      return PurchaseResult(
        success: false,
        message: 'Geri yükleme işlemi tamamlanamadı: $e',
      );
    }
  }
}

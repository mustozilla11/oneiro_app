import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'firestore_service.dart';

class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService instance = SubscriptionService._internal();

  // Test / Canlı RevenueCat Anahtarları (Proje yayına alınırken konsoldan güncellenir)
  static const String _revenueCatApiKeyApple = "appl_oneiro_live_key_placeholder";
  static const String _revenueCatApiKeyGoogle = "goog_oneiro_live_key_placeholder";

  static const String entitlementPremium = "premium";
  static const String identifierMonthly = "\$rc_monthly";
  static const String identifierCredits10 = "credits_10";

  bool _isConfigured = false;
  String? _currentUserId;

  // UI ve State için dinleyici geri çağırımı (Riverpod senkronizasyonu)
  Function(bool isPremium)? onPremiumStatusChanged;
  Function(int creditsAdded)? onCreditsPurchased;

  bool get isConfigured => _isConfigured;

  /// RevenueCat SDK'sını başlatır ve kullanıcı UID'si ile eşleştirir
  Future<void> initialize({String? uid}) async {
    _currentUserId = uid;

    try {
      final apiKey = (!kIsWeb && Platform.isIOS)
          ? _revenueCatApiKeyApple
          : _revenueCatApiKeyGoogle;

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
      debugPrint('[SubscriptionService] RevenueCat yapılandırma notu (Test/Geliştirme modu devrede): $e');
      _isConfigured = false;
    }
  }

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    try {
      final isPremium = customerInfo.entitlements.all[entitlementPremium]?.isActive ?? false;
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
    if (!_isConfigured) {
      debugPrint('[SubscriptionService] Simüle edilmiş RevenueCat girişi: $uid');
      return;
    }

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
    if (!_isConfigured) return;

    try {
      final customerInfo = await Purchases.logOut();
      _handleCustomerInfoUpdate(customerInfo);
      debugPrint('[SubscriptionService] RevenueCat anonim moda döndü.');
    } catch (e) {
      debugPrint('[SubscriptionService] Purchases.logOut hatası: $e');
    }
  }

  /// Aylık Premium Abonelik Satın Alma Akışı (39,99 TL / ay)
  Future<bool> purchaseMonthlySubscription() async {
    if (!_isConfigured) {
      debugPrint('[SubscriptionService] RevenueCat offline/mock modunda: Simüle edilmiş Premium tanımlandı.');
      if (_currentUserId != null) {
        await FirestoreService.instance.updatePremiumStatus(_currentUserId!, true);
      }
      if (onPremiumStatusChanged != null) {
        onPremiumStatusChanged!(true);
      }
      return true;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering != null && currentOffering.monthly != null) {
        final customerInfo = await Purchases.purchasePackage(currentOffering.monthly!);
        final isPremium = customerInfo.entitlements.all[entitlementPremium]?.isActive ?? false;
        _handleCustomerInfoUpdate(customerInfo);
        return isPremium;
      } else {
        debugPrint('[SubscriptionService] Aktif aylık paket bulunamadı, simülasyon onaylanıyor.');
        if (_currentUserId != null) {
          await FirestoreService.instance.updatePremiumStatus(_currentUserId!, true);
        }
        if (onPremiumStatusChanged != null) {
          onPremiumStatusChanged!(true);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Satın alma işlemi sırasında hata: $e');
      // Kullanıcı iptali değilse simülasyona düşebilir
      return false;
    }
  }

  /// Tek Seferlik 10 Rüya Jetonu Paketi Satın Alma Akışı (19,99 TL)
  Future<bool> purchaseCreditPack() async {
    if (!_isConfigured) {
      debugPrint('[SubscriptionService] RevenueCat offline/mock modunda: 10 Jeton simüle edilerek eklendi.');
      if (_currentUserId != null) {
        await FirestoreService.instance.incrementCredits(_currentUserId!, 10);
      }
      if (onCreditsPurchased != null) {
        onCreditsPurchased!(10);
      }
      return true;
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
        return true;
      } else {
        debugPrint('[SubscriptionService] Kredi paketi mağazada bulunamadı, simülasyon kredisi aktarılıyor.');
        if (_currentUserId != null) {
          await FirestoreService.instance.incrementCredits(_currentUserId!, 10);
        }
        if (onCreditsPurchased != null) {
          onCreditsPurchased!(10);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Kredi paketi satın alma hatası: $e');
      return false;
    }
  }
}

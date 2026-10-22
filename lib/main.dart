import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ads/ad_service.dart';
import 'core/theme/theme.dart';
import 'features/auth/presentation/screens/onboarding_auth_screen.dart';
import 'features/home/presentation/screens/main_pager_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tam OLED Black için sistem çubukları ve durum çubuğu şeffaflığı
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 1. Firebase Başlatma (Defansif: google-services.json yoksa çökmez, simülasyon modu devrede kalır)
  try {
    await Firebase.initializeApp();
    debugPrint('[Firebase] Başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('[Firebase] Yapılandırma dosyası bekleniyor (Geliştirme/Çevrimdışı Mod): $e');
  }

  // 2. AuthService Başlatma (Kayıtlı oturumu veya Google sessiz girişini yükle)
  await AuthService.instance.initialize();

  // 3. RevenueCat Satın Alma ve Abonelik Servisini Başlat
  try {
    final currentUid = AuthService.instance.currentUser?.uid;
    await SubscriptionService.instance.initialize(uid: currentUid);
  } catch (e) {
    debugPrint('[RevenueCat] Başlatma uyarısı: $e');
  }

  // 4. AdMob Reklam Servisini Başlat
  try {
    await AdService.instance.initialize();
  } catch (e) {
    debugPrint('[AdService] Başlatma uyarısı: $e');
  }

  // 5. Yerel Sabah Rüya Hatırlatıcı Bildirimlerini Başlat & Sırala
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[NotificationService] Başlatma uyarısı: $e');
  }

  runApp(
    const ProviderScope(
      child: OneiroApp(),
    ),
  );
}

class OneiroApp extends StatelessWidget {
  const OneiroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oneiro / Rüya Tabiri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Oturum durumunu dinleyen AuthGate
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OneiroUser?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.instance.currentUser;

        // Giriş yapmış veya daha önce uygulamaya girmiş kullanıcı -> Doğrudan Ana Sayfaya
        if (user != null || AuthService.instance.hasOnboarded) {
          return const MainPagerScreen();
        }

        // Yalnızca ilk kez açan kullanıcı -> Onboarding & Giriş Ekranı
        return const OnboardingAuthScreen();
      },
    );
  }
}

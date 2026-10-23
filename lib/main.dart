import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ads/ad_service.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/theme_selection_screen.dart';
import 'features/auth/presentation/screens/onboarding_auth_screen.dart';
import 'features/home/presentation/screens/main_pager_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sistem çubukları ve durum çubuğu şeffaflığı
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 0. Kayıtlı Temayı ve 10 Dilli Dil Ayarını Yükle
  await ThemeNotifier.loadInitialTheme();
  final initialLang = await LocaleNotifier.loadInitialLocale();

  // 1. Firebase Başlatma
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 4));
    debugPrint('[Firebase] Başarıyla başlatıldı.');
  } catch (e) {
    debugPrint('[Firebase] Yapılandırma dosyası bekleniyor (Geliştirme/Çevrimdışı Mod): $e');
  }

  // 2. AuthService Başlatma (Kayıtlı oturumu anında yükle)
  await AuthService.instance.initialize();

  // 3. RevenueCat Satın Alma ve Abonelik Servisini Başlat
  try {
    final currentUid = AuthService.instance.currentUser?.uid;
    await SubscriptionService.instance.initialize(uid: currentUid).timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[RevenueCat] Başlatma uyarısı: $e');
  }

  // 4. AdMob Reklam Servisini Başlat
  try {
    await AdService.instance.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[AdService] Başlatma uyarısı: $e');
  }

  // 5. Yerel Sabah Rüya Hatırlatıcı Bildirimlerini Başlat & Sırala
  try {
    await NotificationService.instance.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[NotificationService] Başlatma uyarısı: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleNotifier(initialLang)),
      ],
      child: const OneiroApp(),
    ),
  );
}

class OneiroApp extends ConsumerWidget {
  const OneiroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeProvider);
    ref.watch(localeProvider);

    return MaterialApp(
      title: 'DreamApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(currentThemeMode),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  Widget build(BuildContext context) {
    // Tema değişikliğini tüm alt ekranlara anında yansıt
    ref.watch(themeProvider);

    // Başlangıçta tam sayfa tema seçim ekranını göster ("koca bir sayfa tema sorsun")
    if (!ThemeNotifier.hasConfirmedInitialTheme) {
      return ThemeSelectionScreen(
        isInitialStartup: true,
        onCompleted: () {
          if (mounted) setState(() {});
        },
      );
    }

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

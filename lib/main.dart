import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ads/ad_service.dart';
import 'core/theme/theme.dart';
import 'features/auth/presentation/screens/onboarding_auth_screen.dart';

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

  // Reklam servisini arka planda başlat
  await AdService.instance.initialize();

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
      // İlk açılışta şık Google & Apple giriş ekranı karşılar, ardından ana sayfaya geçer
      home: const OnboardingAuthScreen(),
    );
  }
}

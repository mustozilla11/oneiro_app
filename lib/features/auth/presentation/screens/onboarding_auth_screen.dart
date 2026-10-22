import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../home/presentation/screens/main_pager_screen.dart';

class OnboardingAuthScreen extends StatefulWidget {
  const OnboardingAuthScreen({super.key});

  @override
  State<OnboardingAuthScreen> createState() => _OnboardingAuthScreenState();
}

class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {
  bool _isLoading = false;

  void _navigateToHome() {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, secondaryAnimation) => const MainPagerScreen(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;

      if (user == null) {
        // Kullanıcı Google penceresini kapattı veya iptal etti
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google ile giriş iptal edildi.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
            backgroundColor: AppColors.surfaceCardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // Ana sayfaya geçme, oturum açma ekranında kal!
      }

      final name = user.displayName ?? user.email ?? 'Gezgin';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hoş geldiniz $name. Astral portal açılıyor...',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
          ),
          backgroundColor: AppColors.surfaceCardElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.ancientGold),
          ),
        ),
      );
      _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      debugPrint('[OnboardingAuthScreen] Google Giriş Hatası: $errorStr');

      // Android Debug Modunda SHA-1 parmak izi veya Google Play Services hatası (ApiException 10, 12500 vb.)
      final isAndroidDebugIssue = errorStr.contains('10') ||
          errorStr.contains('DEVELOPER_ERROR') ||
          errorStr.contains('sign_in_failed') ||
          errorStr.contains('12500');

      if (isAndroidDebugIssue && !kIsWeb && Platform.isAndroid) {
        _showAndroidDebugSetupDialog(errorStr);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google ile bağlanırken bir sorun oluştu: $e',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
            backgroundColor: AppColors.surfaceCardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAndroidDebugSetupDialog(String errorDetails) {
    const sha1Fingerprint = '3C:E7:E8:DA:EB:B6:EF:87:59:4B:09:46:E1:0C:D0:B7:29:B4:5A:93';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.ancientGold, width: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.ancientGold, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Google Giriş (Android Debug)',
                style: GoogleFonts.cinzel(
                  color: AppColors.textPureWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Google Play Services, Android Studio debug modunda çalışırken projenin SHA-1 parmak izini Firebase veya Google Cloud Konsolu\'nda doğrulamak ister (ApiException 10).\n\nBu imza konsolda kayıtlı değilse Google açılır pencereyi güvenlik gereği engeller.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSilver,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.oledBlack,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.ancientGold.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paket Adı:',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SelectableText(
                      'com.oneiro.oneiro_app',
                      style: TextStyle(
                        color: AppColors.ancientGold,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Debug SHA-1 Parmak İzi:',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const SelectableText(
                      sha1Fingerprint,
                      style: TextStyle(
                        color: AppColors.textPureWhite,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ancientGold,
                        side: const BorderSide(color: AppColors.ancientGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: sha1Fingerprint));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SHA-1 parmak izi panoya kopyalandı!'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('SHA-1 Kopyala', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Konsol ayarını yapana kadar uygulamadaki rüya yorumlama ve mistik akışları hemen test etmek isterseniz geliştirici moduyla tek tıkla devam edebilirsiniz:',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Kapat',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ancientGold,
              foregroundColor: AppColors.oledBlack,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final devUser = await AuthService.instance.signInWithDevAccount();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Geliştirici moduyla giriş yapıldı (${devUser.displayName}).',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
                  ),
                  backgroundColor: AppColors.surfaceCardElevated,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _navigateToHome();
            },
            child: Text(
              'Geliştirici Olarak Giriş Yap',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAppleSignIn() async {
    HapticFeedback.mediumImpact();

    // Android cihaz kontrolü
    if (!kIsWeb && Platform.isAndroid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCardElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.ancientGold, width: 1),
          ),
          title: Row(
            children: [
              const Icon(Icons.apple, color: AppColors.ancientGold, size: 24),
              const SizedBox(width: 8),
              Text(
                'Apple ile Giriş',
                style: GoogleFonts.cinzel(color: AppColors.textPureWhite, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Apple ile Giriş yalnızca iOS (iPhone / iPad) cihazlarda geçerlidir.\n\nAndroid cihazınızda lütfen "Google ile Devam Et" butonunu veya "Misafir Olarak Keşfet" seçeneğini kullanın.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Anladım', style: GoogleFonts.plusJakartaSans(color: AppColors.ancientGold)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.instance.signInWithApple();
      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Apple girişi iptal edildi.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
            backgroundColor: AppColors.surfaceCardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // Ana sayfaya geçme, ekranda kal!
      }

      final name = user.displayName ?? user.email ?? 'Gezgin';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hoş geldiniz $name. Astral portal açılıyor...',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
          ),
          backgroundColor: AppColors.surfaceCardElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.ancientGold),
          ),
        ),
      );
      _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Apple girişi başarısız: $e',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
          ),
          backgroundColor: AppColors.surfaceCardElevated,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    HapticFeedback.mediumImpact();
    await AuthService.instance.signInAsGuest();
    _navigateToHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üst Bölüm: Mistik Rozet, Logo ve Başlıklar (Yukarı taşındı)
                      Column(
                        children: [
                          const SizedBox(height: 8),

                          // 1. Astral Üst Rozet
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.ancientGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: AppColors.ancientGold.withValues(alpha: 0.35),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.ancientGold.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('✦', style: TextStyle(color: AppColors.ancientGold, fontSize: 10)),
                                const SizedBox(width: 6),
                                Text(
                                  'KADİM BİLİNÇALTI ASTRALI',
                                  style: GoogleFonts.cinzel(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.2,
                                    color: AppColors.ancientGold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('✦', style: TextStyle(color: AppColors.ancientGold, fontSize: 10)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. Mistik Logo & Çift Katmanlı Kozmik Çember
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Dış Mor-Mavi Kozmik Halka
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.neonPurple.withValues(alpha: 0.4),
                                        AppColors.mediterraneanSky.withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // İnce Altın Yörünge Çemberi
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.ancientGold.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                // Ana Çekirdek & Horus Gözü
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF2A1648),
                                        Color(0xFF0F0B18),
                                      ],
                                    ),
                                    border: Border.all(color: AppColors.ancientGold, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.neonPurple.withValues(alpha: 0.35),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '𓂀',
                                      style: TextStyle(
                                        fontSize: 34,
                                        color: AppColors.ancientGold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 3. Marka Başlığı
                          Text(
                            'ONEIRO',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 7.0,
                              color: AppColors.textPureWhite,
                              shadows: [
                                Shadow(
                                  color: AppColors.neonPurple.withValues(alpha: 0.6),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'RÜYALARIN KADİM ŞİFRESİ',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3.2,
                              color: AppColors.ancientGold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'Gece zihninizin sembollerini çözün; Carl Jung analizi, Doğu İslam ve Antik Akdeniz bilgeliğiyle bilinçaltınızı aydınlatın.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: AppColors.textSilver,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 4. Modern Özellik Kartları (3 Mini Vitrin)
                          _buildFeatureHighlights(),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Alt Bölüm: Giriş Butonları & Misafir Keşfi
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Google Butonu
                          _buildAuthButton(
                            onTap: _handleGoogleSignIn,
                            backgroundColor: AppColors.textPureWhite,
                            textColor: const Color(0xFF1F1F1F),
                            iconWidget: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                              ),
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4285F4),
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                            text: 'Google ile Devam Et',
                          ),

                          const SizedBox(height: 12),

                          // Apple Butonu
                          _buildAuthButton(
                            onTap: _handleAppleSignIn,
                            backgroundColor: const Color(0xFF14121E),
                            textColor: AppColors.textPureWhite,
                            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                            iconWidget: const Icon(
                              Icons.apple,
                              size: 22,
                              color: AppColors.textPureWhite,
                            ),
                            text: 'Apple ile Devam Et',
                          ),

                          const SizedBox(height: 14),

                          // Misafir Keşif Butonu (Modern Glass Pill)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handleGuestSignIn,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Giriş Yapmadan Keşfet',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSilver,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15,
                                      color: AppColors.ancientGold,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Gizlilik & Şartlar Dipnotu
                          Text(
                            'Devam ederek Kadim Gizlilik İlkeleri ve Kullanım Şartları\'nı kabul etmiş sayılırsınız.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Modern 3'lü Özellik Vitrini
  Widget _buildFeatureHighlights() {
    final features = [
      {'icon': '🧠', 'title': 'Jung Analizi', 'subtitle': 'Bilinçaltı & Gölgeler'},
      {'icon': '🏛️', 'title': '4 Kadim Ekol', 'subtitle': 'İslam, Akdeniz, Şamanik'},
      {'icon': '📜', 'title': 'Mühürlü Günlük', 'subtitle': 'Kişisel Rüya Arşivi'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF110E1C).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.ancientGold.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: features.map((f) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(f['icon']!, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 5),
                Text(
                  f['title']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPureWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  f['subtitle']!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAuthButton({
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color textColor,
    required Widget iconWidget,
    required String text,
    BoxBorder? border,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: _isLoading ? backgroundColor.withValues(alpha: 0.6) : backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

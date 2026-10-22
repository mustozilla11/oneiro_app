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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // Mistik Logo & Astral Çember
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPurple.withOpacity(0.35),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        border: Border.all(color: AppColors.ancientGold, width: 1.5),
                      ),
                      child: const Center(
                        child: Text(
                          '𓂀',
                          style: TextStyle(
                            fontSize: 42,
                            color: AppColors.ancientGold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Başlık & Açıklama
              Text(
                'ONEIRO',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6.0,
                  color: AppColors.textPureWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'KADİM BİLİNÇALTININ KAPISI',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3.0,
                  color: AppColors.ancientGold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rüyalarınızdaki arketipleri, gizli uyarıları ve kadim bilgeliği keşfedin. Günlüğünüzü sonsuza dek mühürleyin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),

              // 1. Google ile Giriş Yap Butonu
              _buildAuthButton(
                onTap: _handleGoogleSignIn,
                backgroundColor: AppColors.textPureWhite,
                textColor: Colors.black87,
                iconWidget: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4285F4),
                  ),
                ),
                text: 'Google ile Devam Et',
              ),

              const SizedBox(height: 12),

              // 2. Apple ile Giriş Yap Butonu (iOS Dünyası Standardı)
              _buildAuthButton(
                onTap: _handleAppleSignIn,
                backgroundColor: const Color(0xFF161324),
                textColor: AppColors.textPureWhite,
                border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                iconWidget: const Icon(
                  Icons.apple,
                  size: 24,
                  color: AppColors.textPureWhite,
                ),
                text: 'Apple ile Devam Et',
              ),

              const SizedBox(height: 18),

              // 3. Misafir Olarak Giriş (Skip - Mağaza onayları ve hızlı giriş için zorunlu)
              TextButton(
                onPressed: _handleGuestSignIn,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textDim,
                ),
                child: Text(
                  'Giriş Yapmadan Misafir Olarak Keşfet →',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Gizlilik & Şartlar Dipnotu
              Text(
                'Devam ederek Kadim Gizlilik İlkeleri ve Kullanım Şartları\'nı kabul etmiş sayılırsınız.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.textDim,
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isLoading ? backgroundColor.withOpacity(0.6) : backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
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

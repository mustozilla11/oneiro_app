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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

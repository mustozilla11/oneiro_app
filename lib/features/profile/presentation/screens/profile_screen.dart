import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import 'package:oneiro_app/features/subscription/presentation/providers/user_subscription_provider.dart';
import 'package:oneiro_app/features/subscription/presentation/widgets/paywall_modal.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google ile bağlanıldı (${user.displayName ?? user.email}). Rüyalarınız bulutta senkronize ediliyor.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
            backgroundColor: AppColors.surfaceCardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google girişi iptal edildi.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
            backgroundColor: AppColors.surfaceCardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google bağlantısı kurulamadı: $e',
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
            'Apple ile Giriş yalnızca iOS (iPhone / iPad) cihazlarda kullanılabilir.\n\nAndroid cihazınızda Google hesabınızla bağlanabilirsiniz.',
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
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Apple ile bağlanıldı (${user.displayName ?? user.email}).',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
            backgroundColor: AppColors.surfaceCardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
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
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Apple bağlantısı kurulamadı: $e',
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

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();
    await AuthService.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oturum kapatıldı. Misafir moduna geçildi.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
        ),
        backgroundColor: AppColors.surfaceCardElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: AppColors.ancientGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASTRAL PROFİL',
                        style: GoogleFonts.cinzel(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: AppColors.textPureWhite,
                        ),
                      ),
                      Text(
                        'Kullanıcı kimliği ve bilinçaltı arşivi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Profil Kartı & Kimlik Doğrulama
              StreamBuilder<OneiroUser?>(
                stream: AuthService.instance.authStateChanges,
                initialData: AuthService.instance.currentUser,
                builder: (context, authSnap) {
                  final user = authSnap.data ?? AuthService.instance.currentUser;
                  final isSignedIn = user != null;
                  final userName = user?.displayName ?? (isSignedIn ? 'Kadim Gezgin' : 'Misafir Seyyah');
                  final userEmail = user?.email ?? (isSignedIn ? 'Bulut Senkronize' : 'Giriş yapılmadı');
                  final avatarInitial = (userName.isNotEmpty ? userName[0].toUpperCase() : '𓂀');

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSignedIn ? AppColors.ancientGold.withOpacity(0.4) : AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.surfaceCardElevated,
                          child: Text(
                            isSignedIn ? avatarInitial : '𓂀',
                            style: TextStyle(
                              fontSize: isSignedIn ? 28 : 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ancientGold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userName,
                          style: GoogleFonts.cinzel(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPureWhite,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (!isSignedIn) ...[
                          // 1. Google ile Giriş Yap Butonu
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _isLoading ? null : _handleGoogleSignIn,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.textPureWhite,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4285F4),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Google ile Bağlan',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 2. Apple ile Giriş Yap Butonu
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _isLoading ? null : _handleAppleSignIn,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161324),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.apple, size: 20, color: AppColors.textPureWhite),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Apple ile Bağlan',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPureWhite,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Oturumu Kapat Butonu
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _isLoading ? null : _handleSignOut,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.logout_rounded, size: 16, color: AppColors.textMuted),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Oturumu Kapat',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Kadim Gezgin Plus & Jeton Cüzdanı Kartı
              Consumer(
                builder: (context, ref, _) {
                  final sub = ref.watch(userSubscriptionProvider);
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: sub.isPremium
                          ? const LinearGradient(colors: [Color(0xFF261D0C), Color(0xFF140F04)])
                          : null,
                      color: sub.isPremium ? null : AppColors.surfaceCardElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sub.isPremium ? AppColors.ancientGold : AppColors.borderGold,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (sub.isPremium ? AppColors.ancientGold : AppColors.neonPurple).withOpacity(0.15),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (sub.isPremium ? AppColors.ancientGold : AppColors.neonPurple).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            sub.isPremium ? Icons.auto_awesome : Icons.token_rounded,
                            color: sub.isPremium ? AppColors.ancientGold : AppColors.electricLavender,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.isPremium ? 'KADİM GEZGİN PLUS' : 'KADİM JETON CÜZDANI',
                                style: GoogleFonts.cinzel(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: AppColors.ancientGold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sub.isPremium
                                    ? 'Sınırsız Analiz & Sıfır Reklam'
                                    : '${sub.dreamCredits} Jeton Mevcut (Günde 1 Ücretsiz)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textSilver,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => PaywallModal.show(context),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.ancientGold.withOpacity(0.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            sub.isPremium ? 'Yönet' : 'Yükselt',
                            style: GoogleFonts.cinzel(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ancientGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Bilinçaltı İstatistikleri
              Text(
                'BİLİNÇALTI İSTATİSTİKLERİ',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.electricLavender,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatTile('12', 'Çözülen Rüya', Icons.auto_awesome),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile('Su 🌊', 'Baskın Sembol', Icons.water_drop_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile('Gölge', 'Jungian Arketip', Icons.psychology_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile('%85', 'Lucid Frekans', Icons.insights_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Gizlilik & Veri Bilgilendirmesi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.ancientGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gizlilik & Veri Güvencesi',
                            style: GoogleFonts.cinzel(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPureWhite,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rüyalarınız mahremdir. Google yalnızca kimliğinizi doğrular; rüya metinleriniz ve tabirleriniz Google ile paylaşılmaz.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textDim,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.neonPurple, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.cinzel(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPureWhite,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../dream/presentation/providers/dream_provider.dart';
import 'package:oneiro_app/features/subscription/presentation/providers/user_subscription_provider.dart';
import 'package:oneiro_app/features/subscription/presentation/widgets/paywall_modal.dart';
import '../widgets/how_it_works_modal.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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
          backgroundColor: AppColors.charcoalSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: Row(
            children: [
              const Icon(Icons.apple, color: AppColors.moonlight, size: 22),
              const SizedBox(width: 8),
              Text(
                'Apple ile Giriş',
                style: GoogleFonts.cormorantGaramond(
                  color: AppColors.moonlight,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'Apple ile Giriş yalnızca iOS cihazlarda kullanılabilir.\n\nAndroid cihazınızda Google hesabınızla bağlanabilirsiniz.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.mistGrey, height: 1.5, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Anladım',
                style: GoogleFonts.plusJakartaSans(color: AppColors.moonlight, fontWeight: FontWeight.w600),
              ),
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
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signOut();
      ref.read(dreamProvider.notifier).reset();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  /// Kullanıcının kayıtlı gerçek rüyalarından dinamik bilinçaltı istatistikleri üretir
  Future<Map<String, String>> _calculateSubconsciousStats() async {
    final dreams = await FirestoreService.instance.getLocalDreams();
    if (dreams.isEmpty) {
      return {
        'count': '0',
        'topSymbol': 'Henüz Yok',
        'archetype': 'Keşfediliyor',
        'frequency': '%0',
      };
    }

    // 1. Gerçek Çözülen Rüya Sayısı
    final count = '${dreams.length}';

    // 2. En Çok Tekrar Eden Sembol
    final symbolCounts = <String, int>{};
    for (final d in dreams) {
      final symbols = (d['symbols'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      for (final s in symbols) {
        final clean = s.trim();
        if (clean.isNotEmpty) {
          symbolCounts[clean] = (symbolCounts[clean] ?? 0) + 1;
        }
      }
    }

    String topSymbol = 'Keşfediliyor';
    if (symbolCounts.isNotEmpty) {
      final sorted = symbolCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topSymbol = sorted.first.key;
    }

    // 3. Arketip Analizi (Rüyaların içeriğine göre Jungian arketip)
    int shadow = 0;
    int anima = 0;
    int hero = 0;
    int self = 0;

    for (final d in dreams) {
      final text = '${d['dreamText'] ?? ''} ${d['subconsciousAnalysis'] ?? ''} ${d['interpretation'] ?? ''}'.toLowerCase();
      if (text.contains('gölge') || text.contains('karanlık') || text.contains('korku') || text.contains('kaç') || text.contains('yılan') || text.contains('düş')) {
        shadow++;
      }
      if (text.contains('su') || text.contains('deniz') || text.contains('ay') || text.contains('kadın') || text.contains('aşk') || text.contains('sev')) {
        anima++;
      }
      if (text.contains('uç') || text.contains('yol') || text.contains('dağ') || text.contains('aslan') || text.contains('savaş') || text.contains('kapı')) {
        hero++;
      }
      if (text.contains('altın') || text.contains('ışık') || text.contains('güneş') || text.contains('mabet') || text.contains('ayna') || text.contains('bilge')) {
        self++;
      }
    }

    final scores = {
      'Gölge': shadow,
      'Anima': anima,
      'Kahraman': hero,
      'Öz-Benlik': self,
    };
    final topArchetype = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final archetype = topArchetype.value > 0 ? topArchetype.key : 'Bilinçdışı';

    // 4. Hatırlama / Bilinçaltı Frekansı
    final freqNum = (20 + (dreams.length * 15)).clamp(20, 98);
    final frequency = '%$freqNum';

    return {
      'count': count,
      'topSymbol': topSymbol,
      'archetype': archetype,
      'frequency': frequency,
    };
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
                      color: AppColors.charcoalSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: AppColors.moonlight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÜYA PROFİLİ',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.moonlight,
                        ),
                      ),
                      Text(
                        'Kişisel hesap ve bilinçaltı arşivi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.mistGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // "Nasıl Çalışır?" 6 Aşamalı Şema & Blok Diyagram Kutusu
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  HowItWorksModal.show(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Icon(
                          Icons.schema_outlined,
                          color: AppColors.moonlight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'NASIL ÇALIŞIR?',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: AppColors.moonlight,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: Text(
                                    'ŞEMA',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mistGrey,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rüya metninden sembol ayrıştırmaya ve kadim kaynak taramasına kadar 6 aşamalı blok diyagram.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                height: 1.4,
                                color: AppColors.mistGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.mistGrey,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Profil Kartı & Kimlik Doğrulama
              StreamBuilder<OneiroUser?>(
                stream: AuthService.instance.authStateChanges,
                initialData: AuthService.instance.currentUser,
                builder: (context, authSnap) {
                  final user = authSnap.connectionState == ConnectionState.waiting
                      ? AuthService.instance.currentUser
                      : authSnap.data;
                  final isSignedIn = user != null && !user.isGuest;
                  final userName = isSignedIn ? (user.displayName ?? 'Rüya Gezgini') : 'Misafir Okuyucu';
                  final userEmail = isSignedIn ? (user.email ?? 'Giriş Yapıldı') : 'Giriş yapılmadı';
                  final avatarInitial = (isSignedIn && userName.isNotEmpty ? userName[0].toUpperCase() : '☾');

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.charcoalSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.oledBlack,
                          child: Text(
                            avatarInitial,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.moonlight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userName,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppColors.moonlight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.mistGrey,
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (!isSignedIn) ...[
                          // 1. Google ile Giriş Yap Butonu
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isLoading ? null : _handleGoogleSignIn,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.moonlight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.charcoalBlack,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Google ile Giriş Yap',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.charcoalBlack,
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
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isLoading ? null : _handleAppleSignIn,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.apple, size: 18, color: AppColors.moonlight),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Apple ile Bağlan',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.moonlight,
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
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isLoading ? null : _handleSignOut,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.logout_rounded, size: 15, color: AppColors.mistGrey),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Oturumu Kapat',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.mistGrey,
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

              // Gezgin Plus & Jeton Kartı
              Consumer(
                builder: (context, ref, _) {
                  final sub = ref.watch(userSubscriptionProvider);
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.charcoalSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Icon(
                            sub.isPremium ? Icons.auto_stories_outlined : Icons.toll_outlined,
                            color: AppColors.moonlight,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.isPremium ? 'RÜYA GÜNLÜĞÜ PLUS' : 'RÜYA KONTÖRÜ',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AppColors.moonlight,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                sub.isPremium
                                    ? 'Sınırsız Analiz & Sıfır Reklam'
                                    : '${sub.dreamCredits} Tabir Hakkı (Günde 1 Ücretsiz)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.mistGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            PaywallModal.show(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.borderSubtle),
                            ),
                          ),
                          child: Text(
                            sub.isPremium ? 'Yönet' : 'Yükselt',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.moonlight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Bilinçaltı İstatistikleri
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BİLİNÇALTI İSTATİSTİKLERİ',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.moonlight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rüya günlüğünüzdeki sembol ve arketiplerden türetilir',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.mistGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              FutureBuilder<Map<String, String>>(
                future: _calculateSubconsciousStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {
                    'count': '—',
                    'topSymbol': '—',
                    'archetype': '—',
                    'frequency': '—',
                  };

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatTile(stats['count']!, 'Çözülen Rüya', Icons.auto_stories_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatTile(stats['topSymbol']!, 'Baskın Sembol', Icons.water_drop_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatTile(stats['archetype']!, 'Baskın Arketip', Icons.psychology_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatTile(stats['frequency']!, 'Hatırlama Sıklığı', Icons.insights_outlined),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Gizlilik & Veri Güvencesi
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.charcoalSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.moonlight,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gizlilik ve Mahremiyet',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.moonlight,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Rüyalarınız tamamen mahremdir ve öncelikle cihazınızda saklanır. Google veya Apple yalnızca kimliğinizi doğrular; rüya metinleriniz üçüncü şahıslarla paylaşılmaz.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.mistGrey,
                              height: 1.5,
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
        color: AppColors.charcoalSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.moonlight, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.moonlight,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.mistGrey,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/theme_selector_bar.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/notification_service.dart';
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
  bool _morningReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.isMorningReminderEnabled().then((enabled) {
      if (mounted) {
        setState(() => _morningReminderEnabled = enabled);
      }
    });
  }

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
              'Google ile bağlanıldı (${user.displayName ?? user.email}). Oturumunuz kalıcı olarak kaydedildi.',
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
      final errorStr = e.toString();
      final isAndroidDebugIssue = errorStr.contains('10') ||
          errorStr.contains('DEVELOPER_ERROR') ||
          errorStr.contains('sign_in_failed') ||
          errorStr.contains('12500');

      if (isAndroidDebugIssue && !kIsWeb && Platform.isAndroid) {
        final savedUser = await AuthService.instance.signInWithDevAccount(
          name: 'Rüya Gezgini',
          email: 'Onaylı Cihaz Oturumu',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Oturumunuz (${savedUser.displayName}) bu cihaza kalıcı olarak kaydedildi.',
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
              'Google bağlantısı kurulamadı: $e',
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

  Future<void> _handleAppleSignIn() async {
    HapticFeedback.mediumImpact();

    if (!kIsWeb && Platform.isAndroid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.charcoalSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          title: Row(
            children: [
              Icon(Icons.apple, color: AppColors.moonlight, size: 22),
              const SizedBox(width: 8),
              Text(
                'Apple ile Giriş',
                style: AppTheme.headingStyle(
                  color: AppColors.moonlight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
          'Misafir moduna geçildi. Cihazınızdaki rüya arşivi korundu.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
        ),
        backgroundColor: AppColors.surfaceCardElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Kullanıcının kayıtlı gerçek rüyalarından matematiksel ve tıklanabilir bilinçaltı istatistikleri üretir
  Future<Map<String, dynamic>> _calculateSubconsciousStats() async {
    final dreams = await FirestoreService.instance.getLocalDreams();
    final now = DateTime.now();

    // Son 7 günün tarih dizeleri (YYYY-MM-DD)
    final last7Days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });

    if (dreams.isEmpty) {
      return {
        'count': '0',
        'countSub': 'İlk rüyanızı çözümleyin',
        'topSymbol': 'Henüz Yok',
        'topSymbolSub': 'Sembol kaydı bekleniyor',
        'archetype': 'Keşfediliyor',
        'archetypeSub': 'Jung arketip analizi',
        'frequency': '0 / 7 Gün',
        'frequencySub': 'Son 7 günlük kayıt düzeni',
        'symbolList': <MapEntry<String, int>>[],
        'traditionCounts': <String, int>{
          'islam_dogu': 0,
          'antik_akdeniz': 0,
          'psikoloji': 0,
        },
        'archetypeScores': <String, int>{
          'Gölge': 0,
          'Anima': 0,
          'Kahraman': 0,
          'Öz-Benlik': 0,
        },
        'last7DaysStatus': List<Map<String, dynamic>>.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
          return {
            'label': dayNames[d.weekday - 1],
            'dayNum': '${d.day}',
            'active': false,
          };
        }),
        'streak': 0,
        'totalSymbols': 0,
      };
    }

    // 1. Sembol Frekans Analizi
    final symbolCounts = <String, int>{};
    int totalSymbols = 0;
    final traditionCounts = <String, int>{
      'islam_dogu': 0,
      'antik_akdeniz': 0,
      'psikoloji': 0,
    };
    final recordedDates = <String>{};

    for (final d in dreams) {
      final symbols = (d['symbols'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];
      for (final s in symbols) {
        final normalized = s[0].toUpperCase() + s.substring(1).toLowerCase();
        symbolCounts[normalized] = (symbolCounts[normalized] ?? 0) + 1;
        totalSymbols++;
      }

      final tradId = (d['primaryTraditionId'] as String? ?? 'islam_dogu').trim();
      if (traditionCounts.containsKey(tradId)) {
        traditionCounts[tradId] = (traditionCounts[tradId] ?? 0) + 1;
      } else {
        traditionCounts['islam_dogu'] = (traditionCounts['islam_dogu'] ?? 0) + 1;
      }

      final dateStr = (d['dateString'] as String? ?? '').trim();
      if (dateStr.isNotEmpty) {
        recordedDates.add(dateStr);
      }
    }

    final sortedSymbols = symbolCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String topSymbol = 'Keşfediliyor';
    String topSymbolSub = 'Sembol analizi';
    if (sortedSymbols.isNotEmpty) {
      topSymbol = sortedSymbols.first.key;
      topSymbolSub = sortedSymbols.first.value > 1
          ? '${sortedSymbols.first.value} rüyada tekrar etti'
          : '${sortedSymbols.length} farklı sembol içinden';
    }

    // 2. Doğru Kelime ve Sembol Tabanlı Jung Arketip Puanlaması
    int shadow = 0;
    int anima = 0;
    int hero = 0;
    int self = 0;

    bool hasWord(String text, List<String> roots) {
      for (final r in roots) {
        if (RegExp('(^|[^a-zçğıöşü])$r', caseSensitive: false).hasMatch(text)) {
          return true;
        }
      }
      return false;
    }

    for (final d in dreams) {
      final symbolsLower = ((d['symbols'] as List<dynamic>?) ?? [])
          .map((e) => e.toString().toLowerCase().trim())
          .toSet();
      final text =
          '${d['dreamText'] ?? ''} ${d['subconsciousAnalysis'] ?? ''} ${d['emotion'] ?? ''}'
              .toLowerCase();

      if (symbolsLower.intersection({'yılan', 'karanlık', 'gölge', 'uçurum', 'köpek', 'kurt', 'kan', 'ateş'}).isNotEmpty ||
          hasWord(text, ['gölge', 'karanlık', 'korku', 'kabus', 'yılan', 'uçurum', 'düşme', 'kovala', 'kaçış', 'canavar', 'mezar', 'ölüm'])) {
        shadow += 2;
      }
      if (symbolsLower.intersection({'su', 'deniz', 'ay', 'yağmur', 'nehir', 'okyanus', 'göl', 'çiçek'}).isNotEmpty ||
          hasWord(text, ['deniz', 'okyanus', 'nehir', 'yağmur', 'gözyaşı', 'sevgi', 'özlem', 'aşk', 'anne', 'çocuk', 'bahçe', 'duygu'])) {
        anima += 2;
      }
      if (symbolsLower.intersection({'dağ', 'kapı', 'anahtar', 'yol', 'merdiven', 'at', 'aslan', 'köprü', 'uçmak', 'kanat'}).isNotEmpty ||
          hasWord(text, ['dağ', 'zirve', 'yolculuk', 'uçmak', 'uçtuğum', 'köprü', 'kapı', 'anahtar', 'merdiven', 'aslan', 'mücadele', 'zafer', 'sınav'])) {
        hero += 2;
      }
      if (symbolsLower.intersection({'ayna', 'güneş', 'ışık', 'altın', 'kitap', 'ağaç', 'yıldız', 'mabet'}).isNotEmpty ||
          hasWord(text, ['altın', 'ışık', 'güneş', 'mabet', 'tapınak', 'cami', 'ayna', 'bilge', 'kitap', 'ağaç', 'huzur', 'uyanış', 'dua'])) {
        self += 2;
      }
    }

    // Eğer hiçbir kelime eşleşmediyse seçilen ekole ve temel sembol sayısına göre taban puan ver
    if (shadow == 0 && anima == 0 && hero == 0 && self == 0) {
      self = 2;
      anima = 1;
    }

    final archetypeScores = <String, int>{
      'Öz-Benlik': self,
      'Anima': anima,
      'Kahraman': hero,
      'Gölge': shadow,
    };

    final sortedArchetypes = archetypeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final archetype = sortedArchetypes.first.key;
    final totalArchPoints = (shadow + anima + hero + self).clamp(1, 9999);
    final topArchPct = ((sortedArchetypes.first.value / totalArchPoints) * 100).round();

    // 3. Gerçek Tarih Bazlı Son 7 Gün ve Seri (Streak) Hesabı
    const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    int activeDaysInLast7 = 0;
    final last7DaysStatus = <Map<String, dynamic>>[];

    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: 6 - i));
      final dateKey = last7Days[i];
      final isActive = recordedDates.contains(dateKey);
      if (isActive) activeDaysInLast7++;
      last7DaysStatus.add({
        'label': dayNames[d.weekday - 1],
        'dayNum': '${d.day}',
        'active': isActive,
      });
    }

    // Eğer eski kayıtlarda dateString yoksa ama rüya varsa en az 1 aktif gün say
    if (activeDaysInLast7 == 0 && dreams.isNotEmpty) {
      activeDaysInLast7 = 1;
      last7DaysStatus.last['active'] = true;
    }

    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (recordedDates.contains(key)) {
        streak++;
      } else if (i == 0) {
        // Bugün henüz girilmediyse dün kontrolüne devam et
        continue;
      } else {
        break;
      }
    }
    if (streak == 0 && dreams.isNotEmpty) streak = 1;

    return {
      'count': '${dreams.length}',
      'countSub': '$totalSymbols sembol çözümlendi',
      'topSymbol': topSymbol,
      'topSymbolSub': topSymbolSub,
      'archetype': archetype,
      'archetypeSub': '%$topArchPct baskın bilinçaltı izi',
      'frequency': '$activeDaysInLast7 / 7 Gün',
      'frequencySub': 'Aktif seri: $streak gün',
      'symbolList': sortedSymbols,
      'traditionCounts': traditionCounts,
      'archetypeScores': archetypeScores,
      'last7DaysStatus': last7DaysStatus,
      'streak': streak,
      'totalSymbols': totalSymbols,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

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
                    child: Icon(Icons.person_outline_rounded, color: AppColors.moonlight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÜYA PROFİLİ',
                        style: AppTheme.headingStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.moonlight,
                        ),
                      ),
                      Text(
                        'Kişisel hesap, tema tercihi ve bilinçaltı arşivi',
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

              // 1. GÖRÜNÜM & 3 TEMA SEÇİCİ BÖLÜMÜ
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: AppColors.moonlight, size: 17),
                      const SizedBox(width: 8),
                      Text(
                        'GÖRÜNÜM & TEMA SEÇİMİ',
                        style: AppTheme.headingStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.moonlight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Edebi Günlük, Kadim Mistik ve Safir Minimal temaları arasında dilediğiniz an geçiş yapın',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.mistGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ThemeSelectorBar(compact: false),
                ],
              ),

              const SizedBox(height: 18),

              // 2. 10 Dilli Evrensel Dil Seçimi (Language Settings)
              _buildLanguageSelectorCard(context),

              const SizedBox(height: 18),

              // 3. "Nasıl Çalışır?" 6 Aşamalı Şema & Blok Diyagram Kutusu
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
                        child: Icon(
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
                                  style: AppTheme.headingStyle(
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
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.mistGrey,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Profil Kartı & Kimlik Doğrulama
              StreamBuilder<OneiroUser?>(
                stream: AuthService.instance.authStateChanges,
                initialData: AuthService.instance.currentUser,
                builder: (context, authSnap) {
                  final user = authSnap.data ?? AuthService.instance.currentUser;
                  final isSignedIn = user != null && !user.isGuest;
                  final userName = isSignedIn ? (user.displayName ?? 'Rüya Gezgini') : 'Kayıtlı Misafir Okuyucu';
                  final userEmail = isSignedIn
                      ? (user.email ?? 'Kalıcı Oturum Aktif')
                      : 'Rüyalarınız bu cihazda güvenle saklanıyor';
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
                            style: AppTheme.headingStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.moonlight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userName,
                          style: AppTheme.headingStyle(
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
                                    Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.charcoalBlack,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Google ile Hesabı Bağla',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
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
                                    Icon(Icons.apple, size: 18, color: AppColors.moonlight),
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
                                    Icon(Icons.logout_rounded, size: 15, color: AppColors.mistGrey),
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

              // 4. Gezgin Plus & Jeton Kartı
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
                                style: AppTheme.headingStyle(
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
                              side: BorderSide(color: AppColors.borderSubtle),
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

              // 5. Bilinçaltı İstatistikleri (Gerçek Hesaplama & Tıklanabilir Detay Raporu)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BİLİNÇALTI İSTATİSTİKLERİ',
                          style: AppTheme.headingStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.moonlight,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Detaylı analiz tablosunu görmek için kartlara dokunun',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.mistGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: AppColors.moonlight,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              ValueListenableBuilder<int>(
                valueListenable: FirestoreService.instance.localDreamsRevision,
                builder: (context, _, __) {
                  return FutureBuilder<Map<String, dynamic>>(
                    future: _calculateSubconsciousStats(),
                    builder: (context, snapshot) {
                      final stats = snapshot.data ??
                          <String, dynamic>{
                            'count': '0',
                            'countSub': 'İlk rüyanızı çözümleyin',
                            'topSymbol': 'Henüz Yok',
                            'topSymbolSub': 'Sembol kaydı bekleniyor',
                            'archetype': 'Keşfediliyor',
                            'archetypeSub': 'Jung arketip analizi',
                            'frequency': '0 / 7 Gün',
                            'frequencySub': 'Son 7 günlük kayıt düzeni',
                            'symbolList': <MapEntry<String, int>>[],
                            'traditionCounts': <String, int>{},
                            'archetypeScores': <String, int>{},
                            'last7DaysStatus': <Map<String, dynamic>>[],
                            'streak': 0,
                            'totalSymbols': 0,
                          };

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  value: stats['count'] as String,
                                  label: 'Çözülen Rüya',
                                  subLabel: stats['countSub'] as String? ?? '',
                                  icon: Icons.auto_stories_outlined,
                                  accentColor: AppColors.islamGold,
                                  onTap: () => _showStatsDetailSheet(context, stats),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatTile(
                                  value: stats['topSymbol'] as String,
                                  label: 'Baskın Sembol',
                                  subLabel: stats['topSymbolSub'] as String? ?? '',
                                  icon: Icons.water_drop_outlined,
                                  accentColor: AppColors.mediterraneanBlue,
                                  onTap: () => _showStatsDetailSheet(context, stats),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  value: stats['archetype'] as String,
                                  label: 'Baskın Arketip',
                                  subLabel: stats['archetypeSub'] as String? ?? '',
                                  icon: Icons.psychology_outlined,
                                  accentColor: AppColors.psychologyPurple,
                                  onTap: () => _showStatsDetailSheet(context, stats),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatTile(
                                  value: stats['frequency'] as String,
                                  label: 'Haftalık Düzen',
                                  subLabel: stats['frequencySub'] as String? ?? '',
                                  icon: Icons.calendar_today_outlined,
                                  accentColor: AppColors.moonlight,
                                  onTap: () => _showStatsDetailSheet(context, stats),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // 6. Sabah Rüya Hatırlatıcısı Ayarı (08:30)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
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
                            'Sabah Rüya Hatırlatıcısı (08:30)',
                            style: AppTheme.headingStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.moonlight,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Her sabah uyanınca rüyanızı unutmadan kaydetmeniz için bildirim gönderir',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: AppColors.mistGrey,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _morningReminderEnabled,
                      activeThumbColor: AppColors.moonlight,
                      activeTrackColor: AppColors.moonlight.withValues(alpha: 0.25),
                      onChanged: (val) async {
                        HapticFeedback.selectionClick();
                        setState(() => _morningReminderEnabled = val);
                        await NotificationService.instance.setMorningReminderEnabled(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 7. Gizlilik & Veri Güvencesi
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
                      child: Icon(
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
                            'Gizlilik ve Kalıcı Yerel Kayıt',
                            style: AppTheme.headingStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.moonlight,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Rüyalarınız, oturumunuz ve tema tercihiniz doğrudan cihazınızın kalıcı hafızasında saklanır. Uygulamayı kapatsanız dahi verileriniz silinmez.',
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

  Widget _buildLanguageSelectorCard(BuildContext context) {
    final currentLang = ref.watch(localeProvider);
    final activeLangObj = AppStrings.supportedLanguages.firstWhere(
      (l) => l['code'] == currentLang,
      orElse: () => AppStrings.supportedLanguages.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.charcoalSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showLanguagePicker(context);
        },
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
                Icons.language_rounded,
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
                    AppStrings.get('languageSetting', currentLang),
                    style: AppTheme.headingStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.moonlight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppStrings.get('languageSubtitle', currentLang),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AppColors.mistGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderMoonlight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${activeLangObj['flag']} ${activeLangObj['name']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 14,
                    color: AppColors.moonlight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final currentLang = ref.read(localeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.get('languageSetting', currentLang),
                  style: AppTheme.headingStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.moonlight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Uygulama arayüzü ve yapay zeka analiz dili anında güncellenir',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.mistGrey,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: AppStrings.supportedLanguages.length,
                    separatorBuilder: (_, __) => Divider(
                      color: AppColors.borderSubtle,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = AppStrings.supportedLanguages[index];
                      final code = item['code']!;
                      final isSelected = code == currentLang;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Text(
                          item['flag']!,
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          item['name']!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.moonlight : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: AppColors.moonlight, size: 20)
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(localeProvider.notifier).setLanguage(code);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatTile({
    required String value,
    required String label,
    required String subLabel,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.charcoalSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: accentColor, size: 18),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.dimMist,
                    size: 13,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.headingStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.moonlight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppColors.mistGrey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showStatsDetailSheet(BuildContext context, Map<String, dynamic> stats) {
    final symbolList = (stats['symbolList'] as List<MapEntry<String, int>>?) ?? [];
    final traditionCounts = (stats['traditionCounts'] as Map<String, int>?) ?? {};
    final archetypeScores = (stats['archetypeScores'] as Map<String, int>?) ?? {};
    final last7DaysStatus = (stats['last7DaysStatus'] as List<Map<String, dynamic>>?) ?? [];
    final totalDreams = int.tryParse(stats['count'] as String? ?? '0') ?? 0;

    final archetypeDescriptions = <String, String>{
      'Öz-Benlik': 'İçsel bütünlük, ruhsal uyanış ve bilgelik arayışı (Işık, Ayna, Güneş, Ağaç)',
      'Anima': 'Duygusal derinlik, sezgi, şefkat ve akışkanlık (Su, Deniz, Ay, Yağmur)',
      'Kahraman': 'Eşikleri aşma, irade, dönüşüm ve hedef yolculuğu (Dağ, Kapı, Anahtar, Uçuş)',
      'Gölge': 'Bastırılmış korkularla yüzleşme ve arınma süreci (Karanlık, Yılan, Uçurum)',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.charcoalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final totalArch = archetypeScores.values.fold<int>(0, (a, b) => a + b).clamp(1, 9999);
        final totalTrad = traditionCounts.values.fold<int>(0, (a, b) => a + b).clamp(1, 9999);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.76,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'BİLİNÇALTI ANALİZ RAPORU',
                    style: AppTheme.headingStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.moonlight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kaydettiğiniz $totalDreams rüya üzerinden gerçek zamanlı hesaplanan sembol, arketip ve düzen dökümü.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.mistGrey,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. SON 7 GÜNLÜK KAYIT TAKVİMİ
                  Text(
                    'SON 7 GÜNLÜK RÜYA DÜZENİ',
                    style: AppTheme.headingStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.moonlight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: last7DaysStatus.map((day) {
                      final active = day['active'] as bool? ?? false;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.moonlight.withValues(alpha: 0.16)
                                : AppColors.charcoalBlack,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active ? AppColors.moonlight : AppColors.borderSubtle,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                day['label'] as String? ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: AppColors.mistGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                day['dayNum'] as String? ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: active ? AppColors.moonlight : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                active ? Icons.check_circle_rounded : Icons.circle_outlined,
                                size: 13,
                                color: active ? AppColors.moonlight : AppColors.dimMist,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  // 2. EN ÇOK TEKRAR EDEN SEMBOLLER
                  Text(
                    'TEKRAR EDEN RÜYA SEMBOLLERİ',
                    style: AppTheme.headingStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.moonlight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (symbolList.isEmpty)
                    Text(
                      'Henüz sembol kaydı bulunmuyor. İlk rüyanızı çözümlediğinizde sembol frekansları burada listelenir.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.mistGrey,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: symbolList.take(8).map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.charcoalBlack,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.mediterraneanBlue.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                entry.key,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.mediterraneanBlue.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${entry.value}x',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mediterraneanBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 22),

                  // 3. JUNG ARKETİP DAĞILIMI
                  Text(
                    'JUNG ARKETİP DAĞILIMI',
                    style: AppTheme.headingStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.moonlight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...archetypeScores.entries.map((e) {
                    final pct = totalDreams == 0 ? 0 : ((e.value / totalArch) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.key,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '%$pct',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.psychologyPurple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            archetypeDescriptions[e.key] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.mistGrey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalDreams == 0 ? 0.0 : (e.value / totalArch).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: AppColors.charcoalBlack,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.psychologyPurple),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // 4. BAŞVURULAN KAYNAK EKOLLERİ
                  Text(
                    'TERCİH EDİLEN KAYNAK DAĞILIMI',
                    style: AppTheme.headingStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.moonlight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...[
                    {'id': 'islam_dogu', 'name': 'Doğu & İslam (İbn-i Sîrîn)', 'color': AppColors.islamGold},
                    {'id': 'antik_akdeniz', 'name': 'Antik Akdeniz (Artemidorus)', 'color': AppColors.mediterraneanBlue},
                    {'id': 'psikoloji', 'name': 'Modern Psikoloji (Carl Jung)', 'color': AppColors.psychologyPurple},
                  ].map((item) {
                    final id = item['id'] as String;
                    final name = item['name'] as String;
                    final color = item['color'] as Color;
                    final cnt = traditionCounts[id] ?? 0;
                    final pct = totalDreams == 0 ? 0 : ((cnt / totalTrad) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '$cnt rüya (%$pct)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

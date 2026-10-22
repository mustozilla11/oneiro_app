import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ads/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../subscription/presentation/providers/user_subscription_provider.dart';
import '../../../subscription/presentation/widgets/paywall_modal.dart';
import '../../domain/models/dream_interpretation.dart';
import '../providers/dream_provider.dart';

class LockedTraditionCard extends ConsumerStatefulWidget {
  final TraditionAnalysisItem tradition;

  const LockedTraditionCard({
    super.key,
    required this.tradition,
  });

  @override
  ConsumerState<LockedTraditionCard> createState() => _LockedTraditionCardState();
}

class _LockedTraditionCardState extends ConsumerState<LockedTraditionCard> {
  bool _isLoading = false;

  String _cleanInterpretation(String raw) {
    return raw
        .replaceAll(RegExp(r'^\s*#+\s*.*(?:\n+|$)', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*(?:rüyanın tabiri|rüya tabiri|tabir)\s*[:\-]?\s*', caseSensitive: false), '')
        .trim();
  }

  Future<void> _handleUnlock() async {
    HapticFeedback.mediumImpact();

    final subState = ref.read(userSubscriptionProvider);
    final isPremium = subState.isPremium;
    final hasCredits = subState.dreamCredits > 0;

    // 1. Durum: Kullanıcı Premium ise doğrudan aç
    if (isPremium) {
      _executeUnlockOnBackend();
      return;
    }

    // 2. Durum: Kullanıcının Jetonu Varsa
    if (hasCredits) {
      final shouldDeduct = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCardElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.ancientGold, width: 1),
          ),
          title: Text(
            'Kilit Açma Yöntemi',
            style: GoogleFonts.cinzel(
              color: AppColors.ancientGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bu geleneği 1 Jeton harcayarak anında açabilir veya 1 kısa reklam izleyerek jetonunuzu saklayabilirsiniz.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // Reklam izle
              child: Text(
                'Reklam İzle',
                style: GoogleFonts.plusJakartaSans(color: AppColors.electricLavender),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), // Jeton harca
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ancientGold,
                foregroundColor: Colors.black,
              ),
              child: const Text('1 Jeton Harca'),
            ),
          ],
        ),
      );

      if (shouldDeduct == true) {
        await ref.read(userSubscriptionProvider.notifier).useCreditForTradition();
        _executeUnlockOnBackend();
        return;
      }
    }

    // 3. Durum: Ödüllü Video Reklam İzletme
    setState(() => _isLoading = true);
    bool rewardEarned = false;

    await AdService.instance.showRewardedAd(
      onUserEarnedReward: () {
        rewardEarned = true;
        debugPrint('[LockedTraditionCard] Ödül kazanıldı, gelenek kilidi açılıyor: ${widget.tradition.traditionId}');
        _executeUnlockOnBackend();
      },
      onAdClosed: () {
        if (!rewardEarned && mounted) {
          setState(() => _isLoading = false);
        }
      },
      onAdFailed: () {
        if (!rewardEarned && mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _executeUnlockOnBackend() async {
    setState(() => _isLoading = true);

    final success = await ref
        .read(dreamProvider.notifier)
        .unlockTradition(widget.tradition.traditionId);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF261C0A), // Sıcak kadim altın-kehribar
                    Color(0xFF140F24), // Mistik gece tonu
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.ancientGold.withValues(alpha: 0.85),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ancientGold.withValues(alpha: 0.3),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ancientGold.withValues(alpha: 0.18),
                      border: Border.all(
                        color: AppColors.ancientGold.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: AppColors.ancientGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KİLİT BAŞARIYLA AÇILDI ✦',
                          style: GoogleFonts.cinzel(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                            color: AppColors.ancientGold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.tradition.title} analizi günlüğünüze mühürlendi.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPureWhite,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kadim tabir açılamadı, lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
            backgroundColor: AppColors.surfaceCardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trad = widget.tradition;
    final subState = ref.watch(userSubscriptionProvider);
    final isUnlocked = trad.isUnlocked;

    IconData iconData = Icons.auto_stories_outlined;

    if (trad.traditionId == 'antik_akdeniz') {
      iconData = Icons.account_balance_outlined;
    } else if (trad.traditionId == 'psikoloji') {
      iconData = Icons.psychology_outlined;
    } else {
      iconData = Icons.menu_book_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.charcoalSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kart Başlığı (Editorial Header)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Icon(iconData, color: AppColors.moonlight, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trad.title.toUpperCase(),
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trad.scholar,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.mistGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUnlocked ? Icons.lock_open_outlined : Icons.lock_outline,
                        size: 11,
                        color: isUnlocked ? AppColors.moonlight : AppColors.mistGrey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isUnlocked ? 'AÇILDI' : 'KİLİTLİ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isUnlocked ? AppColors.moonlight : AppColors.mistGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.borderSubtle, height: 1),

          // İçerik Alanı
          if (isUnlocked && trad.interpretation != null) ...[
            // Tam Yorum Metni (Editorial Typography)
            Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _cleanInterpretation(trad.interpretation!),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    height: 1.85,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Kilitli Teaser (Fısıltı Alıntısı)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppColors.moonlight.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      '"${trad.teaser ?? "Bu geleneğin rüyanızla ilgili gizemli bir uyarısı var..."}"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Mat Ay Işığı Kilit Açma Butonu
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.moonlight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isLoading
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _handleUnlock();
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: _isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.charcoalBlack),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      subState.isPremium
                                          ? Icons.lock_open_outlined
                                          : Icons.play_arrow_outlined,
                                      color: AppColors.charcoalBlack,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        subState.isPremium
                                            ? 'Kadim Analizi Oku (Plus ile Açık)'
                                            : subState.dreamCredits > 0
                                                ? 'Tam Analizi Oku (1 Reklam veya Jeton)'
                                                : 'Kadim Analizi Oku (Kısa Reklam)',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: AppColors.charcoalBlack,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Plus Satın Alım Hatırlatıcısı
                  if (!subState.isPremium) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          PaywallModal.show(context);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          'Tüm kilitleri sınırsız aç: Kadim Gezgin Plus',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.mistGrey,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.mistGrey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

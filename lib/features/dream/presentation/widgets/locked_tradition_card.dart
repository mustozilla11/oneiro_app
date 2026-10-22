import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ads/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme.dart';
import '../../../subscription/presentation/providers/user_subscription_provider.dart';
import '../../../subscription/presentation/widgets/paywall_modal.dart';
import '../../domain/models/dream_interpretation.dart';
import '../providers/dream_provider.dart';

class LockedTraditionCard extends ConsumerStatefulWidget {
  final TraditionAnalysisItem tradition;
  final DreamInterpretation? parentInterpretation;

  const LockedTraditionCard({
    super.key,
    required this.tradition,
    this.parentInterpretation,
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
    final tradColor = AppColors.traditionColor(widget.tradition.traditionId);

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
            side: BorderSide(color: tradColor, width: 1),
          ),
          title: Text(
            'Kilit Açma Yöntemi',
            style: GoogleFonts.cinzel(
              color: tradColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bu geleneği 1 Jeton harcayarak anında açabilir veya 1 kısa reklam izleyerek jetonunuzu saklayabilirsiniz.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Reklam İzle',
                style: GoogleFonts.plusJakartaSans(color: AppColors.mistGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: tradColor,
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
    final tradColor = AppColors.traditionColor(widget.tradition.traditionId);

    final success = await ref.read(dreamProvider.notifier).unlockTradition(
          widget.tradition.traditionId,
          targetInterpretation: widget.parentInterpretation,
        );

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
                color: AppColors.charcoalElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: tradColor.withValues(alpha: 0.85),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tradColor.withValues(alpha: 0.25),
                    blurRadius: 18,
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
                      color: tradColor.withValues(alpha: 0.16),
                      border: Border.all(
                        color: tradColor.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      color: tradColor,
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
                            color: tradColor,
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
    final tradColor = AppColors.traditionColor(trad.traditionId.isNotEmpty ? trad.traditionId : trad.title);
    final tradSecondaryColor = AppColors.traditionSecondaryColor(trad.traditionId.isNotEmpty ? trad.traditionId : trad.title);

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
        color: Color.alphaBlend(
          tradColor.withValues(alpha: 0.04),
          AppColors.charcoalSurface,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tradColor.withValues(alpha: isUnlocked ? 0.45 : 0.25),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kart Başlığı (Ekol Rengi Vurgulu)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tradColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tradColor.withValues(alpha: 0.35)),
                  ),
                  child: Icon(iconData, color: tradColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trad.title.toUpperCase(),
                        style: AppTheme.headingStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trad.scholar,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tradColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tradColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tradColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUnlocked ? Icons.lock_open_outlined : Icons.lock_outline,
                        size: 11,
                        color: tradColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isUnlocked ? 'AÇILDI' : 'KİLİTLİ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: tradColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: tradColor.withValues(alpha: 0.15), height: 1),

          // İçerik Alanı
          if (isUnlocked && trad.interpretation != null) ...[
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
                          color: tradColor.withValues(alpha: 0.65),
                          width: 2.5,
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

                  // Ekol Renginde Kilit Açma Butonu
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tradColor, tradSecondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: tradColor.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
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
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF090A0D)),
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
                                      color: const Color(0xFF090A0D),
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
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: const Color(0xFF090A0D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

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

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

    // Gelenek İkonu, Renk ve Arka Plan Gradyanı Belirleme
    IconData iconData = Icons.auto_awesome;
    Color accentColor = AppColors.ancientGold;
    LinearGradient cardBgGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF261D0C), Color(0xFF140F04)],
    );

    if (trad.traditionId == 'antik_akdeniz') {
      iconData = Icons.account_balance;
      accentColor = AppColors.mediterraneanSky;
      cardBgGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF071F36), Color(0xFF030D18)],
      );
    } else if (trad.traditionId == 'psikoloji') {
      iconData = Icons.psychology_outlined;
      accentColor = AppColors.subconsciousIndigo;
      cardBgGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF160F2B), Color(0xFF090614)],
      );
    } else {
      iconData = Icons.menu_book_rounded;
      accentColor = AppColors.ancientGold;
      cardBgGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF261D0C), Color(0xFF140F04)],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: cardBgGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUnlocked ? accentColor.withOpacity(0.6) : AppColors.borderSubtle,
          width: isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kart Başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trad.title.toUpperCase(),
                        style: GoogleFonts.cinzel(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppColors.textPureWhite,
                        ),
                      ),
                      Text(
                        trad.scholar,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? AppColors.ancientGold.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnlocked
                          ? AppColors.ancientGold.withOpacity(0.4)
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUnlocked ? Icons.lock_open : Icons.lock_outline,
                        size: 12,
                        color: isUnlocked ? AppColors.ancientGold : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUnlocked ? 'AÇILDI' : 'KİLİTLİ',
                        style: GoogleFonts.cinzel(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? AppColors.ancientGold : AppColors.textMuted,
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
            // Tam Yorum Metni
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                _cleanInterpretation(trad.interpretation!),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSilver,
                ),
              ),
            ),
          ] else ...[
            // Kilitli Teaser (Merak Fısıltısı) Alanı
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Merak Fısıltısı Kutusu
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🔮', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(
                              'MERAK FISILTISI (TEASER)',
                              style: GoogleFonts.cinzel(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"${trad.teaser ?? "Bu geleneğin rüyanızla ilgili gizemli bir uyarısı var..."}"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: AppColors.textPureWhite,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Eyleme Çağrı Butonu (Rewarded Ad / Unlock)
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPurple.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isLoading ? null : _handleUnlock,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: _isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      subState.isPremium
                                          ? Icons.lock_open
                                          : Icons.play_circle_outline_rounded,
                                      color: AppColors.ancientGold,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        subState.isPremium
                                            ? 'Kadim Analizi Oku (Plus ile Açık)'
                                            : subState.dreamCredits > 0
                                                ? 'Tam Analizi Oku (1 Reklam veya Jeton)'
                                                : 'Kadim Analizin Tamamını Oku (1 Kısa Reklam İzle)',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.cinzel(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                          color: AppColors.textPureWhite,
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
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => PaywallModal.show(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          'Tüm kilitleri sınırsız aç: Kadim Gezgin Plus',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.ancientGold,
                            decoration: TextDecoration.underline,
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

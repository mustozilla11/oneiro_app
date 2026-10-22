import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/subscription_service.dart';
import '../providers/user_subscription_provider.dart';

class PaywallModal extends ConsumerWidget {
  const PaywallModal({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PaywallModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(userSubscriptionProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoalBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Tutamaç (Handle)
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Rozet & Başlık
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_outlined, color: AppColors.moonlight, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      'RÜYA GÜNLÜĞÜ PLUS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.moonlight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Bilinçaltının Tüm Sayfalarını Açın',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.moonlight,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Sınırsız rüya tahlili, sıfır reklam ve doğrudan açılan tüm kadim ekoller.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.mistGrey,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // Özellikler Listesi
            _buildFeatureRow(Icons.all_inclusive, 'Sınırsız Rüya Tabiri', 'Günlük limit veya bekleme süresi olmaksızın'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.lock_open_rounded, 'Tüm Ekoller Daima Açık', 'Doğu, Antik Akdeniz ve Carl Jung çözümlemeleri'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.block, 'Sade & Reklamsız Deneyim', 'Edebi odaklanmayı bozan hiçbir reklam yok'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.chat_bubble_outline_rounded, 'Kadim Bilgeyle Diyalog', 'Rüyalarınızla ilgili tüm ayrıntıları doğrudan sorun'),

            const SizedBox(height: 28),

            // 1. Seçenek: Aylık Abonelik (39,99 TL / ay)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                HapticFeedback.lightImpact();
                final result = await SubscriptionService.instance.purchaseMonthlySubscription();
                if (result.success) {
                  await ref.read(userSubscriptionProvider.notifier).setPremium(true);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            result.success ? Icons.verified_outlined : Icons.info_outline,
                            color: AppColors.moonlight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result.message,
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.charcoalSurface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.charcoalSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.5), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Icon(Icons.bookmark_border_rounded, color: AppColors.moonlight, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Aylık Üyelik',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.moonlight,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Text(
                                  'ÖNERİLEN',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.warmSand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'İstediğiniz an iptal edilebilir',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mistGrey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '39,99 ₺',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.moonlight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 2. Seçenek: Tek Seferlik Jeton (19,99 TL)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                HapticFeedback.lightImpact();
                final result = await SubscriptionService.instance.purchaseCreditPack();
                if (result.success) {
                  await ref.read(userSubscriptionProvider.notifier).addCredits(10);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            result.success ? Icons.token_outlined : Icons.info_outline,
                            color: AppColors.moonlight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result.message,
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.charcoalSurface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.charcoalSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
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
                      child: Icon(Icons.toll_outlined, color: AppColors.moonlight, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '10 Adet Rüya Kontörü',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.moonlight,
                            ),
                          ),
                          Text(
                            'Süresi dolmaz, tek seferlik ödeme',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.mistGrey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '19,99 ₺',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.moonlight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Mevcut Bakiye: ${subState.isPremium ? "Sınırsız (Plus)" : "${subState.dreamCredits} Tabir"}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.mistGrey,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Icon(icon, color: AppColors.moonlight, size: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.moonlight,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: AppColors.mistGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

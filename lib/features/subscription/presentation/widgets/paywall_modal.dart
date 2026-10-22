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
      decoration: const BoxDecoration(
        color: AppColors.surfaceCardElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.ancientGold, width: 1.5),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Rozet & Başlık
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.ancientGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.ancientGold.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.ancientGold, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'KADİM GEZGİN PLUS',
                      style: GoogleFonts.cinzel(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: AppColors.ancientGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Bilinçaltının Tüm Kapılarını Arala',
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textPureWhite,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Günde 1 kahve parasına sınırsız kadim bilgelik, sıfır reklam ve anında açılan tüm gelenekler.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // Özellikler Listesi
            _buildFeatureRow(Icons.all_inclusive, 'Sınırsız Rüya Tabiri', 'Günlük limit veya bekleme süresi yok'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.lock_open_rounded, 'Tüm Gelenekler Daima Açık', 'Doğu, Antik Akdeniz & Jung analizi tam metin'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.block, 'Sıfır Reklam', 'Mistik atmosferi bozan hiçbir video yok'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.forum_outlined, 'Kadim Tabirciyle Sohbet', 'Rüyalarınla ilgili merak ettiğin her detayı sor'),

            const SizedBox(height: 28),

            // 1. Seçenek: Aylık Abonelik (39,99 TL / ay)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                HapticFeedback.heavyImpact();
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
                            result.success ? Icons.verified : Icons.info_outline,
                            color: result.success ? AppColors.ancientGold : AppColors.electricLavender,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result.message,
                              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.surfaceCardElevated,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: result.success ? AppColors.ancientGold : AppColors.borderSubtle),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF261D0C), Color(0xFF140F04)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.ancientGold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ancientGold.withOpacity(0.2),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.ancientGold.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, color: AppColors.ancientGold, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Aylık Abonelik',
                                style: GoogleFonts.cinzel(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPureWhite,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.ancientGold,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'EN POPÜLER',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'İstediğin an iptal et',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '39,99 ₺',
                      style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ancientGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Seçenek: Tek Seferlik Jeton (19,99 TL)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                HapticFeedback.mediumImpact();
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
                            result.success ? Icons.token : Icons.info_outline,
                            color: result.success ? AppColors.neonPurple : AppColors.electricLavender,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result.message,
                              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.surfaceCardElevated,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: result.success ? AppColors.neonPurple : AppColors.borderSubtle),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.token, color: AppColors.neonPurple, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '10 Ekstra Rüya Jetonu',
                            style: GoogleFonts.cinzel(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPureWhite,
                            ),
                          ),
                          Text(
                            'Süresi dolmaz, tek seferlik ödeme',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '19,99 ₺',
                      style: GoogleFonts.cinzel(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.electricLavender,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Mevcut Bakiye: ${subState.isPremium ? "Sınırsız (Plus)" : "${subState.dreamCredits} Jeton"}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textDim,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.neonPurple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.ancientGold, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cinzel(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPureWhite,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

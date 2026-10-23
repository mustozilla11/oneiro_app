import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/theme.dart';

class LegalService {
  LegalService._();
  static final LegalService instance = LegalService._();

  static const String privacyPolicyUrl =
      'https://mustozilla11.github.io/oneiro_app/privacy_policy.html';
  static const String termsOfUseUrl =
      'https://mustozilla11.github.io/oneiro_app/terms_of_use.html';

  /// Gizlilik Politikasını tarayıcıda açar veya çevrimdışıysa uygulama içi şık pencerede gösterir
  static Future<void> openPrivacyPolicy(BuildContext context, {String lang = 'tr'}) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(privacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      final privacyText = AppStrings.get('privacyDesc', lang);
      final disclaimerText = AppStrings.get('medicalDisclaimerDesc', lang);
      _showInAppLegalModal(
        context,
        title: AppStrings.get('privacyPolicy', lang),
        content: '$privacyText\n\n$disclaimerText',
      );
    }
  }

  /// Kullanım Koşulları (EULA)'nı açar
  static Future<void> openTermsOfUse(BuildContext context, {String lang = 'tr'}) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(termsOfUseUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      final termsText = AppStrings.get('subscriptionTermsDesc', lang);
      final disclaimerText = AppStrings.get('medicalDisclaimerDesc', lang);
      _showInAppLegalModal(
        context,
        title: AppStrings.get('termsOfUse', lang),
        content: '$termsText\n\n$disclaimerText',
      );
    }
  }

  /// Google Play Yapay Zeka Politikası (AI Content Report) gereği yanıtı bildirme penceresi
  static void showReportDialog(BuildContext context, {String? contentTag, String lang = 'tr'}) {
    HapticFeedback.lightImpact();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: AppColors.charcoalBlack,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.flag_outlined, color: Colors.orangeAccent.shade200, size: 20),
                const SizedBox(width: 10),
                Text(
                  AppStrings.get('reportContentBtn', lang),
                  style: AppTheme.headingStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.moonlight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Yapay zeka tarafından üretilen içerikte bir hata, uygunsuzluk veya yanıltıcı bilgi varsa bize iletin:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.mistGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Bildirim açıklaması (İsteğe bağlı)...',
                hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.mistGrey, fontSize: 12),
                filled: true,
                fillColor: AppColors.charcoalSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.moonlight),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      AppStrings.get('cancelBtn', lang),
                      style: GoogleFonts.plusJakartaSans(color: AppColors.mistGrey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.moonlight,
                      foregroundColor: AppColors.oledBlack,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.lightGreenAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppStrings.get('reportContentSuccess', lang),
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.charcoalElevated,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Text(
                      'Gönder',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showInAppLegalModal(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.charcoalBlack,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.headingStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.moonlight,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  content,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: AppColors.mistGrey,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.charcoalSurface,
                foregroundColor: AppColors.moonlight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class HowItWorksModal extends StatelessWidget {
  const HowItWorksModal({super.key});

  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HowItWorksModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      {
        'number': '01',
        'icon': Icons.edit_note_outlined,
        'title': 'Rüya ve Duygu Girişi',
        'subtitle': 'Bilinçaltı Vizyonu',
        'desc': 'Rüyanızı kendi kelimelerinizle deftere aktarırsınız. Sistem seçtiğiniz birincil kadim ekolü (Doğu & İslam, Antik Akdeniz, Psikoloji) kaydeder.',
      },
      {
        'number': '02',
        'icon': Icons.travel_explore_outlined,
        'title': 'Sembol ve Arketip Ayrıştırma',
        'subtitle': 'Semantik Çözümleme',
        'desc': 'Metin taranarak kilit nesneler ve Carl Jung arketipleri (Gölge, Anima, Kahraman) yalın kökleriyle tespit edilir.',
      },
      {
        'number': '03',
        'icon': Icons.auto_stories_outlined,
        'title': 'Kadim Kitaplık Taraması',
        'subtitle': 'Bin Yıllık Kaynaklar',
        'desc': 'İbn-i Sîrîn, Artemidorus ve antik Doğu tabletlerinin orijinal metinleri taranır. Sembollerinize denk gelen en isabetli kaynak paragrafları çekilir.',
      },
      {
        'number': '04',
        'icon': Icons.psychology_outlined,
        'title': 'Derinlikli Akıl Yürütme',
        'subtitle': 'Yapay Zeka Mimarisi',
        'desc': 'Uydurma tabirler yerine, çekilen kadim metinler edebi, sakin ve derin bir bilgelikle yorumlanır.',
      },
      {
        'number': '05',
        'icon': Icons.explore_outlined,
        'title': 'Bilinçaltı Aynası ve Pusula',
        'subtitle': '3 Ekolün Sentezi',
        'desc': 'Rüya; Doğu & İslam, Antik Akdeniz ve Derinlik Psikolojisi ekolleriyle mühürlenir. Gün boyu eşlik edecek içsel bir pusula sunulur.',
      },
      {
        'number': '06',
        'icon': Icons.chat_bubble_outline_rounded,
        'title': 'Kadim Bilge ile Diyalog',
        'subtitle': 'Derin Soru & Cevap',
        'desc': 'Kilitlerini açtığınız tüm kaynaklar ve rüya hafızada saklanır. Merak ettiğiniz ayrıntıları sorarak bilinçaltı yolculuğunuza devam edersiniz.',
      },
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.charcoalBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tutma Çubuğu (Drag Handle)
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Başlık Alanı
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Icon(Icons.architecture_outlined, color: AppColors.moonlight, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NASIL ÇALIŞIR?',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.moonlight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kadim Bilgelik ve Çift Motorlu Analiz Mimarisi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.mistGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.mistGrey, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.borderSubtle, height: 1),

          // Akış Şeması / Blok Diyagram
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final s = steps[index];
                final isLast = index == steps.length - 1;
                final iconData = s['icon'] as IconData;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol: Dikey Çizgi ve Düğüm (Node)
                      Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.charcoalSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Center(
                              child: Icon(
                                iconData,
                                color: AppColors.moonlight,
                                size: 16,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: AppColors.borderSubtle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Sağ: Açıklama Kartı
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.charcoalSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.borderSubtle,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    s['number'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.warmSand,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s['title'] as String,
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.moonlight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s['subtitle'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.mistGrey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s['desc'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppColors.mistGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Alt Kapat Butonu
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moonlight,
                  foregroundColor: AppColors.charcoalBlack,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'GÜNLÜĞE DÖN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppColors.charcoalBlack,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

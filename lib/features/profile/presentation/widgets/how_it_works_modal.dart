import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class HowItWorksModal extends StatelessWidget {
  const HowItWorksModal({super.key});

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
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
        'icon': '✍️',
        'title': 'Rüya ve Duygu Girişi',
        'subtitle': 'Bilinçaltı Vizyonu',
        'desc': 'Rüyanızı kendi kelimelerinizle yazarsınız. Sistem duygu frekansını ve seçtiğiniz birincil kadim ekolü (Doğu & İslam, Antik Akdeniz, Psikoloji) kaydeder.',
        'color': AppColors.neonPurple,
      },
      {
        'number': '02',
        'icon': '🔬',
        'title': 'Sembol ve Arketip Ayrıştırma',
        'subtitle': 'Yapay Zeka Analizi',
        'desc': 'Metin taranarak kilit nesneler (ör: Okul, Deniz, Anahtar) ve Carl Jung arketipleri (Gölge, Anima, Kahraman) yalın kökleriyle tespit edilir.',
        'color': const Color(0xFF00E5FF),
      },
      {
        'number': '03',
        'icon': '📜',
        'title': 'Kadim Kitaplık Taraması (RAG)',
        'subtitle': 'Bin Yıllık Kaynaklar',
        'desc': 'İbn-i Sîrîn, Artemidorus ve antik Doğu tabletlerinin orijinal metinleri taranır. Sembollerinize denk gelen en isabetli kaynak paragrafları çekilir.',
        'color': AppColors.ancientGold,
      },
      {
        'number': '04',
        'icon': '🧠',
        'title': 'Çift Motorlu Yapay Zeka',
        'subtitle': 'Google Gemini & DeepSeek',
        'desc': 'Uydurma tabirler yerine, çekilen kadim metinler yapay zeka tarafından kullanıcının ana dilinde edebi, derin ve akıcı bir bilgelikle yorumlanır.',
        'color': AppColors.electricLavender,
      },
      {
        'number': '05',
        'icon': '🌌',
        'title': 'Bilinçaltı Aynası ve Pusula',
        'subtitle': '3 Kadim Ekol Sentezi',
        'desc': 'Rüya; Doğu & İslam, Antik Akdeniz ve Derinlik Psikolojisi ekolleriyle mühürlenir. Gün boyu hatırlanacak "Günün Pusulası" aforizması sunulur.',
        'color': const Color(0xFF10B981),
      },
      {
        'number': '06',
        'icon': '𓂀',
        'title': 'Kadim Tabirci ile Canlı Sohbet',
        'subtitle': 'Derin Diyalog',
        'desc': 'Kilitlerini açtığınız tüm kaynaklar ve rüya hafızada saklanır. Tabirciye merak ettiğiniz ayrıntıları sorarak bilinçaltı yolculuğunuza devam edersiniz.',
        'color': AppColors.ancientGold,
      },
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppColors.ancientGold.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.oledBlack.withValues(alpha: 0.8),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tutma Çubuğu (Drag Handle)
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textDim.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Başlık Alanı
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.ancientGold.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Text('⚡', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ONEIRO NASIL ÇALIŞIR?',
                        style: GoogleFonts.cinzel(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppColors.textPureWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kadim Bilgelik & Hibrit Yapay Zeka Mimarisi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.electricLavender,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDim, size: 22),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final s = steps[index];
                final isLast = index == steps.length - 1;
                final color = s['color'] as Color;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol: Dikey Diyagram Çizgisi ve Düğüm (Node)
                      Column(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.oledBlack,
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                s['icon'] as String,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      color,
                                      (steps[index + 1]['color'] as Color).withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Sağ: Açıklama Kartı
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withValues(alpha: 0.25),
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
                                    style: GoogleFonts.cinzel(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s['title'] as String,
                                      style: GoogleFonts.cinzel(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPureWhite,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['subtitle'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDim,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s['desc'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.textSilver,
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
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ancientGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'ANLADIM • BİLİNÇALTINI KEŞFET',
                  style: GoogleFonts.cinzel(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
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

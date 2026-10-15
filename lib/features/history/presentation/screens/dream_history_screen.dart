import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dream/domain/models/dream_interpretation.dart';
import '../../../dream/presentation/screens/dream_result_screen.dart';

class DreamHistoryScreen extends StatelessWidget {
  const DreamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Örnek geçmiş kayıtlar (Kullanıcının geçmiş rüyaları ve sohbetleri)
    final sampleHistory = [
      {
        'title': 'Karanlık Deniz ve Altın Pusula',
        'date': '14 Ekim 2026',
        'emotion': 'Lucid ✨',
        'preview': 'Uçsuz bucaksız siyah bir denizdeydim, elimde parlayan bir pusula vardı...',
        'symbols': ['Deniz', 'Pusula', 'Yıldız'],
      },
      {
        'title': 'Eski Bir Evde Bilinmeyen Bir Kapı',
        'date': '12 Ekim 2026',
        'emotion': 'Karışık 🌀',
        'preview': 'Çocukluğumun geçtiği evin koridorunda daha önce hiç görmediğim ahşap bir kapı belirdi...',
        'symbols': ['Kapı', 'Anahtar', 'Koridor'],
      },
      {
        'title': 'Uçurum Kenarında Beyaz Bir Kuzgun',
        'date': '09 Ekim 2026',
        'emotion': 'Huzurlu 🕊️',
        'preview': 'Yüksek bir kayalıkta rüzgarı hissediyordum, yanıma beyaz tüylü bir kuş kondu...',
        'symbols': ['Kuzgun', 'Rüzgar', 'Uçurum'],
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: AppColors.ancientGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KADİM GÜNLÜK',
                        style: GoogleFonts.cinzel(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: AppColors.textPureWhite,
                        ),
                      ),
                      Text(
                        'Geçmiş rüyalarınız ve bilge sohbetleri',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Liste
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: sampleHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = sampleHistory[index];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Örnek geçmiş kaydı sonuç ekranında aç
                        final mockInterpretation = DreamInterpretation.mockFromRequest(
                          dreamText: item['preview'] as String,
                          emotion: (item['emotion'] as String).split(' ').first,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DreamResultScreen(interpretation: mockInterpretation),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['date'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.textDim,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.neonPurple.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    item['emotion'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.lightLilac,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.cinzel(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPureWhite,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['preview'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Semboller
                            Wrap(
                              spacing: 6,
                              children: (item['symbols'] as List<String>).map((sym) {
                                return Text(
                                  '#$sym',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.ancientGold.withOpacity(0.8),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

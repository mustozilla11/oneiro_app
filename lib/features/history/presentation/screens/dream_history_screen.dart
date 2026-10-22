import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../dream/domain/models/dream_interpretation.dart';
import '../../../dream/presentation/screens/dream_result_screen.dart';

class DreamHistoryScreen extends StatelessWidget {
  const DreamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;

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
                        currentUser != null
                            ? 'Bulutta mühürlenmiş rüyalarınız'
                            : 'Geçmiş rüyalarınız ve bilge sohbetleri',
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

              // Canlı Firestore Verisi veya Fallback Liste
              Expanded(
                child: currentUser == null
                    ? _buildSampleList(context)
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FirestoreService.instance.getDreamHistoryStream(currentUser.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: AppColors.ancientGold, strokeWidth: 2),
                            );
                          }

                          final dreams = snapshot.data ?? [];
                          if (dreams.isEmpty) {
                            return _buildEmptyState(context);
                          }

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: dreams.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final item = dreams[index];
                              final dreamText = item['dreamText'] as String? ?? '';
                              final subconscious = item['subconsciousAnalysis'] as String? ?? '';
                              final dateStr = item['dateString'] as String? ?? 'Yakınlarda';
                              final symbols = (item['symbols'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];

                              return _buildDreamCard(
                                context,
                                date: dateStr,
                                emotion: (item['emotion'] as String? ?? '').trim(),
                                title: symbols.isNotEmpty ? symbols.take(2).join(' & ') : 'Kadim Tabir',
                                preview: dreamText,
                                symbols: symbols,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  final baseMock = DreamInterpretation.mockFromRequest(
                                    dreamText: dreamText,
                                    emotion: 'Mistik',
                                  );
                                  final interpretation = baseMock.copyWith(
                                    freeAnalysis: FreeAnalysis(
                                      bilincaltiAynasi: subconscious.isNotEmpty ? subconscious : baseMock.freeAnalysis.bilincaltiAynasi,
                                      gununPusulasi: baseMock.freeAnalysis.gununPusulasi,
                                    ),
                                  );
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DreamResultScreen(interpretation: interpretation),
                                    ),
                                  );
                                },
                              );
                            },
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonPurple.withOpacity(0.1),
              border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
            ),
            child: const Icon(Icons.auto_stories_outlined, color: AppColors.ancientGold, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz Mühürlenmiş Bir Rüya Yok',
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPureWhite,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Gördüğünüz rüyaları ana ekranda kaleme alın, kadim bilge tabirini buluta mühürlesin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleList(BuildContext context) {
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

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: sampleHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = sampleHistory[index];
        return _buildDreamCard(
          context,
          date: item['date'] as String,
          emotion: item['emotion'] as String,
          title: item['title'] as String,
          preview: item['preview'] as String,
          symbols: item['symbols'] as List<String>,
          onTap: () {
            HapticFeedback.lightImpact();
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
        );
      },
    );
  }

  Widget _buildDreamCard(
    BuildContext context, {
    required String date,
    required String emotion,
    required String title,
    required String preview,
    required List<String> symbols,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                  date,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
                if (emotion.isNotEmpty && !emotion.toLowerCase().contains('mistik'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      emotion,
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
              title,
              style: GoogleFonts.cinzel(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPureWhite,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            if (symbols.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: symbols.map((sym) {
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
          ],
        ),
      ),
    );
  }
}

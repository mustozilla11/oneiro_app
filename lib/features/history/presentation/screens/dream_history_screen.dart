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
              // Başlık (Editorial Journal Arşivi)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.charcoalSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Icon(Icons.history_edu_outlined, color: AppColors.moonlight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÜYA ARŞİVİ',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.moonlight,
                        ),
                      ),
                      Text(
                        'Kişisel rüya günlüğünüz ve çözümlenen kayıtlar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.mistGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Canlı Firestore Verisi ve Yerel Telefon Arşivinin Kusursuz Birleşimi
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: currentUser != null
                      ? FirestoreService.instance.getDreamHistoryStream(currentUser.uid)
                      : const Stream.empty(),
                  builder: (context, snapshot) {
                    final firestoreDreams = snapshot.data ?? [];

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: FirestoreService.instance.getLocalDreams(),
                      builder: (context, localSnap) {
                        final localDreams = localSnap.data ?? [];

                        // Tekrarsız birleşim (Önce bulut, ardından yerel cihaz)
                        final allDreams = <Map<String, dynamic>>[];
                        final seenTexts = <String>{};

                        for (final d in firestoreDreams) {
                          final txt = (d['dreamText'] as String? ?? '').trim();
                          if (txt.isNotEmpty && !seenTexts.contains(txt)) {
                            seenTexts.add(txt);
                            allDreams.add(d);
                          }
                        }
                        for (final d in localDreams) {
                          final txt = (d['dreamText'] as String? ?? '').trim();
                          if (txt.isNotEmpty && !seenTexts.contains(txt)) {
                            seenTexts.add(txt);
                            allDreams.add(d);
                          }
                        }

                        if (allDreams.isEmpty) {
                          if (snapshot.connectionState == ConnectionState.waiting && currentUser != null) {
                            return const Center(
                              child: CircularProgressIndicator(color: AppColors.ancientGold, strokeWidth: 2),
                            );
                          }
                          return currentUser == null ? _buildSampleList(context) : _buildEmptyState(context);
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: allDreams.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final item = allDreams[index];
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
              color: AppColors.charcoalSurface,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Icon(Icons.auto_stories_outlined, color: AppColors.moonlight, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz Mühürlenmiş Bir Rüya Yok',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.moonlight,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Gördüğünüz rüyaları ana ekranda kaleme alın, çözümlemeler günlüğünüze mühürlensin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.mistGrey,
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
        'emotion': 'Duru Bilinç',
        'preview': 'Uçsuz bucaksız siyah bir denizdeydim, elimde parlayan bir pusula vardı...',
        'symbols': ['Deniz', 'Pusula', 'Kuzey Yıldızı'],
      },
      {
        'title': 'Eski Bir Evde Bilinmeyen Bir Kapı',
        'date': '12 Ekim 2026',
        'emotion': 'Arayış',
        'preview': 'Çocukluğumun geçtiği evin koridorunda daha önce hiç görmediğim ahşap bir kapı belirdi...',
        'symbols': ['Kapı', 'Anahtar', 'Geçmiş'],
      },
      {
        'title': 'Uçurum Kenarında Beyaz Bir Kuzgun',
        'date': '09 Ekim 2026',
        'emotion': 'Sükunet',
        'preview': 'Yüksek bir kayalıkta rüzgarı hissediyordum, yanıma beyaz tüylü bir kuş kondu...',
        'symbols': ['Kuzgun', 'Rüzgar', 'İçsel Rehber'],
      },
    ];

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: sampleHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
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
              emotion: item['emotion'] as String,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.charcoalSurface,
          borderRadius: BorderRadius.circular(16),
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
                    letterSpacing: 0.5,
                    color: AppColors.mistGrey,
                  ),
                ),
                if (emotion.isNotEmpty && !emotion.toLowerCase().contains('mistik'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      emotion,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.moonlight,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18.5,
                fontWeight: FontWeight.w700,
                color: AppColors.moonlight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.mistGrey,
                height: 1.5,
              ),
            ),
            if (symbols.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: symbols.map((sym) {
                  return Text(
                    '#$sym',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warmSand,
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

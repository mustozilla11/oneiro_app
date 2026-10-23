import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../dream/domain/models/dream_interpretation.dart';
import '../../../dream/presentation/screens/dream_result_screen.dart';

class DreamHistoryScreen extends ConsumerStatefulWidget {
  const DreamHistoryScreen({super.key});

  @override
  ConsumerState<DreamHistoryScreen> createState() => _DreamHistoryScreenState();
}

class _DreamHistoryScreenState extends ConsumerState<DreamHistoryScreen> {
  String _selectedFilter = 'all'; // 'all', 'islam_dogu', 'antik_akdeniz', 'psikoloji'

  DreamInterpretation _reconstructInterpretation(Map<String, dynamic> item) {
    final dreamText = item['dreamText'] as String? ?? '';
    final interpretationText = item['interpretation'] as String? ?? '';
    final subconscious = item['subconsciousAnalysis'] as String? ?? '';
    final warningOfDay = item['warningOfDay'] as String? ?? '';
    final primaryTitle = item['primaryTradition'] as String? ?? 'Doğu & İslam Geleneği';
    final primaryId = item['primaryTraditionId'] as String? ?? 'islam_dogu';
    final primaryScholar = item['primaryTraditionScholar'] as String? ?? 'İbn-i Sîrîn';
    final symbols = (item['symbols'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];

    final baseMock = DreamInterpretation.mockFromRequest(
      dreamText: dreamText,
      emotion: (item['emotion'] as String? ?? 'Mistik'),
      preferredTradition: primaryId,
    );

    List<TraditionAnalysisItem> lockedList = baseMock.lockedTraditions;
    final rawLockedData = item['lockedTraditionsData'] as List<dynamic>?;
    if (rawLockedData != null && rawLockedData.isNotEmpty) {
      lockedList = rawLockedData
          .map((e) => TraditionAnalysisItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return DreamInterpretation(
      id: item['id'] as String? ?? 'local_${dreamText.hashCode}',
      dreamText: dreamText,
      emotion: item['emotion'] as String? ?? 'Mistik',
      symbols: symbols.isNotEmpty ? symbols : baseMock.symbols,
      freeAnalysis: FreeAnalysis(
        bilincaltiAynasi:
            subconscious.isNotEmpty ? subconscious : baseMock.freeAnalysis.bilincaltiAynasi,
        gununPusulasi:
            warningOfDay.isNotEmpty ? warningOfDay : baseMock.freeAnalysis.gununPusulasi,
      ),
      primaryTradition: TraditionAnalysisItem(
        traditionId: primaryId,
        title: primaryTitle,
        scholar: primaryScholar,
        interpretation: interpretationText.isNotEmpty
            ? interpretationText
            : baseMock.primaryTradition.interpretation,
        isUnlocked: true,
      ),
      lockedTraditions: lockedList,
      createdAt: DateTime.now(),
    );
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    if (_selectedFilter == 'all') return true;
    final id = (item['primaryTraditionId'] as String? ?? '').toLowerCase();
    final title = (item['primaryTradition'] as String? ?? '').toLowerCase();
    if (_selectedFilter == 'islam_dogu') {
      return id == 'islam_dogu' || title.contains('doğu') || title.contains('islam') || id.isEmpty;
    } else if (_selectedFilter == 'antik_akdeniz') {
      return id == 'antik_akdeniz' || title.contains('antik') || title.contains('akdeniz');
    } else if (_selectedFilter == 'psikoloji') {
      return id == 'psikoloji' || title.contains('psikoloji') || title.contains('jung');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final currentUser = AuthService.instance.currentUser;

    final filters = [
      {'id': 'all', 'label': 'Tümü', 'color': AppColors.moonlight},
      {'id': 'islam_dogu', 'label': 'Doğu & İslam', 'color': AppColors.islamGold},
      {'id': 'antik_akdeniz', 'label': 'Antik Akdeniz', 'color': AppColors.mediterraneanBlue},
      {'id': 'psikoloji', 'label': 'Psikoloji', 'color': AppColors.psychologyPurple},
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
                      color: AppColors.charcoalSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Icon(Icons.history_edu_outlined, color: AppColors.moonlight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÜYA ARŞİVİ',
                        style: AppTheme.headingStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.moonlight,
                        ),
                      ),
                      Text(
                        'Cihazınızda ve bulutta kaydedilen tüm rüya yorumları',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.mistGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Gelenek Filtre Çipleri
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: filters.map((f) {
                    final fId = f['id'] as String;
                    final fLabel = f['label'] as String;
                    final fColor = f['color'] as Color;
                    final isSelected = _selectedFilter == fId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFilter = fId);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? fColor.withValues(alpha: 0.16)
                                : AppColors.charcoalSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? fColor.withValues(alpha: 0.65)
                                  : AppColors.borderSubtle,
                              width: isSelected ? 1.2 : 1.0,
                            ),
                          ),
                          child: Text(
                            fLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? fColor : AppColors.mistGrey,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),

              // Canlı Yerel + Bulut Arşivi (Asla bloklanmaz, anında yüklenir)
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: FirestoreService.instance.localDreamsRevision,
                  builder: (context, revision, _) {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: FirestoreService.instance.getLocalDreams(),
                      builder: (context, localSnap) {
                        final localDreams = localSnap.data ?? [];

                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: currentUser != null && !currentUser.isGuest
                              ? FirestoreService.instance.getDreamHistoryStream(currentUser.uid)
                              : const Stream.empty(),
                          builder: (context, cloudSnap) {
                            final firestoreDreams = cloudSnap.data ?? [];

                            // Tekrarsız birleşim (Önce yerel güncel kayıtlar, ardından bulut)
                            final allDreams = <Map<String, dynamic>>[];
                            final seenTexts = <String>{};

                            for (final d in localDreams) {
                              final txt = (d['dreamText'] as String? ?? '').trim();
                              if (txt.isNotEmpty && !seenTexts.contains(txt)) {
                                seenTexts.add(txt);
                                allDreams.add(d);
                              }
                            }
                            for (final d in firestoreDreams) {
                              final txt = (d['dreamText'] as String? ?? '').trim();
                              if (txt.isNotEmpty && !seenTexts.contains(txt)) {
                                seenTexts.add(txt);
                                allDreams.add(d);
                              }
                            }

                            final filteredDreams = allDreams.where(_matchesFilter).toList();

                            if (filteredDreams.isEmpty) {
                              if (localSnap.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.moonlight,
                                    strokeWidth: 2,
                                  ),
                                );
                              }
                              return _buildEmptyState(context);
                            }

                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredDreams.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final item = filteredDreams[index];
                                final dreamText = item['dreamText'] as String? ?? '';
                                final dateStr = item['dateString'] as String? ?? 'Yakınlarda';
                                final primaryTrad = item['primaryTradition'] as String? ?? 'Doğu & İslam';
                                final primaryTradId = item['primaryTraditionId'] as String? ?? primaryTrad;
                                final docId = item['id'] as String?;
                                final symbols = (item['symbols'] as List<dynamic>?)
                                        ?.map((s) => s.toString())
                                        .toList() ??
                                    [];

                                return _buildDreamCard(
                                  context,
                                  date: dateStr,
                                  traditionTitle: primaryTrad,
                                  traditionId: primaryTradId,
                                  title: symbols.isNotEmpty
                                      ? symbols.take(2).join(' & ')
                                      : 'Kadim Tabir',
                                  preview: dreamText,
                                  symbols: symbols,
                                  onDelete: () async {
                                    HapticFeedback.lightImpact();
                                    await FirestoreService.instance.deleteDream(
                                      dreamText,
                                      uid: currentUser?.uid,
                                      docId: docId,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Rüya kaydı arşivden silindi.',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        backgroundColor: AppColors.charcoalElevated,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    final interpretation = _reconstructInterpretation(item);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DreamResultScreen(interpretation: interpretation),
                                      ),
                                    );
                                  },
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
            child: Icon(Icons.auto_stories_outlined, color: AppColors.moonlight, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedFilter == 'all'
                ? 'Henüz Mühürlenmiş Bir Rüya Yok'
                : 'Bu Ekolde Kayıtlı Rüya Bulunamadı',
            style: AppTheme.headingStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.moonlight,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Gördüğünüz rüyaları ana ekranda kaleme alın, çözümlemeler otomatik olarak günlüğünüze kaydedilsin.',
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

  Widget _buildDreamCard(
    BuildContext context, {
    required String date,
    required String traditionTitle,
    required String traditionId,
    required String title,
    required String preview,
    required List<String> symbols,
    required VoidCallback onDelete,
    required VoidCallback onTap,
  }) {
    final tradColor = AppColors.traditionColor(traditionId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            tradColor.withValues(alpha: 0.03),
            AppColors.charcoalSurface,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tradColor.withValues(alpha: 0.25),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: tradColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tradColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        traditionTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: tradColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppColors.mistGrey.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTheme.headingStyle(
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
                      color: tradColor,
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

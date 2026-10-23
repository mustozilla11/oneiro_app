import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/legal/legal_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../chat/presentation/screens/dream_chat_screen.dart';
import '../../domain/models/dream_interpretation.dart';
import '../providers/dream_provider.dart';
import '../widgets/locked_tradition_card.dart';

/// Çoklu Tema ve Ekol Renkleriyle Zenginleştirilmiş Rüya Çözümleme Sayfası
class DreamResultScreen extends ConsumerStatefulWidget {
  final DreamInterpretation interpretation;

  const DreamResultScreen({
    super.key,
    required this.interpretation,
  });

  @override
  ConsumerState<DreamResultScreen> createState() => _DreamResultScreenState();
}

class _DreamResultScreenState extends ConsumerState<DreamResultScreen> {
  bool _isSaved = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.lightImpact();
    });
  }

  void _shareInterpretation(DreamInterpretation currentItem) {
    HapticFeedback.lightImpact();
    final text = '''
DreamApp | Rüya Günlüğü Çözümlemesi
━━━━━━━━━━━━━━━━━━━━━
Baskın Semboller: ${currentItem.symbols.join(', ')}

Psikolojik Anlam:
${currentItem.freeAnalysis.bilincaltiAynasi}

${currentItem.primaryTradition.title} (${currentItem.primaryTradition.scholar}):
${currentItem.primaryTradition.interpretation ?? ''}

Günün İçgörüsü:
"${currentItem.freeAnalysis.gununPusulasi}"

DreamApp ile rüyalarınızın ardındaki anlamı keşfedin.
''';
    Share.share(text);
  }

  Future<void> _saveToJournal() async {
    HapticFeedback.lightImpact();
    final currentItem = ref.read(dreamProvider).interpretation ?? widget.interpretation;
    final uid = AuthService.instance.currentUser?.uid ?? 'local_user';

    setState(() {
      _isSaved = !_isSaved;
    });

    if (_isSaved) {
      await FirestoreService.instance.saveDream(
        uid,
        dreamText: currentItem.dreamText,
        interpretation: currentItem.primaryTradition.interpretation ?? currentItem.ancientInterpretation,
        subconsciousAnalysis: currentItem.freeAnalysis.bilincaltiAynasi,
        warningOfDay: currentItem.freeAnalysis.gununPusulasi,
        primaryTradition: currentItem.primaryTradition.title,
        primaryTraditionId: currentItem.primaryTradition.traditionId,
        primaryTraditionScholar: currentItem.primaryTradition.scholar,
        lockedTraditions: currentItem.lockedTraditions.map((t) => t.title).toList(),
        lockedTraditionsData: currentItem.lockedTraditions.map((t) => t.toJson()).toList(),
        symbols: currentItem.symbols,
        emotion: currentItem.emotion,
      );
    } else {
      await FirestoreService.instance.deleteDream(currentItem.dreamText, uid: uid);
    }

    if (!mounted) return;
    final lang = ref.read(localeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved
              ? AppStrings.get('savedToJournal', lang)
              : AppStrings.get('removedFromJournal', lang),
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.charcoalElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
    );
  }

  void _navigateToChat(DreamInterpretation currentItem) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DreamChatScreen(interpretation: currentItem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final lang = ref.watch(localeProvider);
    final providerInterp = ref.watch(dreamProvider).interpretation;
    final liveInterpretation = (providerInterp != null &&
            providerInterp.dreamText == widget.interpretation.dreamText)
        ? providerInterp
        : widget.interpretation;

    final primaryTradColor = AppColors.traditionColor(
      liveInterpretation.primaryTradition.traditionId.isNotEmpty
          ? liveInterpretation.primaryTradition.traditionId
          : liveInterpretation.primaryTradition.title,
    );

    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          AppStrings.get('journalHeader', lang),
          style: AppTheme.headingStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: primaryTradColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primaryTradColor),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
              size: 20,
              color: _isSaved ? primaryTradColor : AppColors.mistGrey,
            ),
            onPressed: _saveToJournal,
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, size: 20, color: AppColors.mistGrey),
            onPressed: () => _shareInterpretation(liveInterpretation),
          ),
          IconButton(
            tooltip: AppStrings.get('reportContentBtn', lang),
            icon: Icon(Icons.flag_outlined, size: 19, color: AppColors.mistGrey),
            onPressed: () => LegalService.showReportDialog(context, contentTag: 'dream_result', lang: lang),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.traditionAmbientGradient(
            liveInterpretation.primaryTradition.traditionId.isNotEmpty
                ? liveInterpretation.primaryTradition.traditionId
                : liveInterpretation.primaryTradition.title,
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Üst Meta Bilgisi
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryTradColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${AppStrings.get('analysisRecord', lang)} • ${liveInterpretation.primaryTradition.title.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: primaryTradColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Ana Başlık
              Text(
                AppStrings.get('resultMainTitle', lang),
                style: AppTheme.headingStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.moonlight,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Kullanıcının Rüya Notu (Edebi Alıntı Bloğu)
              Container(
                padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: primaryTradColor.withValues(alpha: 0.55),
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  '"${liveInterpretation.dreamText}"',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontStyle: FontStyle.italic,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 36),
              Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 32),

              // 4. Alt Bölüm: Baskın Semboller
              _buildSectionHeader(
                title: AppStrings.get('dominantSymbols', lang),
                icon: Icons.grain_outlined,
                color: AppColors.moonlight,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: liveInterpretation.symbols.map((sym) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.charcoalSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryTradColor.withValues(alpha: 0.30),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      sym,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 36),
              Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 32),

              // 5. Alt Bölüm: Psikolojik Anlam (Bilinçaltı Moru Vurgulu)
              _buildSectionHeader(
                title: AppStrings.get('psychSummaryHeader', lang),
                icon: Icons.psychology_outlined,
                color: AppColors.psychologyPurple,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppColors.psychologyPurple.withValues(alpha: 0.05),
                    AppColors.charcoalSurface,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.psychologyPurple.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  liveInterpretation.freeAnalysis.bilincaltiAynasi,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    height: 1.85,
                    color: AppColors.textSecondary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 36),
              Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 32),

              // 6. Alt Bölüm: Birincil Kaynak Analizi (Seçili Birincil Ekol Renginde)
              _buildSectionHeader(
                title: liveInterpretation.primaryTradition.title.toUpperCase(),
                icon: Icons.auto_stories_outlined,
                color: primaryTradColor,
              ),
              const SizedBox(height: 4),
              Text(
                '${AppStrings.get('repPrefix', lang)}: ${liveInterpretation.primaryTradition.scholar}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryTradColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    primaryTradColor.withValues(alpha: 0.05),
                    AppColors.charcoalSurface,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryTradColor.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Text(
                  liveInterpretation.primaryTradition.interpretation ?? '...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    height: 1.85,
                    color: AppColors.textSecondary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 36),
              Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 32),

              // 7. Alt Bölüm: Somut Tavsiye ve Özet
              _buildSectionHeader(
                title: AppStrings.get('practicalAdviceHeader', lang),
                icon: Icons.lightbulb_outline,
                color: AppColors.islamGold,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.charcoalSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.islamGold.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Text(
                  '"${liveInterpretation.freeAnalysis.gununPusulasi}"',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                    color: AppColors.islamGold,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 36),
              Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 32),

              // 8. Alt Bölüm: Diğer Kaynak Ekoller (Locked Traditions - Her biri kendi renginde!)
              if (liveInterpretation.lockedTraditions.isNotEmpty) ...[
                _buildSectionHeader(
                  title: AppStrings.get('otherSourcesHeader', lang),
                  icon: Icons.lock_clock_outlined,
                  color: AppColors.moonlight,
                ),
                const SizedBox(height: 18),
                ...liveInterpretation.lockedTraditions.map((trad) {
                  return LockedTraditionCard(
                    key: ValueKey(trad.traditionId + (trad.isUnlocked ? '_unlocked' : '_locked')),
                    tradition: trad,
                    parentInterpretation: liveInterpretation,
                  );
                }),
              ],

              const SizedBox(height: 28),

              // 9. Rüya Yorumcusuna Soru Sor Butonu
              Container(
                decoration: BoxDecoration(
                  color: AppColors.charcoalSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryTradColor.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _navigateToChat(liveInterpretation),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            color: primaryTradColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              AppStrings.get('askInterpreterBtn', lang),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: primaryTradColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // Yasal Bilgilendirme ve Tıbbi Feragatname
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    AppStrings.get('medicalDisclaimerDesc', lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.mistGrey.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    Color? color,
  }) {
    final c = color ?? AppColors.moonlight;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: c,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTheme.headingStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c,
            ),
          ),
        ),
      ],
    );
  }
}

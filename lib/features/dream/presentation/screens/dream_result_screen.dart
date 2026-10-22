import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/presentation/screens/dream_chat_screen.dart';
import '../../domain/models/dream_interpretation.dart';
import '../providers/dream_provider.dart';
import '../widgets/locked_tradition_card.dart';

/// Minimalist ve Edebi Bir "Rüya Günlüğü (Editorial Journal)" Çözümleme Sayfası
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
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    // Yorum ekrana yüklendiğinde hafif dokunsal geri bildirim
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.lightImpact();
    });
  }

  void _shareInterpretation(DreamInterpretation currentItem) {
    HapticFeedback.lightImpact();
    final text = '''
Oneiro | Rüya Günlüğü Çözümlemesi
━━━━━━━━━━━━━━━━━━━━━
Baskın Semboller: ${currentItem.symbols.join(', ')}

Psikolojik Anlam:
${currentItem.freeAnalysis.bilincaltiAynasi}

${currentItem.primaryTradition.title} (${currentItem.primaryTradition.scholar}):
${currentItem.primaryTradition.interpretation ?? ''}

Günün İçgörüsü:
"${currentItem.freeAnalysis.gununPusulasi}"

Oneiro ile rüyalarınızın ardındaki edebi anlamı keşfedin.
''';
    Share.share(text);
  }

  void _saveToJournal() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSaved = !_isSaved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved
              ? 'Rüya günlüğünüze kaydedildi.'
              : 'Rüya günlüğünüzden çıkarıldı.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.charcoalElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
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
    final liveInterpretation = ref.watch(dreamProvider).interpretation ?? widget.interpretation;

    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        title: Text(
          'RÜYA GÜNLÜĞÜ',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: AppColors.moonlight,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
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
              color: _isSaved ? AppColors.moonlight : AppColors.mistGrey,
            ),
            onPressed: _saveToJournal,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.mistGrey),
            onPressed: () => _shareInterpretation(liveInterpretation),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Üst Meta Bilgisi (Arşivsel Günlük Başlığı)
            Text(
              'ÇÖZÜMLEME KAYDI • HİLAL 🌘',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
                color: AppColors.dimMist,
              ),
            ),
            const SizedBox(height: 10),

            // 2. Edebi Başlık
            Text(
              'Bilinçdışının Kadim Yankısı',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.w600,
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
                    color: AppColors.moonlight.withValues(alpha: 0.35),
                    width: 2,
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
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 32),

            // 4. Alt Bölüm: Baskın Semboller
            _buildSectionHeader(
              title: 'BASKIN SEMBOLLER',
              icon: Icons.grain_outlined,
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
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    sym,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 36),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 32),

            // 5. Alt Bölüm: Psikolojik Anlam (Bilinçaltı Aynası)
            _buildSectionHeader(
              title: 'PSİKOLOJİK ANLAM VE BİLİNÇALTI',
              icon: Icons.psychology_outlined,
            ),
            const SizedBox(height: 14),
            Text(
              liveInterpretation.freeAnalysis.bilincaltiAynasi,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                height: 1.85,
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 36),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 32),

            // 6. Alt Bölüm: Kadim Tabir (Birincil Ekol)
            _buildSectionHeader(
              title: liveInterpretation.primaryTradition.title.toUpperCase(),
              icon: Icons.auto_stories_outlined,
            ),
            const SizedBox(height: 4),
            Text(
              'Temsil: ${liveInterpretation.primaryTradition.scholar}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.dimMist,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              liveInterpretation.primaryTradition.interpretation ?? 'Kadim tabir hazırlanıyor.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                height: 1.85,
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 36),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 32),

            // 7. Alt Bölüm: İçgörü (Günün Pusulası)
            _buildSectionHeader(
              title: 'GÜNÜN İÇGÖRÜSÜ',
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.charcoalSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Text(
                '"${liveInterpretation.freeAnalysis.gununPusulasi}"',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 19.5,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: AppColors.warmSand,
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 36),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 32),

            // 8. Alt Bölüm: Diğer Kadim Ekoller (Locked Traditions)
            if (liveInterpretation.lockedTraditions.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'DİĞER GELENEKLER VE YANSIMALAR',
                icon: Icons.lock_clock_outlined,
              ),
              const SizedBox(height: 18),
              ...liveInterpretation.lockedTraditions.map((trad) {
                return LockedTraditionCard(
                  key: ValueKey(trad.traditionId + (trad.isUnlocked ? '_unlocked' : '_locked')),
                  tradition: trad,
                );
              }),
            ],

            const SizedBox(height: 28),

            // 9. Tabirci İle Teemmül (Edebi Soru Butonu)
            Container(
              decoration: BoxDecoration(
                color: AppColors.charcoalSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.borderMoonlight,
                  width: 1,
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
                        const Icon(
                          Icons.forum_outlined,
                          color: AppColors.moonlight,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'TABİRCİ İLE TEEMMÜL ET (SORU SOR)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: AppColors.moonlight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.moonlight,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.moonlight,
          ),
        ),
      ],
    );
  }
}

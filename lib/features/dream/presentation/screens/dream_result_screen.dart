import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/presentation/screens/dream_chat_screen.dart';
import '../../domain/models/dream_interpretation.dart';
import '../widgets/mystical_card.dart';

class DreamResultScreen extends StatefulWidget {
  final DreamInterpretation interpretation;

  const DreamResultScreen({
    super.key,
    required this.interpretation,
  });

  @override
  State<DreamResultScreen> createState() => _DreamResultScreenState();
}

class _DreamResultScreenState extends State<DreamResultScreen> {
  bool _isSaved = false;

  void _shareInterpretation() {
    HapticFeedback.lightImpact();
    final text = '''
🌙 Oneiro | Bilinçaltının Kadim Tabiri
━━━━━━━━━━━━━━━━━━━━━
🔮 Anahtar Semboller: ${widget.interpretation.symbols.join(', ')}

📜 Kadim Tabir:
${widget.interpretation.ancientInterpretation}

🧠 Bilinçaltı Analizi:
${widget.interpretation.subconsciousAnalysis}

⚡ Günün Uyarısı:
"${widget.interpretation.warningOfDay}"

Oneiro ile rüyalarının ardındaki sırrı keşfet.
''';
    Share.share(text);
  }

  void _saveToJournal() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSaved = !_isSaved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isSaved ? Icons.bookmark_added : Icons.bookmark_remove,
              color: AppColors.ancientGold,
            ),
            const SizedBox(width: 12),
            Text(
              _isSaved
                  ? 'Rüya kadim günlüğünüze mühürlendi.'
                  : 'Rüya günlüğünüzden kaldırıldı.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceCardElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderGold, width: 1),
        ),
      ),
    );
  }

  void _navigateToChat() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DreamChatScreen(interpretation: widget.interpretation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.interpretation;

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      appBar: AppBar(
        title: Text(
          'KADİM TABİR KARTI',
          style: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: AppColors.textSilver,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _isSaved ? AppColors.ancientGold : AppColors.textSilver,
            ),
            onPressed: _saveToJournal,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textSilver),
            onPressed: _shareInterpretation,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rüya Özeti & Duygu Rozeti
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.neonPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
                        ),
                        child: Text(
                          'HİS: ${item.emotion.toUpperCase()}',
                          style: GoogleFonts.cinzel(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppColors.electricLavender,
                          ),
                        ),
                      ),
                      Text(
                        'Az önce çözümlendi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"${item.dreamText}"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSilver.withOpacity(0.85),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 20),

            // 1. Anahtar Semboller Kartı
            MysticalCard(
              title: 'ANAHTAR SEMBOLLER',
              icon: Icons.vpn_key_outlined,
              accentColor: AppColors.neonPurple,
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.symbols.map((sym) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.neonPurple.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPurple.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✦', style: TextStyle(color: AppColors.ancientGold, fontSize: 10)),
                        const SizedBox(width: 6),
                        Text(
                          sym,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPureWhite,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 18),

            // 2. Kadim Tabir Kartı
            MysticalCard(
              title: 'KADİM TABİR',
              icon: Icons.menu_book_rounded,
              accentColor: AppColors.ancientGold,
              content: Text(
                item.ancientInterpretation,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSilver,
                ),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 18),

            // 3. Bilinçaltı Analizi (Psikolojik / Jung)
            MysticalCard(
              title: 'BİLİNÇALTI ANALİZİ',
              icon: Icons.psychology_outlined,
              accentColor: AppColors.lightLilac,
              content: Text(
                item.subconsciousAnalysis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSilver,
                ),
              ),
            ).animate().fadeIn(delay: 450.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 18),

            // 4. Günün Uyarısı (Altın Vurgulu Kart)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF261D0C),
                    Color(0xFF140F04),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.ancientGold.withOpacity(0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ancientGold.withOpacity(0.12),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: AppColors.ancientGold, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'GÜNÜN UYARISI',
                        style: GoogleFonts.cinzel(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppColors.ancientGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.warningOfDay,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      color: AppColors.textPureWhite,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 32),

            // "Tabirciye Soru Sor" Butonu
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonPurple.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _navigateToChat,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          color: AppColors.ancientGold,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'TABİRCİYE SORU SOR',
                          style: GoogleFonts.cinzel(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                            color: AppColors.textPureWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 750.ms, duration: 400.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

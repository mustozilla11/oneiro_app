import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/dream_provider.dart';
import '../widgets/glow_container.dart';
import 'dream_loading_screen.dart';

class DreamInputScreen extends ConsumerStatefulWidget {
  const DreamInputScreen({super.key});

  @override
  ConsumerState<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends ConsumerState<DreamInputScreen> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  final List<Map<String, String>> _emotions = const [
    {'label': 'Huzurlu', 'emoji': '🕊️'},
    {'label': 'Ürkütücü', 'emoji': '🌑'},
    {'label': 'Karışık', 'emoji': '🌀'},
    {'label': 'Lucid', 'emoji': '✨'},
    {'label': 'Romantik', 'emoji': '🌙'},
    {'label': 'Gergin', 'emoji': '⚡'},
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSolvePressed() {
    HapticFeedback.mediumImpact();

    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lütfen önce rüyanızı kaleme alın...',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
          ),
          backgroundColor: AppColors.surfaceCardElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.neonPurple, width: 1),
          ),
        ),
      );
      return;
    }

    ref.read(dreamProvider.notifier).setDreamText(text);

    // Yükleme & Reklam koordinasyon ekranına geçiş
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DreamLoadingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dreamState = ref.watch(dreamProvider);

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Üst Astral Başlık
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppColors.neonPurple.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.ancientGold, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'ONEIRO ASTRAL PORTAL',
                            style: GoogleFonts.cinzel(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                              color: AppColors.ancientGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bilinçaltının Fısıltıları',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.textPureWhite,
                        shadows: [
                          Shadow(
                            color: AppColors.neonPurple.withOpacity(0.6),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rüyanızdaki sembolleri, arketipleri ve gizli mesajları kadim bilgelikle çözün.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Geniş, kenarları hafif ışıltılı Rüya Yazma Alanı
              Text(
                'RÜYANIZI ANLATIN',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.electricLavender,
                ),
              ),
              const SizedBox(height: 10),

              GlowContainer(
                glowColor: _focusNode.hasFocus ? AppColors.neonPurple : AppColors.deepViolet,
                blurRadius: _focusNode.hasFocus ? 20 : 12,
                spreadRadius: 1,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: AppColors.surfaceInput,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 7,
                  minLines: 5,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: AppColors.textPureWhite,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dün gece ne gördünüz? Bir su kenarı, uçsuz bucaksız bir gökyüzü ya da tanıdık bir ses...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.textDim,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  onChanged: (val) {
                    ref.read(dreamProvider.notifier).setDreamText(val);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Hızlı Duygu Seçimi Çipleri
              Text(
                'RÜYADAKİ TEMEL HİS',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.electricLavender,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _emotions.map((emotion) {
                  final isSelected = dreamState.selectedEmotion == emotion['label'];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(dreamProvider.notifier).setEmotion(emotion['label']!);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.neonPurple.withOpacity(0.2)
                            : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.ancientGold
                              : AppColors.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.ancientGold.withOpacity(0.2),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emotion['emoji']!, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            emotion['label']!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppColors.textPureWhite : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 36),

              // "Tabiri Çöz" Butonu
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPurple.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _onSolvePressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: AppColors.ancientGold,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'TABİRİ ÇÖZ',
                            style: GoogleFonts.cinzel(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: AppColors.textPureWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

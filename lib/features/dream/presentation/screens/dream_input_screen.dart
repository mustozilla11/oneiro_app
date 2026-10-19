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

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
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
    final hasFocus = _focusNode.hasFocus;

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

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
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Rüyanızdaki sembolleri, arketipleri ve kadim işaretleri çözün.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Enine Geniş, Sağda-Solda Neredeyse Boşluk Bırakmayan ve Yazıldıkça Boyuna Esneyen Rüya Penceresi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RÜYANIZI ANLATIN',
                      style: GoogleFonts.cinzel(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.electricLavender,
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        final words = value.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
                        return Text(
                          '$words kelime',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Genişleyen Rüya Giriş Penceresi
              GlowContainer(
                glowColor: hasFocus ? AppColors.neonPurple : AppColors.deepViolet.withOpacity(0.6),
                blurRadius: hasFocus ? 22 : 10,
                spreadRadius: hasFocus ? 1.5 : 0.5,
                borderRadius: BorderRadius.circular(18),
                backgroundColor: AppColors.surfaceInput,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    color: AppColors.textPureWhite,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dün gece ne gördünüz? Hatırladığınız tüm mekanları, kişileri, renkleri ve sembolleri özgürce buraya yazın...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.textDim,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    ref.read(dreamProvider.notifier).setDreamText(val);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // "Tabiri Çöz" Butonu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
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
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

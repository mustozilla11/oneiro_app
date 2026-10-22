import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../subscription/presentation/providers/user_subscription_provider.dart';
import '../../../subscription/presentation/widgets/paywall_modal.dart';
import '../providers/dream_provider.dart';
import '../widgets/antigravity_dream_box.dart';
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

    final subState = ref.read(userSubscriptionProvider);
    if (!subState.canAnalyzeDream) {
      PaywallModal.show(context);
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
    final subState = ref.watch(userSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.amazonDarkSlate,
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
                    GestureDetector(
                      onTap: () => PaywallModal.show(context),
                      child: Container(
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
                    ),
                    const SizedBox(height: 10),

                    // Dinamik Kredi / Abonelik Durum Çipi (Tıklanabilir Paywall Erişimi)
                    GestureDetector(
                      onTap: () => PaywallModal.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: subState.isPremium
                              ? LinearGradient(
                                  colors: [
                                    AppColors.ancientGold.withOpacity(0.25),
                                    AppColors.neonPurple.withOpacity(0.2),
                                  ],
                                )
                              : null,
                          color: subState.isPremium ? null : AppColors.surfaceCardElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: subState.isPremium
                                ? AppColors.ancientGold
                                : AppColors.neonPurple.withOpacity(0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              subState.isPremium ? Icons.workspace_premium_rounded : Icons.stars_rounded,
                              color: subState.isPremium ? AppColors.ancientGold : AppColors.electricLavender,
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              subState.isPremium
                                  ? '👑 Kadim Üye • Sınırsız'
                                  : '✨ Kalan Kredi: ${subState.dreamCredits}  |  Günlük Hak: ${subState.hasFreeDreamToday ? 1 : 0}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: subState.isPremium ? AppColors.ancientGold : AppColors.textPureWhite,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.ancientGold, size: 10),
                          ],
                        ),
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
                        color: AppColors.amazonAmberLight,
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
                            color: AppColors.textWarmMuted,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Antigravity (Yerçekimsiz Süzülen, İçi ve Dışı Farklı, Değişen Kenarlıklı) Rüya Kutusu
              AntigravityDreamBox(
                isFocused: hasFocus,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    color: AppColors.textCreamWhite, // Sabah gözünü yakmayan ipeksi krem
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dün gece ne gördünüz? Hatırladığınız tüm mekanları, kişileri, renkleri ve sembolleri özgürce buraya yazın...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.textWarmMuted,
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

              const SizedBox(height: 22),

              // Birincil Kadim Ekol Seçimi (Kullanıcı hangi tabirin ilk ücretsiz açılacağını seçebilir)
              _buildTraditionSelector(ref.watch(dreamProvider).preferredTradition),

              const SizedBox(height: 26),

              // Parlayan Mistik "RÜYAYI TABİR ET" Butonu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6), // Canlı Eflatun
                        Color(0xFF6D28D9), // Derin Kraliyet Moru
                        Color(0xFF9333EA), // Işıltılı Ametist
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE9D5FF).withOpacity(0.7), // Parlayan lavanta çerçeve
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.55),
                        blurRadius: 22,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFFC084FC).withOpacity(0.35),
                        blurRadius: 36,
                        spreadRadius: 3,
                        offset: const Offset(0, 8),
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
                              color: AppColors.textPureWhite,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'RÜYAYI TABİR ET',
                              style: GoogleFonts.cinzel(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.2,
                                color: AppColors.textPureWhite,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFE9D5FF).withOpacity(0.8),
                                    blurRadius: 12,
                                  ),
                                ],
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

  Widget _buildTraditionSelector(String selectedTradition) {
    final traditions = [
      {
        'id': 'islam_dogu',
        'title': 'Doğu & İslam',
        'scholar': 'İbn-i Sîrîn',
        'icon': Icons.menu_book_rounded,
        'color': AppColors.ancientGold,
        'bg': const Color(0xFF261D0C),
      },
      {
        'id': 'antik_akdeniz',
        'title': 'Antik Akdeniz',
        'scholar': 'Artemidorus',
        'icon': Icons.account_balance,
        'color': AppColors.mediterraneanSky,
        'bg': const Color(0xFF071F36),
      },
      {
        'id': 'psikoloji',
        'title': 'Psikoloji',
        'scholar': 'Carl Jung',
        'icon': Icons.psychology_outlined,
        'color': AppColors.subconsciousIndigo,
        'bg': const Color(0xFF160F2B),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İLK AÇILACAK KADİM TABİR',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.amazonAmberLight,
                ),
              ),
              Text(
                '✦ Öncelikli Ekol',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ancientGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: traditions.map((t) {
            final id = t['id'] as String;
            final title = t['title'] as String;
            final scholar = t['scholar'] as String;
            final icon = t['icon'] as IconData;
            final color = t['color'] as Color;
            final bg = t['bg'] as Color;
            final isSelected = selectedTradition == id;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(dreamProvider.notifier).setPreferredTradition(id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? bg : AppColors.surfaceCardElevated.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : AppColors.borderSubtle,
                      width: isSelected ? 1.6 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? color : AppColors.textDim,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cinzel(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.textPureWhite : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scholar,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? color : AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}


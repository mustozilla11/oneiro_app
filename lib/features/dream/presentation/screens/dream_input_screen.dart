import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/theme_selector_bar.dart';
import '../../../subscription/presentation/providers/user_subscription_provider.dart';
import '../../../subscription/presentation/widgets/paywall_modal.dart';
import '../providers/dream_provider.dart';
import 'dream_loading_screen.dart';

/// Çoklu Tema ve Seçili Ekole Göre Dinamik Ambiyanslı Rüya Günlüğü Giriş Sayfası
class DreamInputScreen extends ConsumerStatefulWidget {
  const DreamInputScreen({super.key});

  @override
  ConsumerState<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends ConsumerState<DreamInputScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _textController;
  late final AnimationController _borderPulseController;
  final FocusNode _focusNode = FocusNode();
  String? _lastDraftDreamText;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _borderPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _focusNode.addListener(_onFocusChange);
    _loadDraftText();
  }

  Future<void> _loadDraftText() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_analyzed_dream_draft');
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() {
          _lastDraftDreamText = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDraftText(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_analyzed_dream_draft', text);
    } catch (_) {}
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _borderPulseController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSolvePressed() {
    HapticFeedback.lightImpact();

    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lütfen önce rüyanızı günlüğe aktarın...',
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
      return;
    }

    final subState = ref.read(userSubscriptionProvider);
    if (!subState.canAnalyzeDream) {
      PaywallModal.show(context);
      return;
    }

    ref.read(dreamProvider.notifier).setDreamText(text);

    // Rüya metnini hafızaya ve diske kaydet, yeni rüya girişi için alanı sıfırla
    _lastDraftDreamText = text;
    _saveDraftText(text);
    _textController.clear();

    // Yükleme & Reklam koordinasyon ekranına geçiş
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DreamLoadingScreen(),
      ),
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = [
      'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
      'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'
    ];
    final days = [
      'PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA', 'CUMARTESİ', 'PAZAR'
    ];
    return '${now.day} ${months[now.month - 1]} • ${days[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final subState = ref.watch(userSubscriptionProvider);
    final selectedTradition = ref.watch(dreamProvider).preferredTradition;

    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Üst Meta Veri Çubuğu (Tarih + Tam Sayfa Tema Değiştirici + Kredi)
              _buildEditorialMetaBar(subState, activeTheme),

              const SizedBox(height: 24),

              // 2. Başlık ve Rehber Cümle (Yalnızca aktif temanın renginde)
              Text(
                'Bu gece hangi eşikten geçtiniz?',
                style: AppTheme.headingStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.moonlight,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Zihninizin derinliklerinde kalan imgeleri, mekanları ve uyandığınızda hissettiğiniz yankıyı serbestçe kaleme alın.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.mistGrey,
                ),
              ),

              const SizedBox(height: 24),

              // 3. Rüya Yazma Kutusu (Sadece border rengi seçili kaynağa göre açıktan koyuya sürekli değişir)
              _buildJournalEditorCanvas(selectedTradition),

              const SizedBox(height: 28),
              Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 24),

              // 4. Öncelikli Ekol Seçimi (Doğu Altın, Akdeniz Mavi, Psikoloji Mor)
              _buildTraditionSelector(selectedTradition),

              const SizedBox(height: 32),

              // 5. Aktif Temaya Uyumlu "RÜYAYI ÇÖZÜMLE" Butonu
              _buildSubmitButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialMetaBar(
    dynamic subState,
    OneiroThemeMode activeTheme,
  ) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tarih ve Ay Fazı
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌘', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _formatCurrentDate(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppColors.mistGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tam Ekran Tema Seçiciyi Açan Hap Buton
              GestureDetector(
                onTap: () => ThemeSelectorBar.showQuickModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderMoonlight, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 13,
                        color: AppColors.moonlight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        activeTheme.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Kredi / Üyelik Göstergesi
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  PaywallModal.show(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subState.isPremium
                          ? 'KADİM PLUS'
                          : 'HAK: ${subState.dreamCredits}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.moonlight,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: AppColors.moonlight,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJournalEditorCanvas(String selectedTradition) {
    final lightBorder = AppColors.traditionLightBorderColor(selectedTradition);
    final darkBorder = AppColors.traditionDarkBorderColor(selectedTradition);
    final baseTradColor = AppColors.traditionColor(selectedTradition);

    return AnimatedBuilder(
      animation: _borderPulseController,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_borderPulseController.value);
        final pulsingBorderColor = Color.lerp(darkBorder, lightBorder, t)!;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.charcoalSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pulsingBorderColor,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: pulsingBorderColor.withValues(alpha: 0.14 * t + 0.04),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              height: 1.85,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  'Dün gece ne gördünüz? Hatırladığınız mekanları, yüzleri, renkleri ve hissettiğiniz uyanış atmosferini buraya not edin...',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: AppColors.dimMist,
                fontSize: 14.5,
                height: 1.7,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              ref.read(dreamProvider.notifier).setDreamText(val);
            },
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 12),

          // Alt Editör Kontrolleri (Kelime Sayacı & Taslak Geri Yükleme)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              final words = value.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    words > 0 ? '$words kelime kaleme alındı' : 'Rüya günlüğü hazır',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AppColors.dimMist,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value.text.isEmpty && _lastDraftDreamText != null && _lastDraftDreamText!.isNotEmpty)
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _textController.text = _lastDraftDreamText!;
                            _textController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _textController.text.length),
                            );
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              children: [
                                Icon(Icons.history_rounded, size: 13, color: baseTradColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Son Notu Getir',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: baseTradColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (value.text.isNotEmpty)
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _lastDraftDreamText = _textController.text.trim();
                            _saveDraftText(_lastDraftDreamText!);
                            _textController.clear();
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Text(
                              'Temizle',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mistGrey,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTraditionSelector(String selectedTradition) {
    final traditions = [
      {
        'id': 'islam_dogu',
        'title': 'Doğu & İslam',
        'scholar': 'İbn-i Sîrîn',
        'icon': Icons.menu_book_outlined,
        'color': AppColors.islamGold, // Kehribar / Altın
      },
      {
        'id': 'antik_akdeniz',
        'title': 'Antik Akdeniz',
        'scholar': 'Artemidorus',
        'icon': Icons.account_balance_outlined,
        'color': AppColors.mediterraneanBlue, // Akdeniz Mavisi
      },
      {
        'id': 'psikoloji',
        'title': 'Psikoloji',
        'scholar': 'Carl Jung',
        'icon': Icons.psychology_outlined,
        'color': AppColors.psychologyPurple, // Bilinçaltı Moru
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ÖNCELİKLİ KADİM BAKIŞ',
              style: AppTheme.headingStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.moonlight,
              ),
            ),
            Text(
              'İlk Açılacak Ekol',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.dimMist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: traditions.map((t) {
            final id = t['id'] as String;
            final title = t['title'] as String;
            final scholar = t['scholar'] as String;
            final icon = t['icon'] as IconData;
            final tradColor = t['color'] as Color;
            final isSelected = selectedTradition == id;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(dreamProvider.notifier).setPreferredTradition(id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? tradColor.withValues(alpha: 0.85)
                          : AppColors.borderSubtle,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? tradColor : AppColors.mistGrey,
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headingStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.textPrimary : AppColors.mistGrey,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        scholar,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? tradColor : AppColors.dimMist,
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

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.moonlight.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _onSolvePressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  color: Color(0xFF090A0D),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'RÜYAYI ÇÖZÜMLE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFF090A0D),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

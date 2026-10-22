import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../subscription/presentation/providers/user_subscription_provider.dart';
import '../../../subscription/presentation/widgets/paywall_modal.dart';
import '../providers/dream_provider.dart';
import 'dream_loading_screen.dart';

/// Minimalist, Modern ve Edebi Rüya Günlüğü (Editorial Journal) Giriş Sayfası
class DreamInputScreen extends ConsumerStatefulWidget {
  const DreamInputScreen({super.key});

  @override
  ConsumerState<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends ConsumerState<DreamInputScreen> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  String? _lastDraftDreamText;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
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
            side: const BorderSide(color: AppColors.borderSubtle, width: 1),
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
              // 1. Üst Meta Veri Çubuğu (Editorial Journal Header)
              _buildEditorialMetaBar(subState),

              const SizedBox(height: 28),

              // 2. Edebi Başlık ve Rehber Cümle
              Text(
                'Bu gece hangi eşikten geçtiniz?',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
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

              const SizedBox(height: 32),

              // 3. Kenarlıksız Lüks Not Defteri / Günlük Sayfası
              _buildJournalEditorCanvas(),

              const SizedBox(height: 32),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 28),

              // 4. Öncelikli Ekol Seçimi (Minimalist Edebi Çipler)
              _buildTraditionSelector(selectedTradition),

              const SizedBox(height: 36),

              // 5. Mat Ay Işığı "RÜYAYI ÇÖZÜMLE" Butonu
              _buildSubmitButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialMetaBar(dynamic subState) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tarih ve Ay Fazı
          Row(
            children: [
              const Text('🌘', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Text(
                _formatCurrentDate(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.mistGrey,
                ),
              ),
            ],
          ),

          // Kredi / Üyelik Göstergesi (Sade, Dikkat Dağıtmayan)
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
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppColors.moonlight,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 9,
                  color: AppColors.moonlight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalEditorCanvas() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoalSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            minLines: 9,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              height: 1.85,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Dün gece ne gördünüz? Hatırladığınız mekanları, yüzleri, renkleri ve hissettiğiniz uyanış atmosferini buraya not edin...',
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
          const Divider(color: AppColors.borderSubtle, height: 1),
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
                                const Icon(Icons.history_rounded, size: 12, color: AppColors.moonlight),
                                const SizedBox(width: 4),
                                Text(
                                  'Son Notu Getir',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.moonlight,
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
      },
      {
        'id': 'antik_akdeniz',
        'title': 'Antik Akdeniz',
        'scholar': 'Artemidorus',
        'icon': Icons.account_balance_outlined,
      },
      {
        'id': 'psikoloji',
        'title': 'Psikoloji',
        'scholar': 'Carl Jung',
        'icon': Icons.psychology_outlined,
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
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
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
            final isSelected = selectedTradition == id;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(dreamProvider.notifier).setPreferredTradition(id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.moonlight.withValues(alpha: 0.08)
                        : AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.moonlight.withValues(alpha: 0.6)
                          : AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? AppColors.moonlight : AppColors.dimMist,
                        size: 18,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? AppColors.textPrimary : AppColors.mistGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scholar,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: isSelected ? AppColors.moonlight : AppColors.dimMist,
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
        color: AppColors.moonlight,
        borderRadius: BorderRadius.circular(14),
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
                  color: AppColors.charcoalBlack,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'RÜYAYI ÇÖZÜMLE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.charcoalBlack,
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/oneiro_logo.dart';
import '../../../subscription/presentation/providers/user_subscription_provider.dart';
import '../../domain/models/dream_interpretation.dart';
import '../providers/dream_provider.dart';
import 'dream_result_screen.dart';

class DreamLoadingScreen extends ConsumerStatefulWidget {
  const DreamLoadingScreen({super.key});

  @override
  ConsumerState<DreamLoadingScreen> createState() => _DreamLoadingScreenState();
}

class _DreamLoadingScreenState extends ConsumerState<DreamLoadingScreen> {
  int _currentStepIndex = 0;
  Timer? _stepTimer;
  Timer? _safetyTimeoutTimer;
  bool _hasNavigated = false;

  final List<Map<String, String>> _progressiveSteps = const [
    {
      'category': 'SEMBOL & DUYGU ANALİZİ',
      'title': 'Rüyanızdaki anahtar semboller taranıyor...',
      'subtitle': 'Metninizdeki nesneler, olaylar ve gizli temalar ayrıştırılıyor',
      'icon': '🔍',
    },
    {
      'category': 'BİNLERCE KİTAP TARAMASI',
      'title': 'Binlerce sayfalık rüya kitapları taranıyor...',
      'subtitle': 'İbn-i Sîrîn, Nablûsî ve kadim kaynaklarda rüyanıza uygun cümleler aranıyor',
      'icon': '📚',
    },
    {
      'category': 'BİLİNÇALTI & PSİKOLOJİ',
      'title': 'Bilinçaltı ve psikoloji kaynaklarıyla eşleştiriliyor...',
      'subtitle': 'Carl Jung arketip analiziyle sembollerin zihninizdeki karşılığı çözülüyor',
      'icon': '🧠',
    },
    {
      'category': 'KİŞİYE ÖZEL TABİR',
      'title': 'Size özel rüya tabiri ve yanıt hazırlanıyor...',
      'subtitle': 'Kitaplardan toplanan anlamlar derlenerek kişiselleştirilmiş yorum oluşturuluyor',
      'icon': '✨',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startProgressiveSteps();
    _executeAnalysis();

    // 45 Saniyelik Emniyet Zaman Aşımı (Render Cold Start için)
    _safetyTimeoutTimer = Timer(const Duration(seconds: 45), () {
      debugPrint('[DreamLoadingScreen] Emniyet süresi doldu. Güvenli geçiş yapılıyor.');
      _navigateToResult();
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _safetyTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startProgressiveSteps() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (mounted) {
        setState(() {
          _currentStepIndex = (_currentStepIndex + 1) % _progressiveSteps.length;
        });
      }
    });
  }

  Future<void> _executeAnalysis() async {
    // Kullanıcının günlük hakkını veya jetonunu tüket
    ref.read(userSubscriptionProvider.notifier).consumeDreamAttempt();

    // DeepSeek + RAG Analizini Başlat
    try {
      final result = await ref.read(dreamProvider.notifier).analyzeDream();
      if (result != null && mounted) {
        // En az 2.5 saniye mistik animasyon keyfi yaşatmak için kısa pay
        await Future.delayed(const Duration(milliseconds: 1200));
        _navigateToResult(result);
      } else {
        _navigateToResult();
      }
    } catch (e) {
      debugPrint('[DreamLoadingScreen] Analiz çağrısı hatası: $e');
      _navigateToResult();
    }
  }

  void _navigateToResult([DreamInterpretation? specificResult]) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _stepTimer?.cancel();
    _safetyTimeoutTimer?.cancel();

    final state = ref.read(dreamProvider);
    final result = specificResult ??
        state.interpretation ??
        DreamInterpretation.mockFromRequest(
          dreamText: state.dreamText.isNotEmpty ? state.dreamText : 'Bilinmeyen Gizemli Rüya',
        );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, secondaryAnimation) =>
            DreamResultScreen(interpretation: result),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _progressiveSteps[_currentStepIndex];

    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minimalist Monochrome Oneiro Amblemi ve İnce Çember
              Stack(
                alignment: Alignment.center,
                children: [
                  // Dönen Dış İnce Çember
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.moonlight),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),

                  // Merkez Minimalist Oneiro Logosu (Monokrom Mod)
                  const OneiroLogo(size: 72, animate: true, monochrome: true),
                ],
              ),

              const SizedBox(height: 36),

              // Adım Rozeti (Editorial Meta Rozet)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Container(
                  key: ValueKey<String>(currentStep['category']!),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    currentStep['category']!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.moonlight,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Dinamik Başlık (Edebi Serif)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  currentStep['title']!,
                  key: ValueKey<String>(currentStep['title']!),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Alt Başlık / Net Açıklama
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  currentStep['subtitle']!,
                  key: ValueKey<String>(currentStep['subtitle']!),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.mistGrey,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Minimalist 4 Aşamalı Nokta İlerleme Çubuğu
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_progressiveSteps.length, (idx) {
                  final isActive = idx == _currentStepIndex;
                  final isDone = idx < _currentStepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 22 : 6,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.moonlight
                          : isDone
                              ? AppColors.mistGrey
                              : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

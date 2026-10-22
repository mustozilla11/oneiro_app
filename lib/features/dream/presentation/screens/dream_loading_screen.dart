import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
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
      'title': 'Kadim yazmalar ve semboller taranıyor...',
      'subtitle': 'İbn-i Sîrîn ve Doğu tabletleri aralanıyor',
      'icon': '📜',
    },
    {
      'title': 'Doğu ve Batı arketipleri karşılaştırılıyor...',
      'subtitle': 'Artemidorus ve Carl Jung hafızası taranıyor',
      'icon': '🏛️',
    },
    {
      'title': 'Bilinçaltı aynası aralanıyor...',
      'subtitle': 'Rüyanızın gizli işaretleri mühürleniyor',
      'icon': '🌌',
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
    _stepTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
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
      backgroundColor: AppColors.oledBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mistik Dönen Astral Çember
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPurple.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.ancientGold.withValues(alpha: 0.15),
                          blurRadius: 60,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // Dönen Dış İnce Çember
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonPurple),
                      backgroundColor: AppColors.ancientGold.withValues(alpha: 0.2),
                    ),
                  ),

                  // Merkez Mistik İkon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      currentStep['icon']!,
                      key: ValueKey<int>(_currentStepIndex),
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Dinamik Mistik Başlık (Aşama yazısı olmadan doğrudan başlık)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  currentStep['title']!,
                  key: ValueKey<String>(currentStep['title']!),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.textPureWhite,
                    shadows: [
                      Shadow(
                        color: AppColors.neonPurple.withValues(alpha: 0.5),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Alt Başlık / Fısıltı
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  currentStep['subtitle']!,
                  key: ValueKey<String>(currentStep['subtitle']!),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // İlerleme Çubukları (3 Aşamalı Gösterge)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (idx) {
                  final isActive = idx == _currentStepIndex;
                  final isDone = idx < _currentStepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 10,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.ancientGold
                          : isDone
                              ? AppColors.neonPurple
                              : AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.ancientGold.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
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

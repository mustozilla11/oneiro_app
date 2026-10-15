import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ads/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/dream_interpretation.dart';
import '../providers/dream_provider.dart';
import 'dream_result_screen.dart';

class DreamLoadingScreen extends ConsumerStatefulWidget {
  const DreamLoadingScreen({super.key});

  @override
  ConsumerState<DreamLoadingScreen> createState() => _DreamLoadingScreenState();
}

class _DreamLoadingScreenState extends ConsumerState<DreamLoadingScreen> {
  int _currentTipIndex = 0;
  Timer? _tipTimer;
  DreamInterpretation? _analyzedResult;
  bool _isAdDismissed = false;
  bool _hasNavigated = false;

  final List<String> _mysticalPhrases = const [
    'Kadim semboller ve bilinçaltı taranıyor...',
    'Mısır ve Mezopotamya papirüsleri çözümleniyor...',
    'Carl Jung arketipsel bilinçdışı taranıyor...',
    'Rüya frekansları astral boyuttan aktarılıyor...',
    'Günün kadim uyarısı mühürleniyor...',
  ];

  @override
  void initState() {
    super.initState();
    _startTipCycle();
    _orchestrateAnalysisAndAd();
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTipCycle() {
    _tipTimer = Timer.periodic(const Duration(milliseconds: 2800), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _mysticalPhrases.length;
        });
      }
    });
  }

  Future<void> _orchestrateAnalysisAndAd() async {
    // 1. API İstek Görevi (DeepSeek + RAG)
    final analysisFuture = ref.read(dreamProvider.notifier).analyzeDream();

    // 2. Reklam Görevi (AdMob Interstitial + 15s Fallback)
    final adCompleter = Completer<void>();
    AdService.instance.showInterstitialWithFallback(
      maxTimeout: const Duration(seconds: 15),
      onCompleted: () {
        debugPrint('[DreamLoadingScreen] Reklam tamamlandı veya fallback süresi doldu.');
        _isAdDismissed = true;
        if (!adCompleter.isCompleted) {
          adCompleter.complete();
        }
        _checkAndNavigate();
      },
    );

    // API sonucunu bekle
    try {
      _analyzedResult = await analysisFuture;
      debugPrint('[DreamLoadingScreen] API yanıtı alındı.');
      _checkAndNavigate();
    } catch (e) {
      debugPrint('[DreamLoadingScreen] Analiz hatası: $e');
      _checkAndNavigate();
    }

    // Her iki işlem de hazır olana kadar bekle
    await adCompleter.future;
    _checkAndNavigate();
  }

  void _checkAndNavigate() {
    if (!mounted || _hasNavigated) return;

    // Hem reklam tamamlandıysa (veya kapatıldıysa/timeout) hem de API sonucu hazırsa
    if (_isAdDismissed && _analyzedResult != null) {
      _hasNavigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, animation, secondaryAnimation) =>
              DreamResultScreen(interpretation: _analyzedResult!),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mistik Dönen Astral Çember & Parıldayan Rün
              Stack(
                alignment: Alignment.center,
                children: [
                  // Dış Işıltı Halkası
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPurple.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),

                  // Dönen Dış Halka
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.neonPurple.withOpacity(0.4),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .rotate(duration: 4.seconds, curve: Curves.linear),

                  // Ters Dönen İç Altın Halka
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ancientGold.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .rotate(duration: 3.seconds, curve: Curves.easeInOut),

                  // Merkezdeki Mistisizm İkonu
                  const Icon(
                    Icons.auto_awesome,
                    size: 40,
                    color: AppColors.ancientGold,
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.15, 1.15),
                        duration: 1500.ms,
                        curve: Curves.easeInOut,
                      ),
                ],
              ),

              const SizedBox(height: 48),

              // Ana Başlık
              Text(
                'KADİM BİLGELİK UYANIYOR',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: AppColors.textPureWhite,
                ),
              ),

              const SizedBox(height: 16),

              // Dinamik Değişen Mistik Cümle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _mysticalPhrases[_currentTipIndex],
                  key: ValueKey<int>(_currentTipIndex),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textSilver,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // İnce Mistik Yükleme Barı
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    backgroundColor: AppColors.surfaceCard,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPurple),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

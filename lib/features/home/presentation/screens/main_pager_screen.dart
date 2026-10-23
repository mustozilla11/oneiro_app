import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../dream/presentation/screens/dream_input_screen.dart';
import '../../../history/presentation/screens/dream_history_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainPagerScreen extends ConsumerStatefulWidget {
  const MainPagerScreen({super.key});

  @override
  ConsumerState<MainPagerScreen> createState() => _MainPagerScreenState();
}

class _MainPagerScreenState extends ConsumerState<MainPagerScreen> {
  late final PageController _pageController;
  int _currentPage = 1; // Başlangıç: 1 (Orta - Ana Rüya Giriş Ekranı)

  Timer? _hideIndicatorTimer;
  bool _isIndicatorVisible = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    // İlk açılışta 1 saniye sonra belirteci zarifçe gizle
    _startAutoHideTimer();
  }

  @override
  void dispose() {
    _hideIndicatorTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// 1 saniye boyunca sayfada hareketsiz kalınca belirteci gizleyen zamanlayıcı
  void _startAutoHideTimer() {
    _hideIndicatorTimer?.cancel();
    _hideIndicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isIndicatorVisible = false;
        });
      }
    });
  }

  /// Sayfa değiştirildiğinde veya kaydırma başladığında belirteci uyandır
  void _wakeIndicator() {
    _hideIndicatorTimer?.cancel();
    if (!_isIndicatorVisible && mounted) {
      setState(() {
        _isIndicatorVisible = true;
      });
    }
    _startAutoHideTimer();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPage = index;
    });
    _wakeIndicator();
  }

  void _goToPage(int index) {
    HapticFeedback.lightImpact();
    _wakeIndicator();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    ref.watch(localeProvider);

    // Klavye açık mı kontrolü (viewInsets.bottom > 50)
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 50;
    final shouldShowIndicator = !isKeyboardOpen && _isIndicatorVisible;

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Kaydırma hareketini dinleyip belirteci anında gösteren NotificationListener
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
                _wakeIndicator();
              }
              return false;
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              children: const [
                // Sol Sayfa: Geçmiş / Rüya Günlüğü & Sohbetler
                DreamHistoryScreen(),

                // Orta Sayfa (Ana Sayfa): Rüya Yazma Ekranı
                DreamInputScreen(),

                // Sağ Sayfa: Kullanıcı Bilgileri & Profil
                ProfileScreen(),
              ],
            ),
          ),

          // Alttaki Şık ve Küçük Nokta Belirteç:
          // 1. Klavye açılınca anında gizlenir.
          // 2. Bir sayfada 1 saniyeden uzun kalınca otomatik olarak zarifçe solar (Fade out).
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              opacity: shouldShowIndicator ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !shouldShowIndicator,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.borderSubtle.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.oledBlack.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final isActive = _currentPage == index;
                        return GestureDetector(
                          onTap: () => _goToPage(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isActive
                                  ? AppColors.moonlight
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

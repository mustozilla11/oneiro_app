import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dream/presentation/screens/dream_input_screen.dart';
import '../../../history/presentation/screens/dream_history_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainPagerScreen extends StatefulWidget {
  const MainPagerScreen({super.key});

  @override
  State<MainPagerScreen> createState() => _MainPagerScreenState();
}

class _MainPagerScreenState extends State<MainPagerScreen> {
  late final PageController _pageController;
  int _currentPage = 1; // Başlangıç: 1 (Orta - Ana Rüya Giriş Ekranı)

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPage = index;
    });
  }

  void _goToPage(int index) {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Klavye açık mı kontrolü (viewInsets.bottom > 50)
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 50;

    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 3 Sayfalı Sağa-Sola Kaydırılabilir PageView
          PageView(
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

          // Alttaki Şık ve Küçük Nokta Belirteç (Klavye açıldığında klavye üstüne binmemesi için tamamen gizlenir)
          if (!isKeyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.borderSubtle.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.oledBlack.withOpacity(0.6),
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
                        width: isActive ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF00E5FF), // Canlı Elektrik Camgöbeği
                                    Color(0xFF0091EA), // Derin Parlak Mavi
                                  ],
                                )
                              : null,
                          color: isActive ? null : AppColors.borderSubtle,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withOpacity(0.7),
                                    blurRadius: 10,
                                    spreadRadius: 1.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

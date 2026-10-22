import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Antigravity Rüya Giriş Kutusu:
/// 1. Kutu içi ve dışı farklı, derinlikli kontrast (Amazon Dark Slate & Gece Safiri).
/// 2. Değişen / akan gradyan kenarlık (Amazon Kehribar -> Şafak İndigosu).
/// 3. Yerçekimsiz süzülme (Floating levitation) animasyonu (Yazarken otomatik sabitlenir).
/// 4. Sabah uyanışında gözü yakmayan sıcak sirkadiyen aydınlatma.
class AntigravityDreamBox extends StatefulWidget {
  final Widget child;
  final bool isFocused;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const AntigravityDreamBox({
    super.key,
    required this.child,
    this.isFocused = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  State<AntigravityDreamBox> createState() => _AntigravityDreamBoxState();
}

class _AntigravityDreamBoxState extends State<AntigravityDreamBox>
    with TickerProviderStateMixin {
  late final AnimationController _floatingController;
  late final Animation<double> _floatingAnimation;

  late final AnimationController _gradientRotateController;

  @override
  void initState() {
    super.initState();

    // 1. Yerçekimsiz süzülme (3.6 saniyelik pürüzsüz nefes alma hareketi)
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _floatingAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _floatingController,
        curve: Curves.easeInOutSine,
      ),
    );

    _floatingController.repeat(reverse: true);

    // 2. Kenarlık renk akışı (Yavaş, göz yormayan 9 saniyelik dönen ışık döngüsü)
    _gradientRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AntigravityDreamBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Yazı yazarken veya odaklandığında titremeyi önlemek için süzülmeyi yumuşakça durdur
    if (widget.isFocused && !oldWidget.isFocused) {
      _floatingController.animateTo(0.5, duration: const Duration(milliseconds: 300));
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _floatingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _gradientRotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.isFocused;
    final borderWidth = isFocused ? 1.2 : 2.8;

    return AnimatedBuilder(
      animation: Listenable.merge([_floatingAnimation, _gradientRotateController]),
      builder: (context, _) {
        // Odaklıyken süzülmeyi nötrle (yazı konforu için sabit tut)
        final verticalOffset = isFocused ? 0.0 : _floatingAnimation.value;
        final rotationAngle = _gradientRotateController.value * 2 * math.pi;

        return Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: [
                // Tıklanmadığında ilgi çekici sıcak kehribar parıltısı, odaklanınca gözü yormayan yumuşak ton
                BoxShadow(
                  color: isFocused
                      ? AppColors.amazonAmber.withValues(alpha: 0.20)
                      : AppColors.amazonAmber.withValues(alpha: 0.32),
                  blurRadius: isFocused ? 18 : 24,
                  spreadRadius: isFocused ? 0.8 : 2.0,
                  offset: Offset(0, isFocused ? 4 : 6),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              // Tıklanmadığında daha kalın (2.8px) dikkat çekici gradyan çerçeve; tıklanınca inceye (1.2px) döner
              padding: EdgeInsets.all(borderWidth),
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                gradient: SweepGradient(
                  center: Alignment.center,
                  transform: GradientRotation(rotationAngle),
                  colors: const [
                    AppColors.amazonAmber,      // Amazon sıcak kehribarı
                    AppColors.amazonAmberLight, // Şafak altını
                    AppColors.dawnViolet,       // Mistik leylak
                    AppColors.dawnIndigo,       // Şafak indigosu
                    AppColors.amazonAmber,      // Döngü tamamlayıcı
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                // Kutu İçi: Dış zeminden ayrışan, sabah gözünü dinlendiren mat gece safiri
                decoration: BoxDecoration(
                  color: isFocused
                      ? AppColors.amazonBoxFocused
                      : AppColors.amazonBoxFill,
                  borderRadius: widget.borderRadius.subtract(
                    BorderRadius.all(Radius.circular(borderWidth)),
                  ),
                ),
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

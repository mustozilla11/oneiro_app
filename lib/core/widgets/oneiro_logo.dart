import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Oneiro mistik ve minimalist amblem/logo widget'ı.
///
/// Hilal (ay), kapalı rüya gözü, astral yıldız ve bilinçaltı dalgalarının
/// koyu tema üzerinde parlayan neon geçişli CustomPainter vektörel çizimidir.
class OneiroLogo extends StatefulWidget {
  final double size;
  final bool animate;
  final VoidCallback? onTap;

  const OneiroLogo({
    super.key,
    this.size = 96,
    this.animate = true,
    this.onTap,
  });

  @override
  State<OneiroLogo> createState() => _OneiroLogoState();
}

class _OneiroLogoState extends State<OneiroLogo> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _initAnimation();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(OneiroLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && _controller == null) {
      _initAnimation();
    } else if (!widget.animate && _controller != null) {
      _controller?.dispose();
      _controller = null;
      _glowAnimation = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (widget.animate && _glowAnimation != null) {
      content = AnimatedBuilder(
        animation: _glowAnimation!,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: OneiroLogoPainter(glowFactor: _glowAnimation!.value),
          );
        },
      );
    } else {
      content = CustomPaint(
        size: Size(widget.size, widget.size),
        painter: const OneiroLogoPainter(glowFactor: 1.0),
      );
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }

    return content;
  }
}

/// Oneiro 512x512 referans uzayını istenen boyuta pürüzsüz ölçekleyen CustomPainter
class OneiroLogoPainter extends CustomPainter {
  final double glowFactor;

  const OneiroLogoPainter({this.glowFactor = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // 512x512 sanal vektör koordinat düzlemine tam eşitleme
    final scale = size.width / 512.0;
    canvas.scale(scale, scale);

    const center = Offset(256, 256);

    // 1. Kozmik Arka Plan & Hâle Işıması (Ambient Nebula Glow)
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7928CA).withValues(alpha: 0.36 * glowFactor.clamp(0.5, 1.3)),
          const Color(0xFF4361EE).withValues(alpha: 0.20 * glowFactor.clamp(0.5, 1.3)),
          const Color(0xFF0F172A).withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.38, 0.68, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 240));
    canvas.drawCircle(center, 240, nebulaPaint);

    // 2. Kutsal Geometri: Yörünge Çemberleri (Astral Orbit Rings)
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        colors: [
          Color(0x80FFD166),
          Color(0x337928CA),
          Color(0x7300F5FF),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 212));

    _drawDashedCircle(canvas, center, 212, orbitPaint, dashLength: 4, spaceLength: 7);

    final innerOrbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.22);
    _drawDashedCircle(canvas, const Offset(270, 256), 168, innerOrbitPaint, dashLength: 2, spaceLength: 10);

    // 3. Büyük Astral Hilal (The Grand Astral Crescent Moon)
    final crescentPath = Path()
      ..moveTo(292, 60)
      ..cubicTo(152, 60, 64, 160, 64, 262)
      ..cubicTo(64, 364, 154, 452, 278, 452)
      ..cubicTo(316, 452, 352, 441, 382, 422)
      ..cubicTo(304, 413, 238, 368, 208, 312)
      ..cubicTo(176, 252, 186, 178, 234, 118)
      ..cubicTo(254, 94, 276, 74, 292, 60)
      ..close();

    // Dış Neon Işıma Katmanı (Bloom)
    final bloomPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.76, -1.0),
        end: Alignment(0.76, 1.0),
        colors: [
          Color(0xFF00F5FF),
          Color(0xFF3B82F6),
          Color(0xFF7928CA),
          Color(0xFFC026D3),
          Color(0xFFF59E0B),
        ],
        stops: [0.0, 0.20, 0.48, 0.78, 1.0],
      ).createShader(const Rect.fromLTWH(64, 60, 318, 392))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowFactor);
    canvas.drawPath(crescentPath, bloomPaint);

    // Hilal Ana Gövdesi (Keskin Vektör)
    final crescentPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.76, -1.0),
        end: Alignment(0.76, 1.0),
        colors: [
          Color(0xFF00F5FF),
          Color(0xFF3B82F6),
          Color(0xFF7928CA),
          Color(0xFFC026D3),
          Color(0xFFF59E0B),
        ],
        stops: [0.0, 0.20, 0.48, 0.78, 1.0],
      ).createShader(const Rect.fromLTWH(64, 60, 318, 392));
    canvas.drawPath(crescentPath, crescentPaint);

    // Hilal Üst Parlaklık Kenar Çizgisi (Gloss Rim)
    final rimPath = Path()
      ..moveTo(284, 76)
      ..cubicTo(160, 84, 82, 172, 82, 262)
      ..cubicTo(82, 344, 148, 420, 252, 438);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.32);
    canvas.drawPath(rimPath, rimPaint);

    // 4. Kapalı Rüya Gözü (The Sleeping Dream Eye)
    final eyeShader = const LinearGradient(
      colors: [
        Color(0xFF00F5FF),
        Color(0xFFA78BFA),
        Color(0xFFFFD166),
        Color(0xFFF59E0B),
      ],
      stops: [0.0, 0.30, 0.70, 1.0],
    ).createShader(const Rect.fromLTWH(230, 250, 94, 35));

    final eyelidPath = Path()
      ..moveTo(230, 250)
      ..cubicTo(255, 274, 299, 274, 324, 250);

    // Göz Hâle Işıması
    final eyeGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..shader = eyeShader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(eyelidPath, eyeGlowPaint);

    // Göz Kapağı Çizgisi
    final eyelidPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..shader = eyeShader;
    canvas.drawPath(eyelidPath, eyelidPaint);

    // Kirpik Işımaları (3 Ethereal Lashes)
    final lashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = eyeShader;

    lashPaint.strokeWidth = 2.4;
    canvas.drawLine(const Offset(250, 265), const Offset(244, 280), lashPaint);
    lashPaint.strokeWidth = 2.6;
    canvas.drawLine(const Offset(277, 268), const Offset(277, 285), lashPaint);
    lashPaint.strokeWidth = 2.4;
    canvas.drawLine(const Offset(304, 265), const Offset(310, 280), lashPaint);

    // 5. Soyut Rüya ve REM Dalgaları (Fluid Dream Waves)
    final waveShader = LinearGradient(
      colors: [
        const Color(0xFF7928CA).withValues(alpha: 0.3),
        const Color(0xFF38BDF8).withValues(alpha: 0.9),
        const Color(0xFFA855F7).withValues(alpha: 0.8),
        const Color(0xFFFFD166).withValues(alpha: 0.35),
      ],
      stops: const [0.0, 0.30, 0.70, 1.0],
    ).createShader(const Rect.fromLTWH(220, 320, 176, 50));

    final wave1 = Path()
      ..moveTo(226, 332)
      ..cubicTo(254, 314, 280, 350, 314, 332)
      ..cubicTo(342, 318, 368, 336, 394, 326);

    final wavePaint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..shader = waveShader;
    canvas.drawPath(wave1, wavePaint1);

    final wave2 = Path()
      ..moveTo(240, 360)
      ..cubicTo(266, 346, 290, 374, 322, 360)
      ..cubicTo(348, 350, 372, 364, 390, 356);

    final wavePaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..shader = waveShader;
    canvas.drawPath(wave2, wavePaint2);

    // 6. Kuzey Rüya Yıldızı / Astral Kıvılcım (The North Star ✦)
    canvas.save();
    canvas.translate(277, 164);

    // Yıldız Aurası
    final starAuraPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.32 * glowFactor)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, 16, starAuraPaint);

    // 4 Köşeli Elmas Yıldız (Diamond Star)
    final starPath = Path()
      ..moveTo(0, -24)
      ..quadraticBezierTo(0, 0, -22, 0)
      ..quadraticBezierTo(0, 0, 0, 24)
      ..quadraticBezierTo(0, 0, 22, 0)
      ..quadraticBezierTo(0, 0, 0, -24)
      ..close();

    final starShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFFFF3B0),
        Color(0xFFF59E0B),
      ],
      stops: [0.0, 0.30, 1.0],
    ).createShader(const Rect.fromLTWH(-22, -24, 44, 48));

    final starPaint = Paint()..shader = starShader;
    canvas.drawPath(starPath, starPaint);

    // Yıldız Işık Hüzmeleri (Crosshair Flares)
    final flarePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), flarePaint);
    canvas.drawLine(const Offset(0, -30), const Offset(0, 30), flarePaint);

    // Saf Çekirdek Işığı
    canvas.drawCircle(Offset.zero, 3.0, Paint()..color = Colors.white);
    canvas.restore();

    // 7. Kozmik Rüya Parıltıları (Astral Stardust Drops)
    _drawDust(canvas, const Offset(372, 170), 2.2, const Color(0xFF00F5FF), 0.85);
    _drawDust(canvas, const Offset(396, 225), 1.8, const Color(0xFFFFD166), 0.90);
    _drawDust(canvas, const Offset(350, 110), 2.0, Colors.white, 0.95);
    _drawDust(canvas, const Offset(410, 285), 2.0, const Color(0xFFE879F9), 0.80);
    _drawDust(canvas, const Offset(155, 175), 1.6, const Color(0xFF818CF8), 0.65);
    _drawDust(canvas, const Offset(140, 330), 1.8, const Color(0xFF38BDF8), 0.55);
    _drawDust(canvas, const Offset(320, 80), 1.5, const Color(0xFFFFD166), 0.70);

    canvas.restore();
  }

  void _drawDust(Canvas canvas, Offset offset, double radius, Color color, double opacity) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    canvas.drawCircle(offset, radius, paint);
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dashLength,
    required double spaceLength,
  }) {
    final circumference = 2 * math.pi * radius;
    final totalSteps = (circumference / (dashLength + spaceLength)).floor();
    final stepAngle = (2 * math.pi) / totalSteps;
    final dashAngle = stepAngle * (dashLength / (dashLength + spaceLength));

    for (int i = 0; i < totalSteps; i++) {
      final startAngle = i * stepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant OneiroLogoPainter oldDelegate) {
    return oldDelegate.glowFactor != glowFactor;
  }
}

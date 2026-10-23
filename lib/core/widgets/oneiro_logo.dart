import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DreamApp Siyah Zemin Üzerine Beyaz Kalın Harfli Minimalist Amblem/Simge Widget'ı.
class OneiroLogo extends StatelessWidget {
  final double size;
  final bool animate;
  final bool monochrome;
  final VoidCallback? onTap;

  const OneiroLogo({
    super.key,
    this.size = 96,
    this.animate = true,
    this.monochrome = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.22);

    final Widget badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'DreamApp',
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: badge,
      );
    }

    return badge;
  }
}

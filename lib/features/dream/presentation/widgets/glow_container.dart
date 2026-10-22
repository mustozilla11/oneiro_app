import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final double spreadRadius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = AppColors.neonPurple,
    this.blurRadius = 16.0,
    this.spreadRadius = 1.0,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceInput,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: glowColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.18),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

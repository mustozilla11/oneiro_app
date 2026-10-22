import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Minimalist, edebi ve kutu içine kutu gömmeyen edebi bölüm kartı
class MysticalCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget content;
  final Color? accentColor;
  final Widget? trailing;
  final bool borderless;

  const MysticalCard({
    super.key,
    required this.title,
    this.icon,
    required this.content,
    this.accentColor,
    this.trailing,
    this.borderless = false,
  });

  @override
  Widget build(BuildContext context) {
    if (borderless) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          content,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoalSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: AppColors.moonlight,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppColors.moonlight,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

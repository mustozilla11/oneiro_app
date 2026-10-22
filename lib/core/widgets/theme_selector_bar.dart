import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/theme.dart';
import '../theme/theme_provider.dart';

/// Giriş ekranında ve uygulama içinde 3 tema arasında anında geçiş sağlayan seçici bileşen
class ThemeSelectorBar extends ConsumerWidget {
  final bool compact;

  const ThemeSelectorBar({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.charcoalSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Row(
          children: OneiroThemeMode.values.map((mode) {
            final isSelected = activeTheme == mode;
            final dotColor = mode.previewPrimaryColor;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeProvider.notifier).setTheme(mode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? dotColor.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? dotColor.withValues(alpha: 0.65)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: dotColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          mode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.textPrimary : AppColors.mistGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    // Geniş Görünüm (Profil Ekranı ve Tema Seçim Modalı için)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: OneiroThemeMode.values.map((mode) {
        final isSelected = activeTheme == mode;
        final accent = mode.previewPrimaryColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(themeProvider.notifier).setTheme(mode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color.alphaBlend(accent.withValues(alpha: 0.10), AppColors.charcoalSurface)
                    : AppColors.charcoalSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? accent.withValues(alpha: 0.75) : AppColors.borderSubtle,
                  width: isSelected ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: mode.previewBgColor,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      mode.icon,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.title,
                          style: AppTheme.headingStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? accent : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mode.subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.mistGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: isSelected ? accent : AppColors.dimMist,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Ana sayfadan tek dokunuşla açılabilen hızlı tema seçici alt penceresi
  static void showQuickModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoalElevated,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dimMist.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: AppColors.moonlight, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'GÖRÜNÜM & TEMA SEÇİMİ',
                      style: AppTheme.headingStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.moonlight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Dilediğiniz atmosferi seçin; tercihiniz otomatik kaydedilir.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.mistGrey,
                  ),
                ),
                const SizedBox(height: 16),
                const ThemeSelectorBar(compact: false),
              ],
            ),
          ),
        );
      },
    );
  }
}

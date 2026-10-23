import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/theme.dart';
import '../theme/theme_provider.dart';

/// Tam Ekran Görsel Tema Seçim Sayfası ("Edebi Günlük", "Kadim Mistik", "Safir Minimal")
class ThemeSelectionScreen extends ConsumerStatefulWidget {
  final bool isInitialStartup;
  final VoidCallback? onCompleted;

  const ThemeSelectionScreen({
    super.key,
    this.isInitialStartup = false,
    this.onCompleted,
  });

  /// Herhangi bir ekrandan tam sayfa tema seçiciyi açar
  static Future<void> open(BuildContext context) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, __) => const ThemeSelectionScreen(isInitialStartup: false),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  ConsumerState<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  Map<String, dynamic> _getThemeVisualSpec(OneiroThemeMode mode) {
    switch (mode) {
      case OneiroThemeMode.editorialJournal:
        return {
          'badge': 'EDEBİ & SICAK',
          'description':
              'Derin kömür siyahı zemin üzerinde sıcak kehribar-altın vurgular ve Cormorant Garamond edebi serif yazı karakteri.',
          'swatches': const [
            Color(0xFF0A0A0C),
            Color(0xFF16181E),
            Color(0xFFE5A93C),
            Color(0xFFF5F3EF),
          ],
          'sampleQuote': '“Her rüya, gecenin karanlığında mühürlenmiş bir mektuptur.”',
        };
      case OneiroThemeMode.ancientMystic:
        return {
          'badge': 'KLASİK MİSTİK',
          'description':
              'Astral gece moru atmosfer, parlak altın & eflatun geçişler ve Cinzel antik tapınak tipografisi.',
          'swatches': const [
            Color(0xFF090612),
            Color(0xFF1E1535),
            Color(0xFFEDB545),
            Color(0xFFC77DFF),
          ],
          'sampleQuote': '“Kadim semboller bilinçaltının derinliklerinden fısıldar.”',
        };
      case OneiroThemeMode.minimalistChic:
        return {
          'badge': 'MODERN & MİNİMAL',
          'description':
              'Saf gece safiri zemin, kuzey buz mavisi & şampanya dokunuşlar ve yalın modern tipografi.',
          'swatches': const [
            Color(0xFF070B12),
            Color(0xFF151F30),
            Color(0xFF7DD3FC),
            Color(0xFFE5C17B),
          ],
          'sampleQuote': '“Sessiz zihin, berrak suyun üzerindeki ay ışığı gibidir.”',
        };
    }
  }

  Future<void> _handleConfirm(OneiroThemeMode activeTheme) async {
    HapticFeedback.mediumImpact();
    await ref.read(themeProvider.notifier).confirmInitialThemeSelection(activeTheme);
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        color: AppColors.charcoalBlack,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Üst Başlık ve Kapatma Butonu (Uygulama içinden açıldıysa)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.moonlight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.moonlight.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette_outlined, size: 14, color: AppColors.moonlight),
                          const SizedBox(width: 6),
                          Text(
                            'ATMOSFER & GÖRÜNÜM SEÇİMİ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.moonlight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isInitialStartup && Navigator.of(context).canPop())
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: AppColors.mistGrey, size: 22),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Ana Başlık
                Text(
                  'Rüya Günlüğünüzün Atmosferini Seçin',
                  style: AppTheme.headingStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bir temaya dokunarak ekranın nasıl dönüştüğünü canlı görün. Seçiminizi dilediğiniz zaman değiştirebilirsiniz.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: AppColors.mistGrey,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                // 3 Büyük Görsel Tema Kartı
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: OneiroThemeMode.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final mode = OneiroThemeMode.values[index];
                      final isSelected = activeTheme == mode;
                      final spec = _getThemeVisualSpec(mode);
                      final accent = mode.previewPrimaryColor;
                      final bg = mode.previewBgColor;
                      final swatches = spec['swatches'] as List<Color>;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(themeProvider.notifier).setTheme(mode);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? accent
                                  : accent.withValues(alpha: 0.25),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.22),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Üst Satır: İkon + Tema Başlığı + Rozet + Seçim İkonu
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.55),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Icon(
                                      mode.icon,
                                      color: accent,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                mode.title,
                                                style: AppTheme.headingStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFFF8FAFC),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: accent.withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: accent.withValues(alpha: 0.4),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                spec['badge'] as String,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.6,
                                                  color: accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          mode.subtitle,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: accent.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? accent : Colors.white38,
                                    size: 24,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Açıklama
                              Text(
                                spec['description'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFFCBD5E1),
                                  height: 1.45,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Alt Önizleme Çubuğu (Renk Paleti + Tipografi Örneği)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Renk Paleti Daireleri
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: swatches.map((c) {
                                        return Container(
                                          width: 16,
                                          height: 16,
                                          margin: const EdgeInsets.only(right: 5),
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.35),
                                              width: 1,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        spec['sampleQuote'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.cormorantGaramond(
                                          fontSize: 13.5,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Alt Onay Butonu
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.moonlight.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _handleConfirm(activeTheme),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF090A0D),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${activeTheme.title.toUpperCase()} TEMASIYLA DEVAM ET',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: const Color(0xFF090A0D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

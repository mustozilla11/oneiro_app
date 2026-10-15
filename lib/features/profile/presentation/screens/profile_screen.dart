import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSignedIn = false;
  String _userName = 'Misafir Seyyah';
  String _userEmail = 'Giriş yapılmadı';

  void _toggleGoogleSignIn() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSignedIn = !_isSignedIn;
      if (_isSignedIn) {
        _userName = 'Mustafa';
        _userEmail = 'mustafa@example.com';
      } else {
        _userName = 'Misafir Seyyah';
        _userEmail = 'Giriş yapılmadı';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSignedIn
              ? 'Google ile bağlanıldı. Rüyalarınız bulutta senkronize ediliyor.'
              : 'Oturum kapatıldı. Rüyalarınız yalnızca cihazınızda saklanacak.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPureWhite),
        ),
        backgroundColor: AppColors.surfaceCardElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.neonPurple, width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: AppColors.ancientGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASTRAL PROFİL',
                        style: GoogleFonts.cinzel(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: AppColors.textPureWhite,
                        ),
                      ),
                      Text(
                        'Kullanıcı kimliği ve bilinçaltı arşivi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Profil Kartı & Google Girişi
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isSignedIn ? AppColors.ancientGold.withOpacity(0.4) : AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.surfaceCardElevated,
                      child: Text(
                        _isSignedIn ? 'M' : '𓂀',
                        style: TextStyle(
                          fontSize: _isSignedIn ? 28 : 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ancientGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _userName,
                      style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPureWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userEmail,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Google ile Giriş Yap Butonu
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _toggleGoogleSignIn,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isSignedIn
                                ? AppColors.surfaceDark
                                : AppColors.textPureWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isSignedIn ? AppColors.borderSubtle : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_isSignedIn) ...[
                                // Google G Simgesi
                                const Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Google ile Bağlan',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ] else ...[
                                const Icon(Icons.logout_rounded, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Text(
                                  'Oturumu Kapat',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Bilinçaltı İstatistikleri
              Text(
                'BİLİNÇALTI İSTATİSTİKLERİ',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.electricLavender,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatTile('12', 'Çözülen Rüya', Icons.auto_awesome),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile('Su 🌊', 'Baskın Sembol', Icons.water_drop_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile('Gölge', 'Jungian Arketip', Icons.psychology_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile('%85', 'Lucid Frekans', Icons.insights_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Gizlilik & Veri Bilgilendirmesi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.ancientGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gizlilik & Veri Güvencesi',
                            style: GoogleFonts.cinzel(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPureWhite,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rüyalarınız mahremdir. Google yalnızca kimliğinizi doğrular; rüya metinleriniz ve tabirleriniz Google ile paylaşılmaz.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textDim,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.neonPurple, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.cinzel(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPureWhite,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

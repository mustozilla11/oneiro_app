class UserSubscriptionState {
  final bool isPremium;
  final int dreamCredits;
  final int dailyFreeDreamsUsed;
  final String lastFreeDreamDate;

  const UserSubscriptionState({
    this.isPremium = false,
    this.dreamCredits = 3, // Yeni gezginlere 3 kadim hediye jeton
    this.dailyFreeDreamsUsed = 0,
    this.lastFreeDreamDate = '',
  });

  /// Bugün kullanıcının ücretsiz 1 rüya hakkı var mı?
  bool get hasFreeDreamToday {
    if (isPremium) return true;
    final today = _getTodayDateString();
    if (lastFreeDreamDate != today) {
      return true; // Gün değişmiş, hak sıfırlanmış
    }
    return dailyFreeDreamsUsed < 1;
  }

  /// Kullanıcı analiz yapabilir mi? (Premium, günlük ücretsiz veya jetonla)
  bool get canAnalyzeDream {
    return isPremium || hasFreeDreamToday || dreamCredits > 0;
  }

  static String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  UserSubscriptionState copyWith({
    bool? isPremium,
    int? dreamCredits,
    int? dailyFreeDreamsUsed,
    String? lastFreeDreamDate,
  }) {
    return UserSubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      dreamCredits: dreamCredits ?? this.dreamCredits,
      dailyFreeDreamsUsed: dailyFreeDreamsUsed ?? this.dailyFreeDreamsUsed,
      lastFreeDreamDate: lastFreeDreamDate ?? this.lastFreeDreamDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_premium': isPremium,
      'dream_credits': dreamCredits,
      'daily_free_dreams_used': dailyFreeDreamsUsed,
      'last_free_dream_date': lastFreeDreamDate,
    };
  }

  factory UserSubscriptionState.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionState(
      isPremium: json['is_premium'] as bool? ?? false,
      dreamCredits: json['dream_credits'] as int? ?? 3,
      dailyFreeDreamsUsed: json['daily_free_dreams_used'] as int? ?? 0,
      lastFreeDreamDate: json['last_free_dream_date'] as String? ?? '',
    );
  }
}

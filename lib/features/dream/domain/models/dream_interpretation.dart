class DreamInterpretation {
  final String id;
  final String dreamText;
  final String emotion;
  final List<String> symbols;
  final String ancientInterpretation;
  final String subconsciousAnalysis;
  final String warningOfDay;
  final DateTime createdAt;

  DreamInterpretation({
    required this.id,
    required this.dreamText,
    required this.emotion,
    required this.symbols,
    required this.ancientInterpretation,
    required this.subconsciousAnalysis,
    required this.warningOfDay,
    required this.createdAt,
  });

  factory DreamInterpretation.fromJson(Map<String, dynamic> json, {String? fallbackDreamText, String? fallbackEmotion}) {
    return DreamInterpretation(
      id: json['id'] as String? ?? UniqueKey().toString(),
      dreamText: json['dream_text'] as String? ?? fallbackDreamText ?? '',
      emotion: json['emotion'] as String? ?? fallbackEmotion ?? 'Bilinmeyen',
      symbols: (json['symbols'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      ancientInterpretation: json['ancient_interpretation'] as String? ??
          json['traditional_interpretation'] as String? ??
          'Kadim kaynaklar bu sembolün derin bir ruhsal dönüşüme işaret ettiğini bildirir.',
      subconsciousAnalysis: json['subconscious_analysis'] as String? ??
          json['modern_psychology'] as String? ??
          'Bilinçaltınız bastırılmış duygularınızı rüya arketipleri üzerinden yüzeye çıkarıyor.',
      warningOfDay: json['warning_of_day'] as String? ??
          'İç sesinizi dinleyin ve acele kararlardan kaçının.',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dream_text': dreamText,
      'emotion': emotion,
      'symbols': symbols,
      'ancient_interpretation': ancientInterpretation,
      'subconscious_analysis': subconsciousAnalysis,
      'warning_of_day': warningOfDay,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Örnek / Mock Rüya Çıktısı (API kapalıyken veya testlerde kullanılır)
  factory DreamInterpretation.mockFromRequest({required String dreamText, required String emotion}) {
    return DreamInterpretation(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      dreamText: dreamText,
      emotion: emotion,
      symbols: ['Karanlık Su', 'Uçurum', 'Altın Işık', 'Kuzgun'],
      ancientInterpretation:
          'Kadim Doğu ve Mısır kaynaklarına göre suyun derinlikleri, gizlenmiş ilahi sırları ve beklenmedik bir arınmayı simgeler. '
          'Karanlıktan yükselen altın ışık, yakın zamanda sabrınızın sınanacağını ancak ardından ruhani bir aydınlanma ve ferahlığın kapınızı çalacağını fısıldar.',
      subconsciousAnalysis:
          'Carl Jung arketipsel analizine göre bu rüya, "Gölge" (Shadow) ile yüzleşme evrenizi temsil ediyor. '
          'Uçurum kenarında hissettiğiniz kontrol kaybı, uyanık hayatınızdaki bir karar eşiğinde bilinçaltınızın verdiği alarmdır. '
          'Bilinçdışınız, kontrolü bırakıp sezgilerinize güvenmeniz gerektiğini işaret ediyor.',
      warningOfDay:
          'Bugün aceleyle verilmiş taahhütlerden ve zihninizi bulandıran kalabalıklardan uzak durun. Bilinçaltınızın fısıltılarına kulak verin.',
      createdAt: DateTime.now(),
    );
  }
}
class UniqueKey {
  @override
  String toString() => DateTime.now().microsecondsSinceEpoch.toString();
}

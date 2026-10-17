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
    // Kaynaklardan veya gelen yanıttan sembolleri çıkar
    List<String> extractedSymbols = (json['symbols'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (extractedSymbols.isEmpty && json['sources_used'] is List) {
      extractedSymbols = (json['sources_used'] as List)
          .map((item) {
            if (item is Map && item['source'] != null) {
              return item['source']
                  .toString()
                  .replaceAll('.txt', '')
                  .replaceAll('.pdf', '')
                  .replaceAll('_', ' ');
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    }

    if (extractedSymbols.isEmpty) {
      extractedSymbols = ['Kadim Doğu', 'Antik Bilgelik', 'Bilinçdışı'];
    }

    final rawInterpretation = json['interpretation'] as String? ??
        json['ancient_interpretation'] as String? ??
        json['traditional_interpretation'] as String? ??
        'Kadim kaynaklar bu sembolün derin bir ruhsal dönüşüme işaret ettiğini bildirir.';

    return DreamInterpretation(
      id: json['id'] as String? ?? UniqueKey().toString(),
      dreamText: json['dream_text'] as String? ?? fallbackDreamText ?? '',
      emotion: json['emotion'] as String? ?? fallbackEmotion ?? 'Bilinmeyen',
      symbols: extractedSymbols,
      ancientInterpretation: rawInterpretation,
      subconsciousAnalysis: json['subconscious_analysis'] as String? ??
          'Carl Jung arketipsel psikolojisine göre bu rüya, bastırılmış içsel duygularınızın ve sezgilerinizin uyanışını temsil ediyor.',
      warningOfDay: json['warning_of_day'] as String? ??
          'Bugün ilk hissinize ve iç sesinize güvenin; kadim yolculuğunuzda en doğru pusula kalbinizdir.',
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

  /// Dinamik ve Zengin Mock / Lorem Üreticisi
  /// Kullanıcının yazdığı rüya metninden kelimeler ayıklayarak canlı bir analiz sunar
  factory DreamInterpretation.mockFromRequest({required String dreamText, required String emotion}) {
    // Rüya metninden anahtar kelimeler türetelim
    final words = dreamText
        .split(RegExp(r'[\s,.;!?]+'))
        .where((w) => w.length > 3)
        .take(3)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();

    final List<String> extractedSymbols = words.isNotEmpty
        ? [...words, 'Mistik Işık', 'Ayna']
        : ['Karanlık Su', 'Uçurum', 'Altın Işık', 'Kuzgun'];

    return DreamInterpretation(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      dreamText: dreamText,
      emotion: emotion,
      symbols: extractedSymbols.take(4).toList(),
      ancientInterpretation:
          'Kadim Mezopotamya ve Mısır papirüslerine göre, bu rüyada görülen "${extractedSymbols.first}" sembolü, '
          'ruhsal bir eşiği ve gizli kalmış bir haberin uyanışını müjdeler. Suyun ve gölgelerin fısıltısı, '
          'hayatınızda kapanmak üzere olan bir devrin ardından gelecek arınma ve aydınlanmayı işaret etmektedir.',
      subconsciousAnalysis:
          'Carl Jung arketipsel psikolojisine göre bu rüya, "Gölge" (Shadow) ve sezgisel benliğinizin çatışmasını yansıtıyor. '
          'Rüyanızdaki $emotion hissi, uyanık hayatınızda bastırılmış bir kararın veya ertelenmiş bir yüzleşmenin dışavurumudur. '
          'Bilinçdışınız, kontrolü mantığa bırakmak yerine iç sesinize güvenmeniz gerektiğini fısıldıyor.',
      warningOfDay:
          'Bugün aceleyle verilmiş kararlardan ve zihninizi bulandıran kalabalıklardan uzak durun. İlk sezginiz en doğru rehberinizdir.',
      createdAt: DateTime.now(),
    );
  }
}

class UniqueKey {
  @override
  String toString() => DateTime.now().microsecondsSinceEpoch.toString();
}

class FreeAnalysis {
  final String bilincaltiAynasi;
  final String gununPusulasi;

  const FreeAnalysis({
    required this.bilincaltiAynasi,
    required this.gununPusulasi,
  });

  factory FreeAnalysis.fromJson(Map<String, dynamic> json) {
    return FreeAnalysis(
      bilincaltiAynasi: json['bilincalti_aynasi'] as String? ??
          'Rüyanız derin bir içsel dönüşüm ve ruhsal arınma atmosferi taşımaktadır.',
      gununPusulasi: json['gunun_pusulasi'] as String? ??
          'İlk sezginize ve kalbinizin sessiz fısıltısına güvenin.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bilincalti_aynasi': bilincaltiAynasi,
      'gunun_pusulasi': gununPusulasi,
    };
  }
}

class TraditionAnalysisItem {
  final String traditionId;
  final String title;
  final String scholar;
  final String? teaser;
  final String? interpretation;
  final bool isUnlocked;

  const TraditionAnalysisItem({
    required this.traditionId,
    required this.title,
    required this.scholar,
    this.teaser,
    this.interpretation,
    this.isUnlocked = false,
  });

  factory TraditionAnalysisItem.fromJson(Map<String, dynamic> json) {
    return TraditionAnalysisItem(
      traditionId: json['tradition_id'] as String? ?? 'islam_dogu',
      title: json['title'] as String? ?? 'Doğu ve İslam Geleneği',
      scholar: json['scholar'] as String? ?? 'İbn-i Sîrîn & Nablusî',
      teaser: json['teaser'] as String?,
      interpretation: json['interpretation'] as String?,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
    );
  }

  TraditionAnalysisItem copyWith({
    String? traditionId,
    String? title,
    String? scholar,
    String? teaser,
    String? interpretation,
    bool? isUnlocked,
  }) {
    return TraditionAnalysisItem(
      traditionId: traditionId ?? this.traditionId,
      title: title ?? this.title,
      scholar: scholar ?? this.scholar,
      teaser: teaser ?? this.teaser,
      interpretation: interpretation ?? this.interpretation,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tradition_id': traditionId,
      'title': title,
      'scholar': scholar,
      'teaser': teaser,
      'interpretation': interpretation,
      'is_unlocked': isUnlocked,
    };
  }
}

class DreamInterpretation {
  final String id;
  final String dreamText;
  final String emotion;
  final List<String> symbols;
  final FreeAnalysis freeAnalysis;
  final TraditionAnalysisItem primaryTradition;
  final List<TraditionAnalysisItem> lockedTraditions;
  final DateTime createdAt;

  DreamInterpretation({
    required this.id,
    required this.dreamText,
    required this.emotion,
    required this.symbols,
    required this.freeAnalysis,
    required this.primaryTradition,
    required this.lockedTraditions,
    required this.createdAt,
  });

  // Geriye dönük uyumluluk getter'ları (Chat & History ekranları için)
  String get ancientInterpretation => primaryTradition.interpretation ?? 'Kadim tabir hazırlanıyor.';
  String get subconsciousAnalysis => freeAnalysis.bilincaltiAynasi;
  String get warningOfDay => freeAnalysis.gununPusulasi;
  String get interpretation => ancientInterpretation;

  DreamInterpretation copyWith({
    String? id,
    String? dreamText,
    String? emotion,
    List<String>? symbols,
    FreeAnalysis? freeAnalysis,
    TraditionAnalysisItem? primaryTradition,
    List<TraditionAnalysisItem>? lockedTraditions,
    DateTime? createdAt,
  }) {
    return DreamInterpretation(
      id: id ?? this.id,
      dreamText: dreamText ?? this.dreamText,
      emotion: emotion ?? this.emotion,
      symbols: symbols ?? this.symbols,
      freeAnalysis: freeAnalysis ?? this.freeAnalysis,
      primaryTradition: primaryTradition ?? this.primaryTradition,
      lockedTraditions: lockedTraditions ?? this.lockedTraditions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory DreamInterpretation.fromJson(
    Map<String, dynamic> json, {
    String? fallbackDreamText,
    String? fallbackEmotion,
  }) {
    // 1. Semboller
    List<String> extractedSymbols = (json['symbols'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (extractedSymbols.isEmpty) {
      extractedSymbols = ['Kadim Doğu', 'Antik Bilgelik', 'Bilinçdışı'];
    }

    // 2. Free Analysis
    FreeAnalysis freeAnalysis;
    if (json['free_analysis'] is Map<String, dynamic>) {
      freeAnalysis = FreeAnalysis.fromJson(json['free_analysis'] as Map<String, dynamic>);
    } else {
      freeAnalysis = FreeAnalysis(
        bilincaltiAynasi: json['subconscious_analysis'] as String? ??
            'Carl Jung arketipsel psikolojisine göre bu rüya, bastırılmış içsel duygularınızın ve sezgilerinizin uyanışını temsil ediyor.',
        gununPusulasi: json['warning_of_day'] as String? ??
            'Bugün ilk hissinize ve iç sesinize güvenin; en doğru pusula kalbinizdir.',
      );
    }

    // 3. Primary Tradition
    TraditionAnalysisItem primaryTradition;
    if (json['primary_tradition'] is Map<String, dynamic>) {
      primaryTradition = TraditionAnalysisItem.fromJson(json['primary_tradition'] as Map<String, dynamic>);
    } else {
      primaryTradition = TraditionAnalysisItem(
        traditionId: 'islam_dogu',
        title: 'Doğu ve İslam Geleneği',
        scholar: 'İbn-i Sîrîn & Nablusî',
        interpretation: json['interpretation'] as String? ??
            json['ancient_interpretation'] as String? ??
            'Kadim kaynaklar bu sembolün derin bir ruhsal dönüşüme ve yaklaşan hayra işaret ettiğini bildirir.',
        isUnlocked: true,
      );
    }

    // 4. Locked Traditions (Teaser'lar)
    List<TraditionAnalysisItem> lockedTraditions = [];
    if (json['locked_traditions'] is List) {
      lockedTraditions = (json['locked_traditions'] as List)
          .map((item) => TraditionAnalysisItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      // Mock / Default Teaser'lar
      lockedTraditions = [
        const TraditionAnalysisItem(
          traditionId: 'antik_akdeniz',
          title: 'Antik Akdeniz Bilgeliği',
          scholar: 'Artemidorus (Oneirocritica)',
          teaser: 'Artemidorus geleneğine göre bu rüya dünyevi bir mülk veya gizli bir borç alametidir...',
          isUnlocked: false,
        ),
        const TraditionAnalysisItem(
          traditionId: 'psikoloji',
          title: 'Derinlik Psikolojisi',
          scholar: 'Carl G. Jung & Freud',
          teaser: 'Jungian analize göre bu sembol bir düşüş değil, Anima ile bilinçdışı karşılaşma eşiğidir...',
          isUnlocked: false,
        ),
      ];
    }

    return DreamInterpretation(
      id: json['id'] as String? ?? UniqueKey().toString(),
      dreamText: json['dream_text'] as String? ?? fallbackDreamText ?? '',
      emotion: json['emotion'] as String? ?? fallbackEmotion ?? 'Mistik',
      symbols: extractedSymbols,
      freeAnalysis: freeAnalysis,
      primaryTradition: primaryTradition,
      lockedTraditions: lockedTraditions,
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
      'free_analysis': freeAnalysis.toJson(),
      'primary_tradition': primaryTradition.toJson(),
      'locked_traditions': lockedTraditions.map((t) => t.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Dinamik ve Zengin Mock / Fallback Üreticisi
  factory DreamInterpretation.mockFromRequest({
    required String dreamText,
    String? emotion,
  }) {
    final words = dreamText
        .split(RegExp(r'[\s,.;!?]+'))
        .where((w) => w.length > 3)
        .take(3)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();

    final List<String> extractedSymbols = words.isNotEmpty
        ? [...words, 'Mistik Işık', 'Ayna']
        : ['Karanlık Su', 'Uçurum', 'Altın Işık', 'Kuzgun'];

    final symbolWord = extractedSymbols.first;

    return DreamInterpretation(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      dreamText: dreamText,
      emotion: emotion ?? 'Mistik',
      symbols: extractedSymbols.take(4).toList(),
      freeAnalysis: const FreeAnalysis(
        bilincaltiAynasi:
            'Carl Jung arketipsel psikolojisine göre bu rüya, Gölge ve sezgisel benliğinizin yüzleşmesini yansıtıyor. '
            'Bilinçdışınız, kontrolü yalnızca mantığa bırakmak yerine kadim sezgilerinize kulak vermeniz gerektiğini fısıldıyor.',
        gununPusulasi:
            'Bugün zihninizi bulandıran aceleci kararlardan uzak durun; kalbinizin ilk sessiz hissi en doğru rotadır.',
      ),
      primaryTradition: TraditionAnalysisItem(
        traditionId: 'islam_dogu',
        title: 'Doğu ve İslam Geleneği',
        scholar: 'İbn-i Sîrîn & Nablusî',
        interpretation:
            'Kadim İbn-i Sîrîn yazmalarına göre, bu rüyada görülen "$symbolWord" sembolü, '
            'başlangıçta sıkıntılı görünen bir meselenin ardından gelecek selamet ve manevi mertebeye delalet eder. '
            'Rüya sahibine sabrın ardından açılacak hayırlı kapılar müjdelenmektedir.',
        isUnlocked: true,
      ),
      lockedTraditions: [
        TraditionAnalysisItem(
          traditionId: 'antik_akdeniz',
          title: 'Antik Akdeniz Bilgeliği',
          scholar: 'Artemidorus (Oneirocritica)',
          teaser: 'Artemidorus\'a göre "$symbolWord" sembolü, beklemediğiniz dünyevi bir kazancın veya gizli bir basiret sınavının habercisidir...',
          isUnlocked: false,
        ),
        const TraditionAnalysisItem(
          traditionId: 'psikoloji',
          title: 'Derinlik Psikolojisi',
          scholar: 'Carl G. Jung & Freud',
          teaser: 'Jungian psikanalize göre bu rüya, bastırdığınız bir çatışmanın Anima arketipleriyle gün yüzüne çıkma feryadıdır...',
          isUnlocked: false,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }
}

class UniqueKey {
  @override
  String toString() => DateTime.now().microsecondsSinceEpoch.toString();
}

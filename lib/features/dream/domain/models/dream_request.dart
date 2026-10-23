class DreamRequest {
  final String dreamText;
  final String emotion;
  final DateTime timestamp;
  final String preferredTradition;
  final String? userId;
  final String? language;

  DreamRequest({
    required this.dreamText,
    this.emotion = '',
    DateTime? timestamp,
    this.preferredTradition = 'islam_dogu',
    this.userId,
    this.language,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'dream_text': dreamText,
      'emotion': emotion,
      'preferred_tradition': preferredTradition,
      'timestamp': timestamp.toIso8601String(),
    };
    if (userId != null && userId!.isNotEmpty) {
      map['user_id'] = userId;
    }
    if (language != null && language!.isNotEmpty) {
      map['language'] = language;
    }
    return map;
  }
}

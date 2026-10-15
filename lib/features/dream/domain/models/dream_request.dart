class DreamRequest {
  final String dreamText;
  final String emotion;
  final DateTime timestamp;

  DreamRequest({
    required this.dreamText,
    required this.emotion,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'dream_text': dreamText,
      'emotion': emotion,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class ApiConstants {
  ApiConstants._();

  /// Geliştirme ve Test Aşaması İçin Sunucu Es Geçme (Mock) Modu
  /// True olduğunda harici FastAPI sunucusu aranmaz, anında zengin mistik tabir üretilir.
  static const bool useMockBackend = true;

  // FastAPI + DeepSeek RAG Backend Base URL (Sunucu açıldığında bağlanacak adres)
  static const String baseUrl = 'https://api.oneiro-rag.internal'; 
  static const String interpretEndpoint = '/api/v1/dreams/interpret';
  static const String chatEndpoint = '/api/v1/dreams/chat';

  // LLM derin düşünme & RAG tarama için timeout süreleri
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // DeepSeek Model Kimliği
  static const String defaultModel = 'deepseek-r1-rag';
}

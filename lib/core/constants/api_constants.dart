class ApiConstants {
  ApiConstants._();

  // FastAPI + DeepSeek RAG Backend Base URL
  // Android Emulator için 10.0.2.2, iOS / Gerçek cihaz için yerel IP veya üretim URL'si
  static const String baseUrl = 'https://api.oneiro-rag.internal'; 
  static const String interpretEndpoint = '/api/v1/dreams/interpret';
  static const String chatEndpoint = '/api/v1/dreams/chat';

  // LLM derin düşünme & RAG tarama için makul timeout süreleri
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // DeepSeek Model Kimliği
  static const String defaultModel = 'deepseek-r1-rag';
}

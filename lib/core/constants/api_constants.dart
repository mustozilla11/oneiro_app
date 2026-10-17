class ApiConstants {
  static const String baseUrl = "https://oneiro-app.onrender.com";
  static const String interpretEndpoint = "$baseUrl/interpret";
  static const String healthEndpoint = "$baseUrl/health";

  /// Canlı Render.com backend'ine bağlanmak için mock modu kapalı (false)
  static const bool useMockBackend = false;

  static const String chatEndpoint = "$baseUrl/chat";

  /// Render.com ücretsiz planı 15 dk sonra uyku moduna geçer (cold start).
  /// Sunucunun uyanıp ilk cevabı vermesi 30-50 saniye sürebileceğinden
  /// timeout sürelerini 60 ve 90 saniye olarak toleranslı ayarlıyoruz.
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 90);

  static const String defaultModel = "deepseek-chat";
}

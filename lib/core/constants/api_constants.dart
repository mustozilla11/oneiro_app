class ApiConstants {
  static const String baseUrl = "https://oneiro-app.onrender.com";
  static const String interpretEndpoint = "$baseUrl/interpret";
  static const String healthEndpoint = "$baseUrl/health";

  /// Canlı Render.com backend'ine bağlanmak için mock modu kapatıldı (false)
  /// İstenirse internet yokken test etmek için true yapılabilir.
  static const bool useMockBackend = false;

  static const String chatEndpoint = "$baseUrl/chat";
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const String defaultModel = "deepseek-chat";
}

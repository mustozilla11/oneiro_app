import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/models/chat_message.dart';

abstract class IChatRepository {
  Future<String> sendChatMessage({
    required String message,
    required String systemPromptContext,
    required List<ChatMessage> history,
  });
}

class ChatRepository implements IChatRepository {
  final DioClient _dioClient;

  ChatRepository({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient();

  @override
  Future<String> sendChatMessage({
    required String message,
    required String systemPromptContext,
    required List<ChatMessage> history,
  }) async {
    // 1. Sunucu es geçme (Mock / Test) modu kontrolü
    if (ApiConstants.useMockBackend) {
      debugPrint('[ChatRepository] Mock modu devrede: Sunucu es geçiliyor, akıllı bilge yanıtı üretiliyor.');
      await Future.delayed(const Duration(milliseconds: 600));
      return _generateMysticalFallbackReply(message);
    }

    try {
      final response = await _dioClient.dio.post(
        ApiConstants.chatEndpoint,
        data: {
          'message': message,
          'system_context': systemPromptContext,
          'history': history.map((e) => e.toJson()).toList(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map<String, dynamic>) {
          return response.data['reply'] as String? ?? 'Kadim bilgelik sessiz kaldı.';
        }
        return response.data.toString();
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          error: 'Sohbet sunucusundan beklenmeyen yanıt',
        );
      }
    } catch (e) {
      debugPrint('[ChatRepository] Çevrimdışı/Hata durumu: $e. Akıllı simülatör yanıtı üretiliyor.');
      await Future.delayed(const Duration(milliseconds: 600));
      return _generateMysticalFallbackReply(message);
    }
  }

  String _generateMysticalFallbackReply(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('ne anlama') || lower.contains('neden') || lower.contains('nasıl')) {
      return 'Bilinçaltın bu sembolü bir ayna gibi kullanıyor. Bu arayış, uyanık hayatında görmezden geldiğin ancak ruhunun çözmek istediği bir dügüme işaret eder. '
          'Rüyandaki o kritik ânı hatırladığında kalbinde hissettiğin ilk his neydi? Asıl anahtar orada saklı.';
    } else if (lower.contains('korku') || lower.contains('korktum') || lower.contains('endişe')) {
      return 'Korku, bilinçaltının henüz aydınlatamadığı odaların bekçisidir. '
          'Kadim bilgelikte korku uyandıran semboller, aslında kişinin aşması gereken sınır eşiklerini temsil eder.';
    } else {
      return 'Sorun kadim levhalarda yankılandı. Bu rüya senin sadece dün geceni değil, içindeki sezgisel kavşakları da aydınlatıyor. '
          'Zihnini serbest bırak ve rüyandaki en canlı ayrıntıya odaklan.';
    }
  }
}

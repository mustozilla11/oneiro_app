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
      await Future.delayed(const Duration(milliseconds: 1400));
      return _generateMysticalFallbackReply(message);
    }
  }

  String _generateMysticalFallbackReply(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('ne anlama') || lower.contains('neden')) {
      return 'Bilinçaltın bu sembolü bir ayna gibi kullanıyor. Sorun, dış dünyadaki bir tıkanıklığın iç aleminde yankılanmasıdır. '
          'Rüyandaki o kritik ânı hatırladığında hissettiğin ilk duygu neydi? Asıl cevap orada gizlidir.';
    } else if (lower.contains('korku') || lower.contains('korktum')) {
      return 'Korku, bilinçaltının henüz aydınlatamadığı odaların bekçisidir. '
          'Kadim gelenekte korkulan sembol, aslında sahibine güç bahşedecek olan gizli hazinedir.';
    } else {
      return 'Sorun kadim levhalarda yankılandı. Bu rüya senin sadece dün geceni değil, yakın gelecekteki sezgisel kavşaklarını da aydınlatıyor. '
          'Zihnini serbest bırak ve rüyandaki en canlı ayrıntıya odaklan.';
    }
  }
}

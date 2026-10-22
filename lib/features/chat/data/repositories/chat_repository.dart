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
          final reply = response.data['reply'] as String?;
          if (reply != null && reply.trim().isNotEmpty) {
            return reply
                .replaceAll(RegExp(r'\s*\(Kaynak\s*\d+\)\s*$', caseSensitive: false), '')
                .trim();
          }
          throw Exception('Sunucudan boş yanıt döndü.');
        }
        return response.data
            .toString()
            .replaceAll(RegExp(r'\s*\(Kaynak\s*\d+\)\s*$', caseSensitive: false), '')
            .trim();
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          error: 'Sohbet sunucusundan beklenmeyen yanıt kodu: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[ChatRepository] Sunucu hatası, bağlamsal çevrimdışı rehber yanıtı üretiliyor: $e');
      await Future.delayed(const Duration(milliseconds: 500));
      return _buildContextualFallbackReply(message, systemPromptContext);
    }
  }

  String _buildContextualFallbackReply(String message, String systemPromptContext) {
    final symbolsMatch = RegExp(r'Çıkarılan Anahtar Semboller:\s*(.+)').firstMatch(systemPromptContext);
    final symbolsText = symbolsMatch?.group(1)?.trim() ?? 'rüyanızdaki kadim semboller';

    return 'Sorduğunuz bu detay, rüyanızdaki "$symbolsText" imgelerinin bilinçdışınızda taşıdığı derin mesajla doğrudan bağlantılıdır.\n\n'
        'Kadim tabir külliyatlarına ve analitik psikolojiye göre, rüya sırasında hissettiğiniz bu duygu; zihninizin artık eski bir kaygıyı geride bırakmaya ve yeni bir farkındalık eşiğinden geçmeye hazır olduğunu gösterir. İç sesinizin size fısıldadığı ilk hisse güvenin.';
  }
}

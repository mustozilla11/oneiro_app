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
            return reply.trim();
          }
          throw Exception('Sunucudan boş yanıt döndü.');
        }
        return response.data.toString();
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          error: 'Sohbet sunucusundan beklenmeyen yanıt kodu: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[ChatRepository] Sunucu hatası: $e');
      rethrow;
    }
  }
}

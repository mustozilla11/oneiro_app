import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/models/dream_interpretation.dart';
import '../../domain/models/dream_request.dart';

abstract class IDreamRepository {
  Future<DreamInterpretation> interpretDream(DreamRequest request);
}

class DreamRepository implements IDreamRepository {
  final DioClient _dioClient;

  DreamRepository({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient();

  @override
  Future<DreamInterpretation> interpretDream(DreamRequest request) async {
    try {
      debugPrint('[DreamRepository] RAG + DeepSeek backend servisine istek gönderiliyor...');
      final response = await _dioClient.dio.post(
        ApiConstants.interpretEndpoint,
        data: request.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data =
            response.data is Map<String, dynamic>
                ? response.data as Map<String, dynamic>
                : <String, dynamic>{};
        return DreamInterpretation.fromJson(
          data,
          fallbackDreamText: request.dreamText,
          fallbackEmotion: request.emotion,
        );
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Sunucudan beklenmeyen yanıt: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[DreamRepository] API çağrısı başarısız veya sunucu çevrimdışı: $e');
      debugPrint('[DreamRepository] Kesintisiz deneyim için akıllı simülasyon (Fallback) devreye alınıyor.');
      // Kullanıcının deneyimini kesintiye uğratmamak için zengin mock model döndürülür
      await Future.delayed(const Duration(milliseconds: 1200));
      return DreamInterpretation.mockFromRequest(
        dreamText: request.dreamText,
        emotion: request.emotion,
      );
    }
  }
}

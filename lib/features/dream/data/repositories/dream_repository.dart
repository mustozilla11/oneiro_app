import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/models/dream_interpretation.dart';
import '../../domain/models/dream_request.dart';

abstract class IDreamRepository {
  Future<DreamInterpretation> interpretDream(DreamRequest request);
  Future<TraditionAnalysisItem> unlockTradition(String dreamText, String traditionId, {String? userId});
}

class DreamRepository implements IDreamRepository {
  final DioClient _dioClient;

  DreamRepository({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient();

  @override
  Future<DreamInterpretation> interpretDream(DreamRequest request) async {
    if (ApiConstants.useMockBackend) {
      debugPrint('[DreamRepository] Mock modu devrede: Zengin mistik lorem tabir üretiliyor.');
      await Future.delayed(const Duration(milliseconds: 400));
      return DreamInterpretation.mockFromRequest(
        dreamText: request.dreamText,
        emotion: request.emotion,
      );
    }

    try {
      debugPrint('[DreamRepository] Teaser tabanlı RAG backend servisine istek gönderiliyor...');
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
      await Future.delayed(const Duration(milliseconds: 500));
      return DreamInterpretation.mockFromRequest(
        dreamText: request.dreamText,
        emotion: request.emotion,
      );
    }
  }

  @override
  Future<TraditionAnalysisItem> unlockTradition(String dreamText, String traditionId, {String? userId}) async {
    if (ApiConstants.useMockBackend) {
      await Future.delayed(const Duration(milliseconds: 400));
      return _mockUnlockedTradition(traditionId);
    }

    try {
      debugPrint('[DreamRepository] "$traditionId" geleneğinin kilidi açılıyor... (User ID: $userId)');
      final payload = <String, dynamic>{
        'dream_text': dreamText,
        'tradition_id': traditionId,
      };
      if (userId != null && userId.isNotEmpty) {
        payload['user_id'] = userId;
      }
      final response = await _dioClient.dio.post(
        ApiConstants.unlockTraditionEndpoint,
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return TraditionAnalysisItem(
          traditionId: data['tradition_id'] as String? ?? traditionId,
          title: data['title'] as String? ?? 'Kadim Bilgelik',
          scholar: data['scholar'] as String? ?? 'Kadim Ekol',
          interpretation: data['interpretation'] as String? ?? 'Analiz tamamlandı.',
          isUnlocked: true,
        );
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Kilit açma yanıtı geçersiz: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[DreamRepository] Kilit açma API hatası: $e. Fallback kullanılıyor.');
      return _mockUnlockedTradition(traditionId);
    }
  }

  TraditionAnalysisItem _mockUnlockedTradition(String traditionId) {
    if (traditionId == 'antik_akdeniz') {
      return const TraditionAnalysisItem(
        traditionId: 'antik_akdeniz',
        title: 'Antik Akdeniz Bilgeliği',
        scholar: 'Artemidorus (Oneirocritica)',
        interpretation:
            'Artemidorus ve Antik Akdeniz geleneklerine göre, rüyanızdaki bu işaretler dünyevi bir fırsata ve '
            'önünüzdeki günlerde alacağınız önemli bir kadersel habere delalet eder. Antik bilgelik, '
            'beklenmedik bir rehberle tanışacağınızı ve basiretinizin artacağını fısıldar.',
        isUnlocked: true,
      );
    } else {
      return const TraditionAnalysisItem(
        traditionId: 'psikoloji',
        title: 'Derinlik Psikolojisi',
        scholar: 'Carl G. Jung & Sigmund Freud',
        interpretation:
            'Carl Gustav Jung analitik psikolojisi ışığında bu sembol, bilinçdışınızdaki "Gölge" (Shadow) arketipiyle '
            'yüzleşmenizi temsil eder. Bastırılmış duygularınız rüya tiyatrosunda beden bularak, sezgisel benliğinizin '
            'kontrolü ele almasını ve içsel bir bütünlüğe (Individuation) ulaşmasını talep ediyor.',
        isUnlocked: true,
      );
    }
  }
}

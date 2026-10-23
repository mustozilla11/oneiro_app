import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../dream/domain/models/dream_interpretation.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/models/chat_message.dart';

final chatRepositoryProvider = Provider<IChatRepository>((ref) {
  return ChatRepository();
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;
  final String? error;
  final String systemPromptContext;
  final String dreamKey;

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.error,
    this.systemPromptContext = '',
    this.dreamKey = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    String? error,
    String? systemPromptContext,
    String? dreamKey,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      error: error,
      systemPromptContext: systemPromptContext ?? this.systemPromptContext,
      dreamKey: dreamKey ?? this.dreamKey,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final IChatRepository _repository;
  final _uuid = const Uuid();

  ChatNotifier(this._repository) : super(const ChatState());

  String _computeDreamKey(DreamInterpretation interpretation) {
    final normalized = interpretation.dreamText.trim().toLowerCase();
    return 'oneiro_chat_history_${normalized.hashCode}';
  }

  Future<void> initialize(DreamInterpretation interpretation) async {
    final dreamKey = _computeDreamKey(interpretation);
    final unlockedTraditionsInfo = interpretation.lockedTraditions
        .where((t) => t.isUnlocked && t.interpretation != null)
        .map((t) => '${t.title} (${t.scholar}):\n${t.interpretation}')
        .join('\n\n');

    final systemPrompt = '''
Sen DreamApp'in 11 kaynak kitaba dayalı Rüya Yorumcususun.

KULLANICININ GÖRDÜĞÜ RÜYA:
"${interpretation.dreamText}"

RÜYANIN KAYNAK ANALİZ DETAYLARI:
- Rüyadaki Somut Semboller: ${interpretation.symbols.join(', ')}
- Psikolojik Özet: ${interpretation.freeAnalysis.bilincaltiAynasi}
- Birincil Kaynak Yorumu (${interpretation.primaryTradition.title} - ${interpretation.primaryTradition.scholar}):
${interpretation.primaryTradition.interpretation ?? interpretation.ancientInterpretation}
${unlockedTraditionsInfo.isNotEmpty ? '\n- Açılan Diğer Kaynak Yorumları:\n$unlockedTraditionsInfo' : ''}
- Somut Tavsiye: ${interpretation.freeAnalysis.gununPusulasi}

GÖREVİN VE ÜSLUBUN:
1. Kullanıcının sorularını rüyadaki somut olaylara ve nesnelere (${interpretation.symbols.join(', ')}) doğrudan değinerek yanıtla.
2. Sıradan bir yapay zeka gibi genel geçer, süslü veya anlaşılması zor kelimeler ('teemmül', 'mühür', 'kadim eşik') kullanma; kaynak kitaplardaki somut verileri açık ve net bir dille anlat.
''';

    final welcomeMessage = ChatMessage(
      id: _uuid.v4(),
      text: 'Rüyanızdaki "${interpretation.symbols.take(3).join(', ')}" sembollerini kaynak kitaplarımızdaki verilere göre inceledim. Rüyadaki bir detayı açmak veya merak ettiğiniz bir noktayı sormak ister misiniz?',
      isUser: false,
    );

    state = ChatState(
      messages: [welcomeMessage],
      systemPromptContext: systemPrompt,
      dreamKey: dreamKey,
    );

    // Kaydedilmiş geçmiş sohbet mesajlarını yükle
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(dreamKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedJson) as List<dynamic>;
        final loadedMessages = decoded
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (loadedMessages.isNotEmpty && mounted) {
          state = state.copyWith(messages: loadedMessages);
        }
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Sohbet geçmişi yükleme uyarısı: $e');
    }
  }

  Future<void> _persistMessages(List<ChatMessage> messages) async {
    if (state.dreamKey.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
      await prefs.setString(state.dreamKey, encoded);
    } catch (e) {
      debugPrint('[ChatNotifier] Sohbet geçmişi kaydetme uyarısı: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: trimmed,
      isUser: true,
    );

    final updatedWithUser = [...state.messages, userMessage];
    state = state.copyWith(
      messages: updatedWithUser,
      isTyping: true,
      error: null,
    );
    await _persistMessages(updatedWithUser);

    try {
      final replyText = await _repository.sendChatMessage(
        message: trimmed,
        systemPromptContext: state.systemPromptContext,
        history: state.messages,
      );

      final botMessage = ChatMessage(
        id: _uuid.v4(),
        text: replyText,
        isUser: false,
      );

      final updatedWithBot = [...state.messages, botMessage];
      state = state.copyWith(
        messages: updatedWithBot,
        isTyping: false,
      );
      await _persistMessages(updatedWithBot);
    } catch (e) {
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        text: '⚠️ Kadim rehberle bağlantı kurulamadı. Sunucuya ulaşılamadı veya bir hata oluştu, lütfen tekrar deneyiniz.',
        isUser: false,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isTyping: false,
        error: 'Cevap alınamadı: $e',
      );
    }
  }
}

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repository);
});

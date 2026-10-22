import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.error,
    this.systemPromptContext = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    String? error,
    String? systemPromptContext,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      error: error,
      systemPromptContext: systemPromptContext ?? this.systemPromptContext,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final IChatRepository _repository;
  final _uuid = const Uuid();

  ChatNotifier(this._repository) : super(const ChatState());

  void initialize(DreamInterpretation interpretation) {
    final unlockedTraditionsInfo = interpretation.lockedTraditions
        .where((t) => t.isUnlocked && t.interpretation != null)
        .map((t) => '${t.title} (${t.scholar}):\n${t.interpretation}')
        .join('\n\n');

    final systemPrompt = '''
Sen Kadim Oneiro Rüyabilimci ve Derin Bilinçaltı Rehberisin.

KULLANICININ GÖRDÜĞÜ RÜYA:
"${interpretation.dreamText}"

RÜYANIN ÇÖZÜMLENEN KADİM DETAYLARI:
- Çıkarılan Anahtar Semboller: ${interpretation.symbols.join(', ')}
- Bilinçaltı Aynası: ${interpretation.freeAnalysis.bilincaltiAynasi}
- Birincil Kadim Tabir (${interpretation.primaryTradition.title} - ${interpretation.primaryTradition.scholar}):
${interpretation.primaryTradition.interpretation ?? interpretation.ancientInterpretation}
${unlockedTraditionsInfo.isNotEmpty ? '\n- Açılan Diğer Kadim Ekoller:\n$unlockedTraditionsInfo' : ''}
- Günün Pusulası: ${interpretation.freeAnalysis.gununPusulasi}

GÖREVİN VE ÜSLUBUN:
Kullanıcı bu rüya hakkında seninle konuşacak, sorular soracak veya rüyasını detaylandıracaktır.
1. Kullanıcının sorularını bu rüyanın ve kadim tabirinin doğal bir devamı olarak ele al.
2. Rüyadaki spesifik sembollere (${interpretation.symbols.join(', ')}) doğrudan atıfta bulunarak, derinlikli, bilgece, edebi ve şefkatli bir dille açıkla.
3. Asla hazır şablon, genel geçer veya kopyala-yapıştır cevaplar verme. Yanıtların tatmin edici uzunlukta ve akıcı olsun.
''';

    final welcomeMessage = ChatMessage(
      id: _uuid.v4(),
      text: 'Rüyanın derinliklerini inceledim. "${interpretation.symbols.take(3).join(', ')}" sembolleri bilinçaltının önemli bir eşiğine işaret ediyor. Bu rüyada aklına takılan veya hissettiğin en derin ayrıntı neydi?',
      isUser: false,
    );

    state = ChatState(
      messages: [welcomeMessage],
      systemPromptContext: systemPrompt,
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: trimmed,
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      error: null,
    );

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

      state = state.copyWith(
        messages: [...state.messages, botMessage],
        isTyping: false,
      );
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

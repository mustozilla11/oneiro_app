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
    final systemPrompt = '''
Sen Kadim Oneiro Rüyabilimci ve Derin Bilinçaltı Rehberisin.
Kullanıcının gördüğü rüya:
"${interpretation.dreamText}"
Seçtiği duygu: ${interpretation.emotion}
Çıkarılan anahtar semboller: ${interpretation.symbols.join(', ')}
Kadim tabiri: ${interpretation.ancientInterpretation}
Psikolojik analizi: ${interpretation.subconsciousAnalysis}
Günün uyarısı: ${interpretation.warningOfDay}

Görevin: Kullanıcı bu rüya hakkında sorular sordukça, mistik, bilge, derinlikli, şefkatli ancak net ve derin psikolojik/ezoterik içgörülerle cevap vermektir.
''';

    final welcomeMessage = ChatMessage(
      id: _uuid.v4(),
      text: 'Bilinçaltının fısıltılarını duydum. "${interpretation.symbols.join(', ')}" sembolleri derin bir kavşakta olduğuna işaret ediyor. Bu rüyada aklına takılan veya hissettiğin en derin ayrıntı neydi?',
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
      state = state.copyWith(
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

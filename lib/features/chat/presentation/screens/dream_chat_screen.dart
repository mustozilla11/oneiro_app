import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dream/domain/models/dream_interpretation.dart';
import '../providers/chat_provider.dart';

/// Minimalist Edebi Diyalog & Teemmül Ekranı (Chatbot/Baloncuk Görünümü Yoktur)
class DreamChatScreen extends ConsumerStatefulWidget {
  final DreamInterpretation interpretation;

  const DreamChatScreen({
    super.key,
    required this.interpretation,
  });

  @override
  ConsumerState<DreamChatScreen> createState() => _DreamChatScreenState();
}

class _DreamChatScreenState extends ConsumerState<DreamChatScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late final AnimationController _borderPulseController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _borderPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Sistem promptunu ve rüya bağlamını hazırla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.lightImpact();
      ref.read(chatProvider.notifier).initialize(widget.interpretation);
    });
  }

  @override
  void dispose() {
    _borderPulseController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Yeni mesaj geldiğinde listeyi kaydır
    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.isTyping != next.isTyping) {
        _scrollToBottom();
      }
    });

    final symbolsSnippet = widget.interpretation.symbols.take(3).join(' • ');

    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TEEMMÜL & SÖYLEŞİ',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppColors.moonlight,
              ),
            ),
            if (symbolsSnippet.isNotEmpty)
              Text(
                symbolsSnippet,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.dimMist,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Divider(color: AppColors.borderSubtle, height: 1),

          // Edebi Diyalog Listesi (Baloncuksuz, Açık Metin)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              itemCount: chatState.messages.length + (chatState.isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == chatState.messages.length && chatState.isTyping) {
                  return _buildTypingIndicator();
                }
                final message = chatState.messages[index];
                return _buildDialogueEntry(message);
              },
            ),
          ),

          // Hızlı Soru Önerileri (Sade Çipler)
          if (chatState.messages.length <= 3)
            _buildSuggestionsBar(),

          // Alt Metin Giriş Çubuğu
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDialogueEntry(dynamic message) {
    final isUser = message.isUser as bool;
    final timeStr = DateFormat('HH:mm').format(message.timestamp as DateTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Konuşmacı Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser ? Icons.edit_note_outlined : Icons.auto_stories_outlined,
                    size: 13,
                    color: isUser ? AppColors.mistGrey : AppColors.moonlight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUser ? 'SİZ' : 'KADİM REHBER',
                    style: isUser
                        ? GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: AppColors.mistGrey,
                          )
                        : GoogleFonts.cormorantGaramond(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                            color: AppColors.moonlight,
                          ),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.dimMist,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Metin Gövdesi (Kullanıcı için ince sol çizgi, bot için açık edebi paragraf)
          if (isUser)
            Container(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
              ),
              child: Text(
                message.text as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  height: 1.75,
                  color: AppColors.textPrimary,
                ),
              ),
            )
          else
            Text(
              message.text as String,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                height: 1.85,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.moonlight),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Kadim kaynaklar taranıyor...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.mistGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBar() {
    final suggestions = [
      'Bu sembollerin kadim kökeni nedir?',
      'Rüyadaki hisler neye işaret ediyor?',
      'Bilinçaltım neyi entegre etmemi istiyor?',
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(chatProvider.notifier).sendMessage(s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.charcoalSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Text(
                s,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    final tradId = widget.interpretation.primaryTradition.traditionId;
    final lightBorder = AppColors.traditionLightBorderColor(tradId);
    final darkBorder = AppColors.traditionDarkBorderColor(tradId);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.charcoalBlack,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _borderPulseController,
              builder: (context, child) {
                final t = Curves.easeInOutSine.transform(_borderPulseController.value);
                final animatedBorderColor = Color.lerp(darkBorder, lightBorder, t)!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: animatedBorderColor, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: animatedBorderColor.withValues(alpha: 0.08 + (t * 0.14)),
                        blurRadius: 6 + (t * 8),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Rüya hakkında bir soru sorun...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.dimMist,
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.moonlight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_upward_rounded,
                color: AppColors.charcoalBlack,
                size: 20,
              ),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

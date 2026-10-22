import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/subscription_service.dart';
import '../../data/repositories/dream_repository.dart';
import '../../domain/models/dream_interpretation.dart';
import '../../domain/models/dream_request.dart';

final dreamRepositoryProvider = Provider<IDreamRepository>((ref) {
  return DreamRepository();
});

class DreamState {
  final String dreamText;
  final String selectedEmotion;
  final String preferredTradition;
  final bool isLoading;
  final bool isUnlocking;
  final DreamInterpretation? interpretation;
  final String? errorMessage;

  const DreamState({
    this.dreamText = '',
    this.selectedEmotion = '',
    this.preferredTradition = 'islam_dogu',
    this.isLoading = false,
    this.isUnlocking = false,
    this.interpretation,
    this.errorMessage,
  });

  DreamState copyWith({
    String? dreamText,
    String? selectedEmotion,
    String? preferredTradition,
    bool? isLoading,
    bool? isUnlocking,
    DreamInterpretation? interpretation,
    String? errorMessage,
  }) {
    return DreamState(
      dreamText: dreamText ?? this.dreamText,
      selectedEmotion: selectedEmotion ?? this.selectedEmotion,
      preferredTradition: preferredTradition ?? this.preferredTradition,
      isLoading: isLoading ?? this.isLoading,
      isUnlocking: isUnlocking ?? this.isUnlocking,
      interpretation: interpretation ?? this.interpretation,
      errorMessage: errorMessage,
    );
  }
}

class DreamNotifier extends StateNotifier<DreamState> {
  final IDreamRepository _repository;

  DreamNotifier(this._repository) : super(const DreamState());

  void setEmotion(String emotion) {
    state = state.copyWith(selectedEmotion: emotion);
  }

  void setPreferredTradition(String traditionId) {
    state = state.copyWith(preferredTradition: traditionId);
  }

  void setDreamText(String text) {
    state = state.copyWith(dreamText: text);
  }

  void reset() {
    state = const DreamState();
  }

  Future<DreamInterpretation?> analyzeDream() async {
    if (state.dreamText.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Lütfen rüyanızı tarif edin.');
      return null;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final currentUid = AuthService.instance.currentUser?.uid;
      final request = DreamRequest(
        dreamText: state.dreamText.trim(),
        emotion: state.selectedEmotion,
        preferredTradition: state.preferredTradition,
        userId: currentUid,
      );

      final result = await _repository.interpretDream(request);
      state = state.copyWith(
        isLoading: false,
        interpretation: result,
      );

      // Gizlilik ve sıfır sunucu maliyeti politikası:
      // Rüyalar yerel cihazda gizli tutulur. Yalnızca ücretli Kadim Gezgin Plus aboneleri için buluta yedeklenir.
      if (currentUid != null && SubscriptionService.instance.isPremiumUser) {
        await FirestoreService.instance.saveDream(
          currentUid,
          dreamText: result.dreamText,
          interpretation: result.interpretation,
          subconsciousAnalysis: result.subconsciousAnalysis,
          warningOfDay: result.warningOfDay,
          primaryTradition: result.primaryTradition.title,
          lockedTraditions: result.lockedTraditions.map((t) => t.title).toList(),
          symbols: result.symbols,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Kadim alemlerle bağlantı kurulamadı: $e',
      );
      return null;
    }
  }

  /// Kilitli geleneğin tam tabirini açar ve state'teki kartı günceller
  Future<bool> unlockTradition(String traditionId) async {
    if (state.interpretation == null) return false;

    state = state.copyWith(isUnlocking: true);

    try {
      final currentUid = AuthService.instance.currentUser?.uid;
      final unlockedItem = await _repository.unlockTradition(
        state.dreamText.isNotEmpty ? state.dreamText : state.interpretation!.dreamText,
        traditionId,
        userId: currentUid,
      );

      final updatedLocked = state.interpretation!.lockedTraditions.map((trad) {
        if (trad.traditionId == traditionId) {
          return unlockedItem;
        }
        return trad;
      }).toList();

      final updatedInterpretation = state.interpretation!.copyWith(
        lockedTraditions: updatedLocked,
      );

      state = state.copyWith(
        isUnlocking: false,
        interpretation: updatedInterpretation,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isUnlocking: false);
      return false;
    }
  }
}

final dreamProvider = StateNotifierProvider<DreamNotifier, DreamState>((ref) {
  final repository = ref.watch(dreamRepositoryProvider);
  return DreamNotifier(repository);
});

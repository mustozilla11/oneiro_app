import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/dream_repository.dart';
import '../../domain/models/dream_interpretation.dart';
import '../../domain/models/dream_request.dart';

final dreamRepositoryProvider = Provider<IDreamRepository>((ref) {
  return DreamRepository();
});

class DreamState {
  final String dreamText;
  final String selectedEmotion;
  final bool isLoading;
  final DreamInterpretation? interpretation;
  final String? errorMessage;

  const DreamState({
    this.dreamText = '',
    this.selectedEmotion = 'Huzurlu',
    this.isLoading = false,
    this.interpretation,
    this.errorMessage,
  });

  DreamState copyWith({
    String? dreamText,
    String? selectedEmotion,
    bool? isLoading,
    DreamInterpretation? interpretation,
    String? errorMessage,
  }) {
    return DreamState(
      dreamText: dreamText ?? this.dreamText,
      selectedEmotion: selectedEmotion ?? this.selectedEmotion,
      isLoading: isLoading ?? this.isLoading,
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
      final request = DreamRequest(
        dreamText: state.dreamText.trim(),
        emotion: state.selectedEmotion,
      );

      final result = await _repository.interpretDream(request);
      state = state.copyWith(
        isLoading: false,
        interpretation: result,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Kadim alemlerle bağlantı kurulamadı: $e',
      );
      return null;
    }
  }
}

final dreamProvider = StateNotifierProvider<DreamNotifier, DreamState>((ref) {
  final repository = ref.watch(dreamRepositoryProvider);
  return DreamNotifier(repository);
});

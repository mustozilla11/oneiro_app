import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/firestore_service.dart';
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
  static const String _prefTraditionKey = 'oneiro_preferred_tradition_v1';

  DreamNotifier(this._repository) : super(const DreamState()) {
    _loadSavedTradition();
  }

  Future<void> _loadSavedTradition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTrad = prefs.getString(_prefTraditionKey);
      if (savedTrad != null && savedTrad.isNotEmpty) {
        state = state.copyWith(preferredTradition: savedTrad);
      }
    } catch (_) {}
  }

  void setEmotion(String emotion) {
    state = state.copyWith(selectedEmotion: emotion);
  }

  Future<void> setPreferredTradition(String traditionId) async {
    state = state.copyWith(preferredTradition: traditionId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTraditionKey, traditionId);
    } catch (_) {}
  }

  void setDreamText(String text) {
    state = state.copyWith(dreamText: text);
  }

  void reset() {
    state = DreamState(preferredTradition: state.preferredTradition);
  }

  Future<DreamInterpretation?> analyzeDream({String? language}) async {
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
        language: language,
      );

      final result = await _repository.interpretDream(request);
      state = state.copyWith(
        isLoading: false,
        interpretation: result,
      );

      final lockedDataList = result.lockedTraditions
          .map((t) => <String, dynamic>{
                'tradition_id': t.traditionId,
                'title': t.title,
                'scholar': t.scholar,
                'teaser': t.teaser,
                'interpretation': t.interpretation,
                'is_unlocked': t.isUnlocked,
              })
          .toList();

      // Rüyayı her zaman telefon hafızasına tam detaylarıyla kaydet; oturum açıksa arka planda buluta da mühürle
      await FirestoreService.instance.saveDream(
        currentUid ?? 'local_user',
        dreamText: result.dreamText,
        interpretation: result.interpretation,
        subconsciousAnalysis: result.subconsciousAnalysis,
        warningOfDay: result.warningOfDay,
        primaryTradition: result.primaryTradition.title,
        primaryTraditionId: result.primaryTradition.traditionId,
        primaryTraditionScholar: result.primaryTradition.scholar,
        lockedTraditions: result.lockedTraditions.map((t) => t.title).toList(),
        lockedTraditionsData: lockedDataList,
        symbols: result.symbols,
        emotion: state.selectedEmotion,
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

  /// Kilitli geleneğin tam tabirini açar, state'i ve yerel arşivi günceller
  Future<bool> unlockTradition(String traditionId, {DreamInterpretation? targetInterpretation}) async {
    final activeInterp = targetInterpretation ?? state.interpretation;
    if (activeInterp == null) return false;

    state = state.copyWith(isUnlocking: true);

    try {
      final currentUid = AuthService.instance.currentUser?.uid;
      final dreamTxt = activeInterp.dreamText.isNotEmpty ? activeInterp.dreamText : state.dreamText;
      final unlockedItem = await _repository.unlockTradition(
        dreamTxt,
        traditionId,
        userId: currentUid,
      );

      final updatedLocked = activeInterp.lockedTraditions.map((trad) {
        if (trad.traditionId == traditionId) {
          return unlockedItem;
        }
        return trad;
      }).toList();

      final updatedInterpretation = activeInterp.copyWith(
        lockedTraditions: updatedLocked,
      );

      state = state.copyWith(
        isUnlocking: false,
        interpretation: updatedInterpretation,
      );

      // Yerel arşivdeki kaydı da güncelle ki Arşivden tekrar açıldığında kilit açık kalsın
      final lockedDataList = updatedLocked
          .map((t) => <String, dynamic>{
                'tradition_id': t.traditionId,
                'title': t.title,
                'scholar': t.scholar,
                'teaser': t.teaser,
                'interpretation': t.interpretation,
                'is_unlocked': t.isUnlocked,
              })
          .toList();
      await FirestoreService.instance.updateLocalDreamLockedTraditions(dreamTxt, lockedDataList);

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

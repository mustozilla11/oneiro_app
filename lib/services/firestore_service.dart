import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService instance = FirestoreService._internal();

  FirebaseFirestore? _firestore;

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /// Kullanıcı ilk kez giriş yaptığında Firestore dokümanını oluşturur veya senkronize eder
  Future<Map<String, dynamic>?> syncUserRecord({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    if (!isFirebaseAvailable) {
      debugPrint('[FirestoreService] Firebase aktif değil, kullanıcı yerel modda devam ediyor.');
      return null;
    }

    try {
      final userDocRef = firestore.collection('users').doc(uid);
      final docSnap = await userDocRef.get();

      if (!docSnap.exists) {
        final initialData = <String, dynamic>{
          'uid': uid,
          'email': email ?? '',
          'displayName': displayName ?? 'Kadim Gezgin',
          'dailyFreeDreamDate': _getTodayDateString(),
          'dreamCredits': 3, // İlk kayıtta 3 kadim hediye jeton
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        await userDocRef.set(initialData);
        debugPrint('[FirestoreService] Yeni kullanıcı dokümanı oluşturuldu: $uid');
        return initialData;
      } else {
        await userDocRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        return docSnap.data();
      }
    } catch (e) {
      debugPrint('[FirestoreService] syncUserRecord hatası: $e');
      return null;
    }
  }

  /// Kullanıcı doküman verisini getirir
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    if (!isFirebaseAvailable) return null;
    try {
      final docSnap = await firestore.collection('users').doc(uid).get();
      return docSnap.data();
    } catch (e) {
      debugPrint('[FirestoreService] getUserData hatası: $e');
      return null;
    }
  }

  /// Kullanıcı verisini canlı dinleyen Stream
  Stream<Map<String, dynamic>?> streamUserData(String uid) {
    if (!isFirebaseAvailable) {
      return Stream.value(null);
    }
    try {
      return firestore.collection('users').doc(uid).snapshots().map((snapshot) {
        return snapshot.data();
      });
    } catch (e) {
      debugPrint('[FirestoreService] streamUserData hatası: $e');
      return Stream.value(null);
    }
  }

  /// Premium durumunu günceller
  Future<void> updatePremiumStatus(String uid, bool isPremium) async {
    if (!isFirebaseAvailable) return;
    try {
      await firestore.collection('users').doc(uid).update({
        'isPremium': isPremium,
      });
      debugPrint('[FirestoreService] Kullanıcı $uid premium durumu güncellendi: $isPremium');
    } catch (e) {
      debugPrint('[FirestoreService] updatePremiumStatus hatası: $e');
    }
  }

  /// Jeton bakiyesini güvenli şekilde artırır
  Future<void> incrementCredits(String uid, int count) async {
    if (!isFirebaseAvailable) return;
    try {
      await firestore.collection('users').doc(uid).update({
        'dreamCredits': FieldValue.increment(count),
      });
      debugPrint('[FirestoreService] Kullanıcı $uid jetonları $count artırıldı.');
    } catch (e) {
      debugPrint('[FirestoreService] incrementCredits hatası: $e');
    }
  }

  /// Rüya yorumlama hakkını Firestore üzerinde tüketir
  Future<bool> deductCreditOrUseDaily(String uid) async {
    if (!isFirebaseAvailable) return true;
    try {
      final userDocRef = firestore.collection('users').doc(uid);
      final docSnap = await userDocRef.get();
      if (!docSnap.exists) return true;

      final data = docSnap.data()!;
      final isPremium = data['isPremium'] as bool? ?? false;
      if (isPremium) return true;

      final lastDate = data['dailyFreeDreamDate'] as String? ?? '';
      final today = _getTodayDateString();

      if (lastDate != today) {
        // Bugünün ücretsiz hakkını kullandır
        await userDocRef.update({
          'dailyFreeDreamDate': today,
        });
        return true;
      }

      final credits = data['dreamCredits'] as int? ?? 0;
      if (credits > 0) {
        await userDocRef.update({
          'dreamCredits': FieldValue.increment(-1),
        });
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[FirestoreService] deductCreditOrUseDaily hatası: $e');
      return true; // Kullanıcıyı engellememek için fallback true
    }
  }

  /// Yorumlanan rüyayı `users/{uid}/dreams` alt koleksiyonuna mühürler
  Future<void> saveDream(
    String uid, {
    required String dreamText,
    required String interpretation,
    required String subconsciousAnalysis,
    required String warningOfDay,
    required String primaryTradition,
    List<String>? lockedTraditions,
    List<String>? symbols,
  }) async {
    if (!isFirebaseAvailable) {
      debugPrint('[FirestoreService] Firebase aktif değil, rüya yerel bellekte tutuluyor.');
      return;
    }

    try {
      final dreamData = <String, dynamic>{
        'dreamText': dreamText,
        'interpretation': interpretation,
        'subconsciousAnalysis': subconsciousAnalysis,
        'warningOfDay': warningOfDay,
        'primaryTradition': primaryTradition,
        'lockedTraditions': lockedTraditions ?? <String>[],
        'symbols': symbols ?? <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'dateString': _getTodayDateString(),
      };

      await firestore
          .collection('users')
          .doc(uid)
          .collection('dreams')
          .add(dreamData);

      debugPrint('[FirestoreService] Rüya başarıyla buluta mühürlendi (users/$uid/dreams).');
    } catch (e) {
      debugPrint('[FirestoreService] saveDream hatası: $e');
    }
  }

  /// Kullanıcının geçmiş rüyalarını canlı yayınlayan Stream
  Stream<List<Map<String, dynamic>>> getDreamHistoryStream(String uid) {
    if (!isFirebaseAvailable) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    try {
      return firestore
          .collection('users')
          .doc(uid)
          .collection('dreams')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint('[FirestoreService] getDreamHistoryStream hatası: $e');
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }
}

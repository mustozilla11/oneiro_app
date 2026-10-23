import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService instance = FirestoreService._internal();

  FirebaseFirestore? _firestore;

  /// Yerel rüya arşivi her güncellendiğinde dinleyicileri (Arşiv & Profil) anında yeniler
  final ValueNotifier<int> localDreamsRevision = ValueNotifier<int>(0);

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
    if (!isFirebaseAvailable) return null;

    try {
      final userDocRef = firestore.collection('users').doc(uid);
      final docSnap = await userDocRef.get().timeout(const Duration(seconds: 3));

      if (!docSnap.exists) {
        final initialData = <String, dynamic>{
          'uid': uid,
          'email': email ?? '',
          'displayName': displayName ?? 'Kadim Gezgin',
          'dailyFreeDreamDate': _getTodayDateString(),
          'dreamCredits': 3,
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        await userDocRef.set(initialData).timeout(const Duration(seconds: 3));
        return initialData;
      } else {
        await userDocRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 3));
        return docSnap.data();
      }
    } catch (e) {
      debugPrint('[FirestoreService] syncUserRecord uyarısı (yerel mod aktif): $e');
      return null;
    }
  }

  /// Kullanıcı doküman verisini getirir
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    if (!isFirebaseAvailable) return null;
    try {
      final docSnap = await firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 3));
      return docSnap.data();
    } catch (e) {
      debugPrint('[FirestoreService] getUserData uyarısı: $e');
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
      }).handleError((_) => null);
    } catch (e) {
      return Stream.value(null);
    }
  }

  /// Premium durumunu günceller
  Future<void> updatePremiumStatus(String uid, bool isPremium) async {
    if (!isFirebaseAvailable) return;
    try {
      await firestore.collection('users').doc(uid).update({
        'isPremium': isPremium,
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[FirestoreService] updatePremiumStatus uyarısı: $e');
    }
  }

  /// Jeton bakiyesini güvenli şekilde artırır
  Future<void> incrementCredits(String uid, int count) async {
    if (!isFirebaseAvailable) return;
    try {
      await firestore.collection('users').doc(uid).update({
        'dreamCredits': FieldValue.increment(count),
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[FirestoreService] incrementCredits uyarısı: $e');
    }
  }

  /// Rüya yorumlama hakkını Firestore üzerinde tüketir (Zaman aşımlı, asla bloklamaz)
  Future<bool> deductCreditOrUseDaily(String uid) async {
    if (!isFirebaseAvailable) return true;
    try {
      final userDocRef = firestore.collection('users').doc(uid);
      final docSnap = await userDocRef.get().timeout(const Duration(seconds: 3));
      if (!docSnap.exists) return true;

      final data = docSnap.data()!;
      final isPremium = data['isPremium'] as bool? ?? false;
      if (isPremium) return true;

      final lastDate = data['dailyFreeDreamDate'] as String? ?? '';
      final today = _getTodayDateString();

      if (lastDate != today) {
        await userDocRef.update({
          'dailyFreeDreamDate': today,
        }).timeout(const Duration(seconds: 3));
        return true;
      }

      final credits = data['dreamCredits'] as int? ?? 0;
      if (credits > 0) {
        await userDocRef.update({
          'dreamCredits': FieldValue.increment(-1),
        }).timeout(const Duration(seconds: 3));
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[FirestoreService] deductCreditOrUseDaily uyarısı: $e');
      return true;
    }
  }

  static const String _prefLocalDreamsKey = 'oneiro_local_dream_history_v1';

  /// Yorumlanan rüyayı ÖNCE telefonun yerel hafızasına anında kaydeder,
  /// ardından bloklamadan arka planda Firestore'a mühürler.
  Future<void> saveDream(
    String uid, {
    required String dreamText,
    required String interpretation,
    required String subconsciousAnalysis,
    required String warningOfDay,
    required String primaryTradition,
    String? primaryTraditionId,
    String? primaryTraditionScholar,
    List<String>? lockedTraditions,
    List<Map<String, dynamic>>? lockedTraditionsData,
    List<String>? symbols,
    String? emotion,
  }) async {
    final dreamData = <String, dynamic>{
      'dreamText': dreamText,
      'interpretation': interpretation,
      'subconsciousAnalysis': subconsciousAnalysis,
      'warningOfDay': warningOfDay,
      'primaryTradition': primaryTradition,
      'primaryTraditionId': primaryTraditionId ?? 'islam_dogu',
      'primaryTraditionScholar': primaryTraditionScholar ?? 'İbn-i Sîrîn',
      'lockedTraditions': lockedTraditions ?? <String>[],
      'lockedTraditionsData': lockedTraditionsData ?? <Map<String, dynamic>>[],
      'symbols': symbols ?? <String>[],
      'emotion': emotion ?? '',
      'dateString': _getTodayDateString(),
    };

    // 1. HER ZAMAN ÖNCE YEREL TELEFONA (SharedPreferences) ANINDA KAYDET
    try {
      final prefs = await SharedPreferences.getInstance();
      final localListStr = prefs.getString(_prefLocalDreamsKey);
      List<dynamic> localList = [];
      if (localListStr != null && localListStr.isNotEmpty) {
        try {
          localList = jsonDecode(localListStr) as List<dynamic>;
        } catch (_) {
          localList = [];
        }
      }
      // Aynı rüya metni varsa güncelle, yoksa en başa ekle
      localList.removeWhere((item) =>
          item is Map && (item['dreamText'] as String? ?? '').trim() == dreamText.trim());
      localList.insert(0, dreamData);
      if (localList.length > 100) localList = localList.sublist(0, 100);
      await prefs.setString(_prefLocalDreamsKey, jsonEncode(localList));
      localDreamsRevision.value++;
      debugPrint('[FirestoreService] Rüya yerel telefona mühürlendi (Toplam: ${localList.length}).');
    } catch (e) {
      debugPrint('[FirestoreService] Yerel rüya kaydetme uyarısı: $e');
    }

    // 2. Firebase hazırsa ARKA PLANDA (bloklamadan) buluta mühürle
    if (isFirebaseAvailable && uid.isNotEmpty && uid != 'local_user') {
      unawaited(
        Future(() async {
          try {
            final firestoreData = Map<String, dynamic>.from(dreamData);
            firestoreData['createdAt'] = FieldValue.serverTimestamp();
            await firestore
                .collection('users')
                .doc(uid)
                .collection('dreams')
                .add(firestoreData)
                .timeout(const Duration(seconds: 4));
            debugPrint('[FirestoreService] Rüya buluta mühürlendi (users/$uid/dreams).');
          } catch (e) {
            debugPrint('[FirestoreService] saveDream bulut senkronizasyon notu: $e');
          }
        }),
      );
    }
  }

  /// Kilitli bir gelenek açıldığında yerel arşivdeki rüya kaydını günceller
  Future<void> updateLocalDreamLockedTraditions(
    String dreamText,
    List<Map<String, dynamic>> updatedLockedTraditionsData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localListStr = prefs.getString(_prefLocalDreamsKey);
      if (localListStr == null || localListStr.isEmpty) return;

      final localList = jsonDecode(localListStr) as List<dynamic>;
      bool changed = false;
      for (int i = 0; i < localList.length; i++) {
        final item = Map<String, dynamic>.from(localList[i] as Map);
        if ((item['dreamText'] as String? ?? '').trim() == dreamText.trim()) {
          item['lockedTraditionsData'] = updatedLockedTraditionsData;
          localList[i] = item;
          changed = true;
          break;
        }
      }
      if (changed) {
        await prefs.setString(_prefLocalDreamsKey, jsonEncode(localList));
        localDreamsRevision.value++;
      }
    } catch (e) {
      debugPrint('[FirestoreService] updateLocalDreamLockedTraditions uyarısı: $e');
    }
  }

  /// Yerel hafızadaki kayıtlı rüyaları getirir
  Future<List<Map<String, dynamic>>> getLocalDreams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localListStr = prefs.getString(_prefLocalDreamsKey);
      if (localListStr != null && localListStr.isNotEmpty) {
        final decoded = jsonDecode(localListStr) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[FirestoreService] getLocalDreams hatası: $e');
    }
    return [];
  }

  /// Kayıtlı bir rüyayı yerel arşivden (ve varsa buluttan) siler
  Future<void> deleteDream(String dreamText, {String? uid, String? docId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localListStr = prefs.getString(_prefLocalDreamsKey);
      if (localListStr != null && localListStr.isNotEmpty) {
        final localList = jsonDecode(localListStr) as List<dynamic>;
        localList.removeWhere((item) =>
            item is Map && (item['dreamText'] as String? ?? '').trim() == dreamText.trim());
        await prefs.setString(_prefLocalDreamsKey, jsonEncode(localList));
        localDreamsRevision.value++;
      }
    } catch (e) {
      debugPrint('[FirestoreService] deleteDream yerel silme uyarısı: $e');
    }

    if (isFirebaseAvailable && uid != null && uid.isNotEmpty && docId != null && docId.isNotEmpty) {
      unawaited(
        Future(() async {
          try {
            await firestore
                .collection('users')
                .doc(uid)
                .collection('dreams')
                .doc(docId)
                .delete()
                .timeout(const Duration(seconds: 3));
          } catch (_) {}
        }),
      );
    }
  }

  /// Kullanıcının tüm yerel ve bulut rüya kayıtlarını ve verilerini kalıcı olarak siler (Hesap Silme Zorunluluğu)
  Future<void> deleteAllUserData({String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLocalDreamsKey);
      localDreamsRevision.value++;
    } catch (e) {
      debugPrint('[FirestoreService] deleteAllUserData yerel temizlik hatası: $e');
    }

    if (isFirebaseAvailable && uid != null && uid.isNotEmpty && !uid.startsWith('guest_') && !uid.startsWith('dev_')) {
      try {
        final query = await firestore
            .collection('users')
            .doc(uid)
            .collection('dreams')
            .get()
            .timeout(const Duration(seconds: 5));

        for (final doc in query.docs) {
          await doc.reference.delete().catchError((_) {});
        }

        await firestore.collection('users').doc(uid).delete().catchError((_) {});
      } catch (e) {
        debugPrint('[FirestoreService] deleteAllUserData Firestore temizlik uyarısı: $e');
      }
    }
  }

  /// Kullanıcının geçmiş rüyalarını canlı yayınlayan Stream
  Stream<List<Map<String, dynamic>>> getDreamHistoryStream(String uid) {
    if (!isFirebaseAvailable || uid.isEmpty || uid.startsWith('guest_') || uid.startsWith('dev_')) {
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
      }).handleError((_) => <Map<String, dynamic>>[]);
    } catch (e) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }
}

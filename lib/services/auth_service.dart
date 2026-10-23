import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firestore_service.dart';
import 'subscription_service.dart';

/// Oneiro kullanıcı kimlik modeli (Firebase, Google ve Misafir oturumlarını birleştirir)
class OneiroUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isGuest;

  const OneiroUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isGuest = false,
  });

  factory OneiroUser.fromFirebase(User user) {
    return OneiroUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      isGuest: user.isAnonymous,
    );
  }

  factory OneiroUser.fromGoogle(GoogleSignInAccount account) {
    return OneiroUser(
      uid: account.id,
      email: account.email,
      displayName: account.displayName,
      photoURL: account.photoUrl,
      isGuest: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoURL': photoURL,
    'isGuest': isGuest,
  };

  factory OneiroUser.fromJson(Map<String, dynamic> json) => OneiroUser(
    uid: json['uid'] as String,
    email: json['email'] as String?,
    displayName: json['displayName'] as String?,
    photoURL: json['photoURL'] as String?,
    isGuest: json['isGuest'] as bool? ?? false,
  );
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const String _prefUserKey = 'oneiro_auth_user_json';
  static const String _prefOnboardingKey = 'oneiro_has_onboarded_bool';

  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: '1051570592259-vnrq5tl43rrg9dmjus7qbsnjsg14vkqd.apps.googleusercontent.com',
  );
  final GoogleSignIn _googleSignInFallback = GoogleSignIn(
    scopes: ['email'],
  );

  OneiroUser? _currentUser;
  bool _hasOnboarded = false;
  final StreamController<OneiroUser?> _authStateController = StreamController<OneiroUser?>.broadcast();

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth get auth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  OneiroUser? get currentUser => _currentUser;
  bool get hasOnboarded => _hasOnboarded;

  Stream<OneiroUser?> get authStateChanges => _authStateController.stream;

  bool get isSignedIn => _currentUser != null && !_currentUser!.isGuest;

  /// Servisi başlatır ve hafızadaki oturumu anında yükler
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasOnboarded = prefs.getBool(_prefOnboardingKey) ?? false;

      // 1. SharedPreferences'tan kayıtlı oturumu ANINDA yükle
      final userJsonStr = prefs.getString(_prefUserKey);
      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        try {
          final map = jsonDecode(userJsonStr) as Map<String, dynamic>;
          _currentUser = OneiroUser.fromJson(map);
          _hasOnboarded = true;
          await prefs.setBool(_prefOnboardingKey, true);
          _authStateController.add(_currentUser);
          debugPrint('[AuthService] Yerel oturum yüklendi: ${_currentUser?.displayName} (${_currentUser?.email})');
        } catch (e) {
          debugPrint('[AuthService] Yerel kullanıcı ayrıştırma hatası: $e');
        }
      }

      // 2. Kullanıcı daha önce uygulamaya girmişse ancak oturum kaydı yoksa,
      // asla tekrar giriş ekranına atma; yerel oturumu koru
      if (_currentUser == null && _hasOnboarded) {
        final guestUid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
        _currentUser = OneiroUser(
          uid: guestUid,
          displayName: 'Kadim Gezgin',
          email: null,
          isGuest: true,
        );
        await prefs.setString(_prefUserKey, jsonEncode(_currentUser!.toJson()));
        _authStateController.add(_currentUser);
      }

      // 3. Firebase yapılandırılmışsa Firebase auth listener ekle (Ancak yerel tam oturumu asla ezme!)
      if (isFirebaseAvailable) {
        try {
          final fbUser = auth.currentUser;
          if (fbUser != null && (_currentUser == null || _currentUser!.isGuest)) {
            _currentUser = OneiroUser.fromFirebase(fbUser);
            await _persistUser(_currentUser!);
            _authStateController.add(_currentUser);
          }
          auth.authStateChanges().listen((fbUser) async {
            if (fbUser != null && (_currentUser == null || _currentUser!.isGuest)) {
              _currentUser = OneiroUser.fromFirebase(fbUser);
              await _persistUser(_currentUser!);
              _authStateController.add(_currentUser);
            }
          });
        } catch (e) {
          debugPrint('[AuthService] Firebase Auth kontrol uyarısı: $e');
        }
      }

      // 4. Google sessiz oturum açma (arka planda bloklamadan tazele)
      _googleSignIn.signInSilently().timeout(const Duration(seconds: 3)).then((googleAccount) async {
        if (googleAccount != null) {
          _currentUser = OneiroUser.fromGoogle(googleAccount);
          await _persistUser(_currentUser!);
          _authStateController.add(_currentUser);
          debugPrint('[AuthService] Google sessiz oturumu tazelendi: ${googleAccount.email}');
        }
      }).catchError((e) {
        debugPrint('[AuthService] Google sessiz giriş notu: $e');
      });

      _authStateController.add(_currentUser);
    } catch (e) {
      debugPrint('[AuthService] Başlatma hatası: $e');
      _authStateController.add(_currentUser);
    }
  }

  Future<void> setOnboarded() async {
    _hasOnboarded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefOnboardingKey, true);
    } catch (_) {}
  }

  Future<void> _persistUser(OneiroUser user) async {
    _currentUser = user;
    _hasOnboarded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUserKey, jsonEncode(user.toJson()));
      await prefs.setBool(_prefOnboardingKey, true);
    } catch (e) {
      debugPrint('[AuthService] Kullanıcı kaydetme hatası: $e');
    }
  }

  /// Google Hesabı ile Giriş
  /// Önce oturumu telefona kaydeder; bulut senkronizasyonu asla girişi bloklamaz.
  Future<OneiroUser?> signInWithGoogle() async {
    try {
      debugPrint('[AuthService] Google Giriş arayüzü başlatılıyor...');
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (firstErr) {
        debugPrint('[AuthService] Birincil GoogleSignIn uyarısı ($firstErr), yedek istemci deneniyor...');
        googleUser = await _googleSignInFallback.signIn();
      }

      if (googleUser == null) {
        debugPrint('[AuthService] Google Giriş kullanıcı tarafından iptal edildi.');
        return null;
      }

      OneiroUser signedInUser = OneiroUser.fromGoogle(googleUser);

      // 1. ÖNCE YEREL HAFIZAYA ANINDA KAYDET (Böylece uygulama kapatılsa bile oturum asla kaybolmaz!)
      await _persistUser(signedInUser);
      _authStateController.add(_currentUser);

      // 2. Firebase hazırsa arka planda zaman aşımlı doğrula
      if (isFirebaseAvailable) {
        try {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication.timeout(const Duration(seconds: 3));
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final UserCredential userCredential =
              await auth.signInWithCredential(credential).timeout(const Duration(seconds: 3));
          if (userCredential.user != null) {
            signedInUser = OneiroUser.fromFirebase(userCredential.user!);
            await _persistUser(signedInUser);
            _authStateController.add(_currentUser);
          }
        } catch (e) {
          debugPrint('[AuthService] Firebase credential aktarım uyarısı (yerel Google oturumu korundu): $e');
        }
      }

      // 3. Firestore ve RevenueCat eşleştirmesini ARKA PLANDA (bloklamadan) çalıştır
      unawaited(
        FirestoreService.instance
            .syncUserRecord(
              uid: signedInUser.uid,
              email: signedInUser.email,
              displayName: signedInUser.displayName,
            )
            .catchError((_) => null),
      );
      unawaited(
        SubscriptionService.instance.logIn(signedInUser.uid).catchError((_) {}),
      );

      debugPrint('[AuthService] Google ile giriş başarılı ve kalıcı olarak mühürlendi: ${signedInUser.displayName}');
      return signedInUser;
    } catch (e) {
      debugPrint('[AuthService] Google Giriş hatası: $e');
      rethrow;
    }
  }

  /// Apple ID ile Giriş (iOS ve macOS)
  Future<OneiroUser?> signInWithApple() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) {
      throw UnsupportedError(
        'Apple ile Giriş yalnızca iOS (iPhone / iPad) cihazlarda kullanılabilir.',
      );
    }

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final displayName = (appleCredential.givenName != null || appleCredential.familyName != null)
          ? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim()
          : 'Rüya Gezgini';

      OneiroUser signedInUser = OneiroUser(
        uid: appleCredential.userIdentifier ?? 'apple_${DateTime.now().millisecondsSinceEpoch}',
        email: appleCredential.email,
        displayName: displayName,
        isGuest: false,
      );

      // 1. ÖNCE YEREL HAFIZAYA ANINDA KAYDET
      await _persistUser(signedInUser);
      _authStateController.add(_currentUser);

      // 2. Firebase & Bulut senkronizasyonu (bloklamadan)
      if (isFirebaseAvailable) {
        try {
          final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
          final AuthCredential credential = oAuthProvider.credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          );
          final UserCredential userCredential =
              await auth.signInWithCredential(credential).timeout(const Duration(seconds: 3));
          if (userCredential.user != null) {
            signedInUser = OneiroUser.fromFirebase(userCredential.user!);
            await _persistUser(signedInUser);
            _authStateController.add(_currentUser);
          }
        } catch (e) {
          debugPrint('[AuthService] Firebase Apple credential uyarısı: $e');
        }
      }

      unawaited(
        FirestoreService.instance
            .syncUserRecord(
              uid: signedInUser.uid,
              email: signedInUser.email,
              displayName: displayName,
            )
            .catchError((_) => null),
      );
      unawaited(
        SubscriptionService.instance.logIn(signedInUser.uid).catchError((_) {}),
      );

      return signedInUser;
    } catch (e) {
      debugPrint('[AuthService] Apple Giriş hatası: $e');
      rethrow;
    }
  }

  /// Misafir Olarak Giriş (Kalıcı olarak cihazda tutulur)
  Future<OneiroUser> signInAsGuest() async {
    final guestUid = _currentUser?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final guestUser = OneiroUser(
      uid: guestUid,
      displayName: 'Misafir Seyyah',
      email: null,
      isGuest: true,
    );
    await _persistUser(guestUser);
    _authStateController.add(_currentUser);
    return guestUser;
  }

  /// Cihaz / Geliştirici Hesabıyla Kalıcı Oturum Açma
  Future<OneiroUser> signInWithDevAccount({String? name, String? email}) async {
    final devUid = _currentUser != null && !_currentUser!.isGuest
        ? _currentUser!.uid
        : 'oneiro_user_${DateTime.now().millisecondsSinceEpoch}';
    final devUser = OneiroUser(
      uid: devUid,
      displayName: name ?? 'Kadim Gezgin',
      email: email ?? 'gezgin@oneiro.app',
      isGuest: false,
    );
    await _persistUser(devUser);
    _authStateController.add(_currentUser);
    return devUser;
  }

  /// Oturumu Kapat (Rüya geçmişi verilerini silmez, yalnızca misafir moduna geçirir)
  Future<void> signOut() async {
    try {
      if (isFirebaseAvailable) {
        unawaited(auth.signOut().catchError((_) {}));
      }
      try {
        unawaited(_googleSignIn.signOut().catchError((_) => null));
      } catch (_) {}
      final guestUser = OneiroUser(
        uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        displayName: 'Misafir Okuyucu',
        email: null,
        isGuest: true,
      );
      await _persistUser(guestUser);
      unawaited(SubscriptionService.instance.logOut().catchError((_) {}));
      debugPrint('[AuthService] Oturum misafir moduna geçirildi.');
    } catch (e) {
      debugPrint('[AuthService] Çıkış işlemi istisnası: $e');
    } finally {
      _authStateController.add(_currentUser);
    }
  }

  /// Hesabı ve Tüm Verileri Kalıcı Olarak Sil (Apple Guideline 5.1.1(v) & Google Play Data Safety)
  Future<bool> deleteAccount() async {
    try {
      final user = _currentUser;
      final uid = user?.uid;

      // 1. Veritabanındaki rüyaları ve profili temizle
      await FirestoreService.instance.deleteAllUserData(uid: uid);

      // 2. Firebase Auth kullanıcısını sil
      if (isFirebaseAvailable) {
        try {
          final fbUser = auth.currentUser;
          if (fbUser != null) {
            await fbUser.delete();
          }
        } catch (e) {
          debugPrint('[AuthService] Firebase auth delete uyarısı: $e');
        }
        try {
          await auth.signOut();
        } catch (_) {}
      }

      // 3. Google Sign-In bağlantısını kopar
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      // 4. Misafir kullanıcıya sıfırla ve SharedPreferences kullanıcı verisini temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserKey);

      final guestUser = OneiroUser(
        uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        displayName: 'Misafir Okuyucu',
        email: null,
        isGuest: true,
      );
      await _persistUser(guestUser);
      unawaited(SubscriptionService.instance.logOut().catchError((_) {}));
      debugPrint('[AuthService] Kullanıcı hesabı ve tüm verileri kalıcı olarak silindi.');
      return true;
    } catch (e) {
      debugPrint('[AuthService] deleteAccount hatası: $e');
      return false;
    } finally {
      _authStateController.add(_currentUser);
    }
  }
}

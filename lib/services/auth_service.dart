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

  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  OneiroUser? _currentUser;
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

  Stream<OneiroUser?> get authStateChanges => _authStateController.stream;

  bool get isSignedIn => _currentUser != null && !_currentUser!.isGuest;

  /// Servisi başlatır ve hafızadaki veya arka plandaki oturumu yükler
  Future<void> initialize() async {
    try {
      // 1. SharedPreferences'tan kayıtlı oturumu yükle
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString(_prefUserKey);
      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        try {
          final map = jsonDecode(userJsonStr) as Map<String, dynamic>;
          _currentUser = OneiroUser.fromJson(map);
          _authStateController.add(_currentUser);
          debugPrint('[AuthService] Yerel oturum yüklendi: ${_currentUser?.displayName} (${_currentUser?.email})');
        } catch (e) {
          debugPrint('[AuthService] Yerel kullanıcı ayrıştırma hatası: $e');
        }
      }

      // 2. Firebase yapılandırılmışsa Firebase auth listener ekle
      if (isFirebaseAvailable) {
        final fbUser = auth.currentUser;
        if (fbUser != null) {
          _currentUser = OneiroUser.fromFirebase(fbUser);
          _authStateController.add(_currentUser);
        }
        auth.authStateChanges().listen((fbUser) {
          if (fbUser != null) {
            _currentUser = OneiroUser.fromFirebase(fbUser);
            _authStateController.add(_currentUser);
          }
        });
      }

      // 3. Google sessiz oturum açma (arka planda yenileme)
      _googleSignIn.signInSilently().then((googleAccount) {
        if (googleAccount != null && (_currentUser == null || _currentUser!.isGuest)) {
          _currentUser = OneiroUser.fromGoogle(googleAccount);
          _persistUser(_currentUser!);
          _authStateController.add(_currentUser);
          debugPrint('[AuthService] Google sessiz oturumu tazelendi: ${googleAccount.email}');
        }
      }).catchError((e) {
        debugPrint('[AuthService] Google sessiz giriş notu: $e');
      });
    } catch (e) {
      debugPrint('[AuthService] Başlatma hatası: $e');
    }
  }

  Future<void> _persistUser(OneiroUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('[AuthService] Kullanıcı kaydetme hatası: $e');
    }
  }

  /// Google Hesabı ile Giriş (Gerçek Google Dialog Penceresi Tetiklenir)
  Future<OneiroUser?> signInWithGoogle() async {
    try {
      debugPrint('[AuthService] Gerçek Google Giriş arayüzü başlatılıyor...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[AuthService] Google Giriş kullanıcı tarafından iptal edildi.');
        return null;
      }

      OneiroUser signedInUser = OneiroUser.fromGoogle(googleUser);

      // Firebase hazırsa credential ile doğrula
      if (isFirebaseAvailable) {
        try {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final UserCredential userCredential = await auth.signInWithCredential(credential);
          if (userCredential.user != null) {
            signedInUser = OneiroUser.fromFirebase(userCredential.user!);
          }
        } catch (e) {
          debugPrint('[AuthService] Firebase credential aktarım uyarısı: $e');
        }
      }

      // Firestore ve RevenueCat eşleştirmesi
      try {
        await FirestoreService.instance.syncUserRecord(
          uid: signedInUser.uid,
          email: signedInUser.email,
          displayName: signedInUser.displayName,
        );
      } catch (e) {
        debugPrint('[AuthService] Firestore sync uyarısı: $e');
      }

      try {
        await SubscriptionService.instance.logIn(signedInUser.uid);
      } catch (e) {
        debugPrint('[AuthService] RevenueCat login uyarısı: $e');
      }

      _currentUser = signedInUser;
      await _persistUser(signedInUser);
      _authStateController.add(_currentUser);

      debugPrint('[AuthService] Google ile giriş başarılı: ${signedInUser.displayName} (${signedInUser.email})');
      return signedInUser;
    } catch (e) {
      debugPrint('[AuthService] Google Giriş hatası: $e');
      rethrow;
    }
  }

  /// Apple ID ile Giriş (iOS ve macOS)
  Future<OneiroUser?> signInWithApple() async {
    // Apple platform kontrolü
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) {
      throw UnsupportedError(
        'Apple ile Giriş yalnızca iOS (iPhone / iPad) cihazlarda kullanılabilir.',
      );
    }

    try {
      debugPrint('[AuthService] Apple Giriş akışı başlatılıyor...');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final displayName = (appleCredential.givenName != null || appleCredential.familyName != null)
          ? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim()
          : null;

      OneiroUser signedInUser = OneiroUser(
        uid: appleCredential.userIdentifier ?? 'apple_${DateTime.now().millisecondsSinceEpoch}',
        email: appleCredential.email,
        displayName: displayName,
        isGuest: false,
      );

      if (isFirebaseAvailable) {
        try {
          final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
          final AuthCredential credential = oAuthProvider.credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          );
          final UserCredential userCredential = await auth.signInWithCredential(credential);
          if (userCredential.user != null) {
            signedInUser = OneiroUser.fromFirebase(userCredential.user!);
          }
        } catch (e) {
          debugPrint('[AuthService] Firebase Apple credential uyarısı: $e');
        }
      }

      try {
        await FirestoreService.instance.syncUserRecord(
          uid: signedInUser.uid,
          email: signedInUser.email,
          displayName: displayName ?? signedInUser.displayName,
        );
        await SubscriptionService.instance.logIn(signedInUser.uid);
      } catch (e) {
        debugPrint('[AuthService] Sync uyarısı: $e');
      }

      _currentUser = signedInUser;
      await _persistUser(signedInUser);
      _authStateController.add(_currentUser);

      debugPrint('[AuthService] Apple ile giriş başarılı: ${signedInUser.uid}');
      return signedInUser;
    } catch (e) {
      debugPrint('[AuthService] Apple Giriş hatası: $e');
      rethrow;
    }
  }

  /// Misafir Olarak Giriş
  Future<OneiroUser> signInAsGuest() async {
    final guestUid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final guestUser = OneiroUser(
      uid: guestUid,
      displayName: 'Misafir Seyyah',
      email: null,
      isGuest: true,
    );
    _currentUser = guestUser;
    await _persistUser(guestUser);
    _authStateController.add(_currentUser);
    return guestUser;
  }

  /// Oturumu Kapat
  Future<void> signOut() async {
    try {
      if (isFirebaseAvailable) {
        await auth.signOut();
      }
      await _googleSignIn.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserKey);
      _currentUser = null;
      _authStateController.add(null);
      await SubscriptionService.instance.logOut();
      debugPrint('[AuthService] Oturum güvenle kapatıldı.');
    } catch (e) {
      debugPrint('[AuthService] Çıkış hatası: $e');
    }
  }
}

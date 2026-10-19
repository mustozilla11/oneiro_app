import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firestore_service.dart';
import 'subscription_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

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

  User? get currentUser {
    if (!isFirebaseAvailable) return null;
    try {
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    if (!isFirebaseAvailable) {
      return Stream.value(null);
    }
    try {
      return auth.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Google Hesabı ile Tek Tıkla Giriş
  Future<User?> signInWithGoogle() async {
    if (!isFirebaseAvailable) {
      debugPrint('[AuthService] Firebase aktif değil. Simüle edilmiş Google girişi yapılıyor.');
      return null;
    }

    try {
      debugPrint('[AuthService] Google Giriş akışı başlatılıyor...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[AuthService] Google Giriş kullanıcı tarafından iptal edildi.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        debugPrint('[AuthService] Google ile giriş başarılı: ${user.uid} (${user.email})');
        // Firestore dokümanını senkronize et
        await FirestoreService.instance.syncUserRecord(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
        );

        // RevenueCat ile UID eşleştir
        await SubscriptionService.instance.logIn(user.uid);
      }

      return user;
    } catch (e) {
      debugPrint('[AuthService] Google Giriş hatası: $e');
      rethrow;
    }
  }

  /// Apple ID ile Giriş (iOS ve macOS)
  Future<User?> signInWithApple() async {
    if (!isFirebaseAvailable) {
      debugPrint('[AuthService] Firebase aktif değil. Simüle edilmiş Apple girişi yapılıyor.');
      return null;
    }

    try {
      debugPrint('[AuthService] Apple Giriş akışı başlatılıyor...');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final displayName = (appleCredential.givenName != null || appleCredential.familyName != null)
            ? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim()
            : user.displayName;

        debugPrint('[AuthService] Apple ile giriş başarılı: ${user.uid}');
        // Firestore dokümanını senkronize et
        await FirestoreService.instance.syncUserRecord(
          uid: user.uid,
          email: user.email,
          displayName: displayName,
        );

        // RevenueCat ile UID eşleştir
        await SubscriptionService.instance.logIn(user.uid);
      }

      return user;
    } catch (e) {
      debugPrint('[AuthService] Apple Giriş hatası: $e');
      rethrow;
    }
  }

  /// Oturumu Kapat
  Future<void> signOut() async {
    try {
      if (isFirebaseAvailable) {
        await auth.signOut();
        await _googleSignIn.signOut();
      }
      await SubscriptionService.instance.logOut();
      debugPrint('[AuthService] Oturum güvenle kapatıldı.');
    } catch (e) {
      debugPrint('[AuthService] Çıkış hatası: $e');
    }
  }
}

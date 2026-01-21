
// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Googleログイン（匿名ユーザーなら link してUID維持）
  Future<UserCredential> signInWithGoogleOrLink() async {
    if (kIsWeb) {
      // ✅ Web: Firebase Auth の popup/redirect を使う
      final provider = GoogleAuthProvider();

      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        // 匿名→Googleに昇格（UID維持）
        return await user.linkWithPopup(provider);
      } else {
        // 通常ログイン
        return await _auth.signInWithPopup(provider);
      }
    } else {
      // ✅ Android/iOS: google_sign_in で認証フロー
      final GoogleSignInAccount googleUser =
      await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken は環境/バージョンで無い場合があるので、まずは idToken だけでOK
      );

      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        return await user.linkWithCredential(credential);
      } else {
        return await _auth.signInWithCredential(credential);
      }
    }
  }

  /// ログアウト
  Future<void> signOut() async {
    if (!kIsWeb) {
      // ネイティブはGoogle側のセッションも切る
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }
}

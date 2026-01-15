import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/schedule_service.dart';
import 'services/in_app_notification_service.dart';
import 'ui/home_page.dart';
import 'app.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 匿名ログイン（未ログイン時のみ）
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
      debugPrint('Signed in anonymously. uid=${auth.currentUser?.uid}');
    } on FirebaseAuthException catch (e) {
      debugPrint('Anonymous sign-in failed: ${e.code} ${e.message}');
      // 失敗してもアプリは起動可能
    }
  } else {
    debugPrint('Already signed in. uid=${auth.currentUser?.uid}');
  }

  // ✅ モバイル(将来)に備えて：通知初期化は「必要なプラットフォームのみ」
  // Web/デスクトップではアプリ内通知（SnackBar）を主に使う
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (isMobile) {
    await NotificationService.instance.init();
  }

  InAppNotificationService.instance.bind(SleepCoffeeApp.messengerKey);
  runApp(const SleepCoffeeApp());
}

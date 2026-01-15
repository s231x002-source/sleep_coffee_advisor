
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/in_app_notification_service.dart';
import 'ui/home_page.dart';

class SleepCoffeeApp extends StatelessWidget {
  const SleepCoffeeApp({super.key});

  // ✅ SnackBar表示に必要
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // ✅ 何度呼ばれてもOK。ここで確実にbindしておく
    InAppNotificationService.instance.bind(messengerKey);

    return MaterialApp(
      title: '睡眠×コーヒー提案',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,

      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'NotoSansJP',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'NotoSansJP',
      ),

      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('ja'),
        Locale('en'),
      ],

      home: const HomePage(),
    );
  }
}

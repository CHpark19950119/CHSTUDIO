import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../ui/home_shell.dart';

class DailyApp extends StatelessWidget {
  const DailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAILY',
      debugShowCheckedModeBanner: false,
      theme: buildDailyTheme(brightness: Brightness.light),
      darkTheme: buildDailyTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

/// 사용자 UID 단일 소스 · Firestore users/{uid}/... 경로 베이스
const String kUid = 'sJ8Pxusw9gR0tNR44RhkIge7OiG2';

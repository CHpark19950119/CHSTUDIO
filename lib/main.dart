import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/botanical_theme.dart';
import 'screens/splash_screen.dart';
import 'services/briefing_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const CheonhongApp());
}

class CheonhongApp extends StatefulWidget {
  const CheonhongApp({super.key});

  @override
  State<CheonhongApp> createState() => _CheonhongAppState();
}

/// ★ UL-8: WidgetsBindingObserver로 앱 resume 시 볼륨 복구 보장
class _CheonhongAppState extends State<CheonhongApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ★ UL-8: 앱 복귀 시 미복구 볼륨 체크 → 복구
      BriefingService().ensureVolumeRestored();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHEONHONG STUDIO',
      debugShowCheckedModeBanner: false,
      theme: BotanicalTheme.light(),
      darkTheme: BotanicalTheme.dark(),
      themeMode: ThemeMode.system,

      // ✅ 앱 진입 시 로딩 애니메이션
      home: const SplashScreen(),
    );
  }
}
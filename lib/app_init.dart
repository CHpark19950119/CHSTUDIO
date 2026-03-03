import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

import 'services/alarm_service.dart';
import 'services/focus_timer_service.dart';
import 'services/focus_mode_service.dart';
import 'services/location_service.dart';
import 'services/nfc_service.dart';
import 'services/briefing_service.dart';
import 'services/sleep_service.dart';

class AppInit {
  static Future<void> run() async {
    // ── Phase 0: Locale 초기화 (DateFormat 'ko' 사용 전 필수) ──
    await initializeDateFormatting('ko', null);

    // ── Phase 1: Firebase (필수 선행) ──
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // ── Phase 2: 서비스 초기화 (병렬) ──
    await Future.wait([
      AlarmService().initialize(),
      FocusTimerService().initialize(),
      FocusModeService().initialize(),
      LocationService().initialize(),
      NfcService().initialize(),
      SleepService().initialize(),
    ]);

    // ── Phase 3: 상태 복원 (병렬) ──
    await Future.wait([
      FocusTimerService().restoreState(),
      AlarmService().syncPendingWakeRecords(),
    ]);

    // ── Phase 4: 백그라운드 서비스 ──
    // B10 FIX: GPS 자동 시작 제거 — 외출 NFC 터치 시에만 GPS ON
    // (LocationService._restoreState가 이전 추적 상태를 복원하므로 별도 시작 불필요)

    SleepService().checkAndActivateNightMode();
  }
}
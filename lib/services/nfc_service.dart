/// ═══════════════════════════════════════════════════
///  호환 레이어 — NfcService → DayService 마이그레이션
/// ═══════════════════════════════════════════════════
export 'day_service.dart';

import 'day_service.dart';

/// @deprecated Use DayService
typedef NfcService = DayService;

/// @deprecated Use DayAction
typedef NfcAction = DayAction;

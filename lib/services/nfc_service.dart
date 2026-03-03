import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'firebase_service.dart';
import 'location_service.dart';
import 'briefing_service.dart';
import 'sleep_service.dart';
import 'alarm_service.dart';


/// NFC 태그 서비스 v8.11
/// 5태그: wake(욕실) / ready(책상) / outing(현관,토글) / study(독서대,토글) / meal(식탁,토글)
///
///
class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  static const _nfcChannel =
      MethodChannel('com.cheonhong.cheonhong_studio/nfc');

  List<NfcTagConfig> _tags = [];
  bool _nfcAvailable = false;
  bool _initialized = false;

  bool _isOut = false;
  bool _isStudying = false;
  bool _isMealing = false;
  bool _silentReaderEnabled = false;
  bool _wasStudyingBeforeMeal = false;  // ★ #7: 식사 전 공부 상태 플래그

  /// UI 액션 콜백
  Function(String action, String emoji, String message)? onNfcAction;

  /// 상태 변경 콜백 (NFC 화면 등에서 setState 트리거용)
  VoidCallback? onStateChanged;

  /// 진단용: 마지막 수신 로그
  String lastDiagnostic = '';

  bool _notifPermissionRequested = false;

  bool get isAvailable => _nfcAvailable;
  List<NfcTagConfig> get tags => List.unmodifiable(_tags);
  bool get isOut => _isOut;

  /// 수동으로 외출 상태 강제 설정 (홈 화면 수동 편집용)
  void forceOutState(bool value) {
    _isOut = value;
    _saveToggleState();
    _notifyStateChanged();
  }

  /// 수동으로 공부 상태 강제 설정
  void forceStudyState(bool value) {
    _isStudying = value;
    _saveToggleState();
    _notifyStateChanged();
  }
  bool get isStudying => _isStudying;
  bool get isMealing => _isMealing;
  bool get isSilentReaderEnabled => _silentReaderEnabled;

  void _log(String msg) {
    debugPrint('[NFC] $msg');
    lastDiagnostic = '${DateFormat('HH:mm:ss').format(DateTime.now())} $msg';
  }

  /// ★ 학습일 기준 날짜 (04:00 이전은 전날로 간주 — home_screen과 동일 기준)
  String _studyDate([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final effective = now.hour < 4
        ? now.subtract(const Duration(days: 1))
        : now;
    return DateFormat('yyyy-MM-dd').format(effective);
  }

  // ─── 초기화 ───
  Future<void> initialize() async {
    if (_initialized) {
      _log('⚠️ 이미 초기화됨 — 스킵');
      return;
    }

    _log('═══ 초기화 시작 ═══');

    try {
      _nfcAvailable = await NfcManager.instance.isAvailable();
      _log('NFC 사용 가능: $_nfcAvailable');
    } catch (e) {
      _nfcAvailable = false;
      _log('❌ NFC 가용성 체크 실패: $e');
    }

    await _loadTags();
    _log('태그 로드 완료: ${_tags.length}개');

    await _restoreToggleState();
    _log('토글 복원: isOut=$_isOut, isStudying=$_isStudying');

    _setupMethodChannel();
    _log('MethodChannel 핸들러 설정 완료');

    // Flutter 준비 완료 신호
    try {
      await _nfcChannel.invokeMethod('flutterReady');
      _log('✅ flutterReady 신호 전송 성공');
    } catch (e) {
      _log('❌ flutterReady 전송 실패: $e');
    }

    // F10 FIX: 앱 시작 시 대기 중인 NFC Intent 즉시 처리
    // 앱이 NFC 태그로 인해 cold-start된 경우, Intent가 Flutter ready 전에 도착
    // → flutterReady 직후 pendingNfcIntent를 명시적으로 요청
    try {
      final pending = await _nfcChannel.invokeMethod<Map>('getPendingNfcIntent');
      if (pending != null) {
        final role = pending['role']?.toString() ?? '';
        final tagUid = pending['tagUid']?.toString() ?? '';
        _log('📨 대기 Intent 발견: role=$role, tagUid=$tagUid');
        if (role.isNotEmpty) {
          await _handleAutoAction(role, tagUid.isNotEmpty ? tagUid : null);
          _notifyStateChanged();
        } else if (tagUid.isNotEmpty) {
          final matched = _matchTag(tagUid);
          if (matched != null) {
            await _executeRole(matched);
            _notifyStateChanged();
          }
        }
      }
    } catch (e) {
      _log('⚠️ pendingNfcIntent 조회 실패 (구버전 native): $e');
    }

    // Android 13+ 알림 권한 요청 (NFC 처리 결과를 상단바 알림으로 표시)
    await _requestNotificationPermissionOnce();

    _initialized = true;
    _log('═══ 초기화 완료 ═══');
  }

  Future<void> reloadTags() async {
    await _loadTags();
    _log('태그 리로드: ${_tags.length}개');
  }

  // ─── B3: 무진동 리더 모드 ───

  Future<void> enableSilentReader() async {
    _log('무진동 모드 활성화 시도...');
    if (!_nfcAvailable) {
      _log('❌ NFC 불가 — 무진동 불가');
      return;
    }
    try {
      await _nfcChannel.invokeMethod('enableSilentReader');
      _silentReaderEnabled = true;
      _log('✅ 무진동 모드 ON');
    } catch (e) {
      _log('❌ enableSilentReader 에러: $e');
    }
  }

  Future<void> disableSilentReader() async {
    try {
      await _nfcChannel.invokeMethod('disableSilentReader');
      _silentReaderEnabled = false;
      _log('✅ 무진동 모드 OFF');
    } catch (e) {
      _log('❌ disableSilentReader 에러: $e');
    }
  }

  // ─── MethodChannel 리스너 ───

  void _setupMethodChannel() {
    _nfcChannel.setMethodCallHandler((call) async {
      _log('📨 MethodCall 수신: ${call.method}');

      if (call.method == 'onNfcTagFromIntent') {
        final args = call.arguments;
        _log('📨 arguments type: ${args.runtimeType}');

        final uri = _argStr(args, 'uri');
        final role = _argStr(args, 'role');
        final tagUid = _argStr(args, 'tagUid');

        _log('═══ NFC Intent 수신 ═══');
        _log('  role="$role" (empty=${role.isEmpty})');
        _log('  tagUid="$tagUid" (empty=${tagUid.isEmpty})');
        _log('  uri="$uri"');

        if (role.isNotEmpty) {
          _log('→ handleAutoAction(role=$role)');
          await _handleAutoAction(role, tagUid.isNotEmpty ? tagUid : null);
        } else if (tagUid.isNotEmpty) {
          _log('→ UID 매칭 시도: $tagUid');
          final matched = _matchTag(tagUid);
          if (matched != null) {
            _log('→ 매칭 성공: ${matched.name} (${matched.role.name})');
            await _executeRole(matched);
          } else {
            _log('⚠️ 미등록 태그: $tagUid');
          }
        } else {
          _log('⚠️ role/tagUid 모두 비어있음');
        }

        _notifyStateChanged();
      }
    });
  }

  /// 안전한 argument 추출 (null/타입 방어)
  String _argStr(dynamic args, String key) {
    try {
      if (args is Map) {
        final v = args[key];
        if (v == null) return '';
        return v.toString();
      }
    } catch (_) {}
    return '';
  }

  void _notifyStateChanged() {
    _log('📢 상태 변경 알림 (isOut=$_isOut, isStudying=$_isStudying)');
    try {
      onStateChanged?.call();
    } catch (e) {
      _log('❌ onStateChanged 콜백 에러: $e');
    }
  }

  // ─── 수동 테스트용 ───

  /// 진단: 수동으로 role 실행 테스트 (NFC 하드웨어 우회)
  Future<String> manualTestRole(NfcTagRole role) async {
    _log('🧪 수동 테스트: ${role.name}');
    try {
      final now = DateTime.now();
      final dateStr = _studyDate(now);
      final timeStr = DateFormat('HH:mm').format(now);

      switch (role) {
        case NfcTagRole.wake:
          await _handleWake(dateStr, timeStr);
          break;
        case NfcTagRole.ready:
          await _handleReady(dateStr, timeStr);
          break;
        case NfcTagRole.outing:
          await _handleOutingToggle(dateStr, timeStr);
          break;
        case NfcTagRole.study:
          await _handleStudyToggle(dateStr, timeStr);
          break;
        case NfcTagRole.sleep:
          await _handleSleep(dateStr, timeStr);
          break;
        case NfcTagRole.meal:
          await _handleMealToggle(dateStr, timeStr);
          break;
      }
      _notifyStateChanged();
      return '✅ ${role.name} 실행 성공 (isOut=$_isOut, isStudying=$_isStudying)';
    } catch (e) {
      return '❌ 에러: $e';
    }
  }

  // ─── NDEF URI role → 자동 실행 ───

  Future<void> _handleAutoAction(String roleName, String? tagUid) async {
    NfcTagRole? role;
    try {
      role = NfcTagRole.values.firstWhere((r) => r.name == roleName);
    } catch (_) {
      _log('❌ 알 수 없는 role: "$roleName"');
      return;
    }

    _log('✅ role 매칭: ${role.name}');

    final now = DateTime.now();
    final dateStr = _studyDate(now);
    final timeStr = DateFormat('HH:mm').format(now);

    String? action;
    switch (role) {
      case NfcTagRole.outing:
        action = _isOut ? 'end' : 'start';
        break;
      case NfcTagRole.study:
        action = _isStudying ? 'end' : 'start';
        break;
      case NfcTagRole.meal:
        action = _isMealing ? 'end' : 'start';
        break;
      default:
        break;
    }

    final event = NfcEvent(
      id: 'nfc_${now.millisecondsSinceEpoch}',
      date: dateStr,
      timestamp: now.toIso8601String(),
      role: role,
      tagName: _findTagName(tagUid) ?? role.name,
      action: action,
    );
    try {
      await FirebaseService().saveNfcEvent(dateStr, event);
      _log('이벤트 저장 완료');
    } catch (e) {
      _log('⚠️ 이벤트 저장 실패: $e');
    }

    switch (role) {
      case NfcTagRole.wake:
        await _handleWake(dateStr, timeStr);
        break;
      case NfcTagRole.ready:
        await _handleReady(dateStr, timeStr);
        break;
      case NfcTagRole.outing:
        await _handleOutingToggle(dateStr, timeStr);
        break;
      case NfcTagRole.study:
        await _handleStudyToggle(dateStr, timeStr);
        break;
      case NfcTagRole.sleep:
        await _handleSleep(dateStr, timeStr);
        break;
      case NfcTagRole.meal:
        await _handleMealToggle(dateStr, timeStr);
        break;
    }
  }

  String? _findTagName(String? uid) {
    if (uid == null) return null;
    for (final t in _tags) {
      if (t.nfcId?.toLowerCase() == uid.toLowerCase()) return t.name;
    }
    return null;
  }

  // ─── NFC 태그 스캔 (수동, NFC 화면용) ───
  Future<void> startScan({
    required Function(NfcTagConfig? matchedTag, String nfcUid) onDetected,
    required Function(String error) onError,
  }) async {
    if (!_nfcAvailable) {
      onError('NFC를 사용할 수 없습니다');
      return;
    }

    if (_silentReaderEnabled) {
      await disableSilentReader();
    }

    // F10 FIX: 이전 세션이 완전히 정리되도록 보장
    try { NfcManager.instance.stopSession(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        try {
          final uid = _extractUid(tag);
          if (uid == null) {
            onError('태그 UID를 읽을 수 없습니다');
            NfcManager.instance.stopSession();
            return;
          }
          _log('수동 스캔 감지: UID=$uid');
          final matched = _matchTag(uid);
          onDetected(matched, uid);
          if (matched != null) {
            await _executeRole(matched);
            _notifyStateChanged();
          }
          NfcManager.instance.stopSession();
        } catch (e) {
          onError('태그 읽기 실패: $e');
          NfcManager.instance.stopSession();
        }
      },
    );
  }

  void stopScan() {
    try { NfcManager.instance.stopSession(); } catch (_) {}
  }

  String? _extractUid(NfcTag tag) {
    try {
      final data = tag.data;
      for (final key in ['nfca', 'nfcb', 'nfcf', 'nfcv', 'mifareclassic', 'mifareultralight']) {
        final tech = data[key];
        if (tech != null && tech is Map) {
          final id = tech['identifier'];
          if (id != null && id is List) {
            return id.cast<int>()
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':');
          }
        }
      }
    } catch (e) {
      _log('UID 추출 실패: $e');
    }
    return null;
  }

  NfcTagConfig? _matchTag(String uid) {
    for (final t in _tags) {
      if (t.nfcId != null && t.nfcId!.toLowerCase() == uid.toLowerCase()) {
        return t;
      }
    }
    return null;
  }

  // ══════════════════════════════════════════
  //  역할별 동작 실행
  // ══════════════════════════════════════════

  Future<void> _executeRole(NfcTagConfig tag) async {
    final now = DateTime.now();
    // ★ FIX: 04:00 이전은 전날 날짜로 기록 (home_screen과 동일 기준)
    final dateStr = _studyDate(now);
    final timeStr = DateFormat('HH:mm').format(now);

    String? action;
    switch (tag.role) {
      case NfcTagRole.outing:
        action = _isOut ? 'end' : 'start';
        break;
      case NfcTagRole.study:
        action = _isStudying ? 'end' : 'start';
        break;
      case NfcTagRole.meal:
        action = _isMealing ? 'end' : 'start';
        break;
      default:
        break;
    }

    final event = NfcEvent(
      id: 'nfc_${now.millisecondsSinceEpoch}',
      date: dateStr,
      timestamp: now.toIso8601String(),
      role: tag.role,
      tagName: tag.name,
      action: action,
    );
    try {
      await FirebaseService().saveNfcEvent(dateStr, event);
    } catch (_) {}

    switch (tag.role) {
      case NfcTagRole.wake:
        await _handleWake(dateStr, timeStr);
        break;
      case NfcTagRole.ready:
        await _handleReady(dateStr, timeStr);
        break;
      case NfcTagRole.outing:
        await _handleOutingToggle(dateStr, timeStr);
        break;
      case NfcTagRole.study:
        await _handleStudyToggle(dateStr, timeStr);
        break;
      case NfcTagRole.sleep:
        await _handleSleep(dateStr, timeStr);
        break;
      case NfcTagRole.meal:
        await _handleMealToggle(dateStr, timeStr);
        break;
    }
  }

  // ══════════════════════════════════════════
  //  🚿 기상 (wake)
  // ══════════════════════════════════════════

  Future<void> _handleWake(String dateStr, String timeStr) async {
    _log('🚿 기상 처리 시작: $dateStr $timeStr');

    // ★ B1 FIX: 기상 태그 시 알람/진동 즉시 중지
    try {
      await AlarmService.stopVibrationByNfc();
      _log('🛑 알람/진동 해제 완료 (기상 NFC)');
    } catch (e) {
      _log('⚠️ 알람 해제 실패 (계속 진행): $e');
    }

    try {
      final fb = FirebaseService();
      final records = await fb.getTimeRecords();
      final existing = records[dateStr];
      if (existing?.wake != null) {
        _log('이미 기상 기록됨: ${existing!.wake}');
        onNfcAction?.call('wake_already', '🚿', '이미 기상 기록됨 (${existing.wake})');
        return;
      }

      await fb.updateTimeRecord(dateStr, TimeRecord(
        date: dateStr, wake: timeStr,
        study: existing?.study, studyEnd: existing?.studyEnd,
        outing: existing?.outing, returnHome: existing?.returnHome,
        mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
        meals: existing?.meals,
      ));
      _log('✅ 기상시간 기록 완료: $timeStr');

      // B7 FIX: 기상 기록 성공 알림 추가
      await _notifyNativeResult(title: '✅ 기상 인증', body: '기상시간 $timeStr 기록 완료');

      // ★ FIX: 수면 기록 완성 (SleepRecord에 wakeTime + sleepMinutes 기록)
      try {
        final sleepGrade = await SleepService().completeWakeRecord(timeStr);
        if (sleepGrade != null) {
          _log('💤 수면기록 완성: ${sleepGrade.totalScore.round()}점 ${sleepGrade.grade}등급 '
              '(수면 ${sleepGrade.durationScore.round()}/25)');
        } else {
          _log('⚠️ 수면기록 완성 — SleepRecord 없음 (전날 취침 미기록)');
        }
      } catch (e) {
        _log('⚠️ 수면기록 완성 실패: $e');
      }

      // N6: 새 하루 시작 (수면모드 해제 + 하루 종료 마킹 초기화)
      await SleepService().startNewDay();
      _log('✅ 새 하루 시작 — 수면모드 해제');

      // 토글 상태 초기화 (새 하루)
      _isOut = false;
      _isStudying = false;
      _isMealing = false;
      await _saveToggleState();

      onNfcAction?.call('wake', '🚿', '기상시간 $timeStr 기록');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_qr_wake');
      await prefs.remove('pending_qr_wake_time');
      _triggerWidgetUpdate();
    } catch (e) {
      _log('❌ Wake 에러: $e');
      await _notifyNativeResult(title: '⚠️ NFC 처리 실패', body: '기상 기록 실패');
    }
  }

  // ══════════════════════════════════════════
  //  📖 준비완료 (ready)
  // ══════════════════════════════════════════

  // ══════════════════════════════════════════
  //  📖 준비완료 (ready) — v8.8 TTS FIX
  // ══════════════════════════════════════════

  Future<void> _handleReady(String dateStr, String timeStr) async {
    _log('📖 준비완료 처리 시작: $timeStr');

    // 1) 알림 먼저 (TTS 실패해도 사용자에게 피드백)
    await _notifyNativeResult(title: '📖 준비완료', body: '모닝 브리핑 시작 $timeStr');
    onNfcAction?.call('ready', '📖', '모닝 브리핑 시작 $timeStr');

    // 2) 준비완료 시간만 Firebase에 기록 (공부시작은 독서대 NFC에서 처리)
    try {
      // ready 태그는 브리핑 전용 — 공부시작 기록은 study(독서대) 태그에서 처리
      _log('📖 준비완료 (브리핑 전용 — 공부시작은 독서대 태그)');
    } catch (e) {
      _log('⚠️ 준비완료 처리 실패: $e');
    }

    // 3) TTS 브리핑 (비동기 — 실패해도 나머지 NFC 처리 영향 없음)
    try {
      _log('🔊 BriefingService 호출...');
      await BriefingService().playMorningBriefing();
      _log('✅ 브리핑 시작됨');
    } catch (e) {
      _log('❌ TTS 브리핑 실패: $e');
      // TTS 실패해도 NFC 처리는 완료 — 알림으로 대체
      await _notifyNativeResult(title: '⚠️ 브리핑 실패', body: 'TTS 엔진 오류: $e');
    }
  }

  // ══════════════════════════════════════════
  //  🚪 외출/귀가 토글 (outing)
  // ══════════════════════════════════════════

  Future<void> _handleOutingToggle(String dateStr, String timeStr) async {
    _log('🚪 외출 토글: 현재 isOut=$_isOut → ${!_isOut}');
    try {
      final fb = FirebaseService();
      final records = await fb.getTimeRecords();
      final existing = records[dateStr];

      if (!_isOut) {
        _isOut = true;
        await fb.updateTimeRecord(dateStr, TimeRecord(
          date: dateStr, wake: existing?.wake,
          study: existing?.study, studyEnd: existing?.studyEnd,
          outing: timeStr, returnHome: null,
          arrival: existing?.arrival, bedTime: existing?.bedTime,
          mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
          meals: existing?.meals,
        ));
        _log('✅ 외출 기록: $timeStr');

        // GPS 추적 시작 (미추적 중이면 시작 + 이동모드)
        final loc = LocationService();
        if (!loc.isTracking) {
          await loc.startTracking();
          _log('📍 GPS 추적 자동 시작 (외출 NFC)');
        }
        loc.setTravelMode(true);

        await _notifyNativeResult(title: '✅ NFC 처리 완료', body: '외출 시작 $timeStr 📍GPS ON');
        onNfcAction?.call('outing_start', '🚪', '외출 $timeStr (GPS 추적 시작)');
      } else {
        _isOut = false;
        await fb.updateTimeRecord(dateStr, TimeRecord(
          date: dateStr, wake: existing?.wake,
          study: existing?.study, studyEnd: existing?.studyEnd,
          outing: existing?.outing, returnHome: timeStr,
          arrival: existing?.arrival, bedTime: existing?.bedTime,
          mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
          meals: existing?.meals,
        ));
        _log('✅ 귀가 기록: $timeStr');

        // GPS "집" 체류로 마무리 + 추적 종료 (항상)
        final loc = LocationService();
        loc.forceCurrentPlaceAsHome();
        if (loc.isTracking) {
          await loc.stopTracking();
          _log('📍 GPS → 집 체류 마무리 + 추적 종료');
        }
        loc.setTravelMode(false);

        // 외출 총시간 계산
        final updatedTR = TimeRecord(
          date: dateStr, outing: existing?.outing, returnHome: timeStr,
        );
        final outMin = updatedTR.outingMinutes;
        final durText = updatedTR.outingFormatted ?? '';
        final durMsg = durText.isNotEmpty ? ' (외출 $durText)' : '';

        await _notifyNativeResult(title: '✅ NFC 처리 완료', body: '귀가 $timeStr$durMsg');

        final tr = TimeRecord(
          date: dateStr, outing: existing?.outing,
          study: existing?.study, studyEnd: existing?.studyEnd,
          returnHome: timeStr,
        );
        final commuteFrom = tr.commuteFromMinutes;
        if (commuteFrom != null && commuteFrom > 0) {
          onNfcAction?.call('outing_end', '🏠', '귀가 $timeStr (하교 ${commuteFrom}분)$durMsg');
        } else {
          onNfcAction?.call('outing_end', '🏠', '귀가 $timeStr$durMsg 📍GPS OFF');
        }
      }

      await _saveToggleState();
      _notifyStateChanged();
    } catch (e) {
      _log('❌ Outing 에러: $e');
      await _notifyNativeResult(title: '⚠️ NFC 처리 실패', body: '외출 토글 실패');
    }
  }

  // ══════════════════════════════════════════
  //  📚 공부시작/종료 토글 (study)
  // ══════════════════════════════════════════

  Future<void> _handleStudyToggle(String dateStr, String timeStr) async {
    _log('📚 공부 토글: 현재 isStudying=$_isStudying → ${!_isStudying}');
    try {
      final fb = FirebaseService();
      final records = await fb.getTimeRecords();
      final existing = records[dateStr];

      if (!_isStudying) {
        _isStudying = true;
        await fb.updateTimeRecord(dateStr, TimeRecord(
          date: dateStr, wake: existing?.wake,
          study: timeStr, studyEnd: existing?.studyEnd,
          outing: existing?.outing, returnHome: existing?.returnHome,
          arrival: existing?.arrival, bedTime: existing?.bedTime,
          mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
          meals: existing?.meals,
        ));
        _log('✅ 공부시작: $timeStr');
        await _notifyNativeResult(title: '✅ NFC 처리 완료', body: '공부 시작 $timeStr');

        final tr = TimeRecord(date: dateStr, outing: existing?.outing, study: timeStr);
        final commuteTo = tr.commuteToMinutes;
        if (commuteTo != null && commuteTo > 0) {
          onNfcAction?.call('study_start', '📚', '공부시작 $timeStr (등교 ${commuteTo}분)');
        } else {
          onNfcAction?.call('study_start', '📚', '공부시작 $timeStr');
        }
        _triggerWidgetUpdate();
      } else {
        _isStudying = false;
        await fb.updateTimeRecord(dateStr, TimeRecord(
          date: dateStr, wake: existing?.wake,
          study: existing?.study, studyEnd: timeStr,
          outing: existing?.outing, returnHome: existing?.returnHome,
          arrival: existing?.arrival, bedTime: existing?.bedTime,
          mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
          meals: existing?.meals,
        ));
        _log('✅ 공부종료: $timeStr');
        await _notifyNativeResult(title: '✅ NFC 처리 완료', body: '공부 종료 $timeStr');

        final tr = TimeRecord(date: dateStr, study: existing?.study, studyEnd: timeStr);
        final stay = tr.stayMinutes;
        if (stay != null && stay > 0) {
          final h = stay ~/ 60; final m = stay % 60;
          onNfcAction?.call('study_end', '📚', '공부종료 $timeStr (체류 ${h}h${m}m)');
        } else {
          onNfcAction?.call('study_end', '📚', '공부종료 $timeStr');
        }
      }

      await _saveToggleState();
      _notifyStateChanged();
    } catch (e) {
      _log('❌ Study 에러: $e');
      await _notifyNativeResult(title: '⚠️ NFC 처리 실패', body: '공부 토글 실패');
    }
  }


  // ══════════════════════════════════════════
  //  🛏️ 수면시작 (sleep)
  // ══════════════════════════════════════════

  Future<void> _handleSleep(String dateStr, String timeStr) async {
    _log('🛏️ 수면시작 처리: $dateStr $timeStr');
    try {
      final fb = FirebaseService();
      final records = await fb.getTimeRecords();

      // ★ UL-2: 오전 4시~7시 사이 → 전날 bedTime이 없으면 전날로 귀속
      final now = DateTime.now();
      String effectiveDate = dateStr;
      if (now.hour >= 4 && now.hour < 7) {
        final yesterday = DateFormat('yyyy-MM-dd').format(
            now.subtract(const Duration(days: 1)));
        final yesterdayTR = records[yesterday];
        if (yesterdayTR?.bedTime == null) {
          _log('🛏️ UL-2: 전날($yesterday) bedTime 미기록 → 전날로 귀속');
          effectiveDate = yesterday;
        }
      }
      dateStr = effectiveDate;

      final existing = records[dateStr];

      // 1) TimeRecord에 bedTime 기록
      await fb.updateTimeRecord(dateStr, TimeRecord(
        date: dateStr,
        wake: existing?.wake,
        study: existing?.study,
        studyEnd: existing?.studyEnd,
        outing: existing?.outing,
        returnHome: existing?.returnHome,
        arrival: existing?.arrival,
        bedTime: timeStr,
        mealStart: existing?.mealStart,
        mealEnd: existing?.mealEnd,
        meals: existing?.meals,
      ));
      _log('✅ 취침시간 기록: $timeStr');

      // 2) ★ FIX: SleepService.enterSleepMode 호출
      //    → SleepRecord 생성 + 야간모드 + 하루종료 마킹 + 화면 모니터링
      try {
        await SleepService().enterSleepMode(dateStr, timeStr);
        _log('🌙 수면모드 진입 완료 (enterSleepMode)');
      } catch (e) {
        _log('⚠️ 수면모드 진입 실패: $e');
        // 폴백: 최소한 야간모드만이라도 활성화
        try {
          await SleepService().activateNightMode();
        } catch (_) {}
      }

      // 3) 진행 중 공부/외출 토글 정리
      if (_isStudying) {
        _isStudying = false;
        // 공부종료 기록 (취침 전 자동 종료)
        if (existing?.study != null && existing?.studyEnd == null) {
          await fb.updateTimeRecord(dateStr, TimeRecord(
            date: dateStr, wake: existing?.wake,
            study: existing?.study, studyEnd: timeStr,
            outing: existing?.outing, returnHome: existing?.returnHome,
            arrival: existing?.arrival, bedTime: timeStr,
            mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
            meals: existing?.meals,
          ));
          _log('📚 공부 자동종료 (취침): $timeStr');
        }
      }
      if (_isMealing) {
        _isMealing = false;
        // ★ 진행 중인 식사 자동 종료 (meals 배열에서)
        final updatedMeals = List<MealEntry>.from(existing?.meals ?? []);
        final openIdx = updatedMeals.lastIndexWhere((m) => m.end == null);
        if (openIdx >= 0) {
          updatedMeals[openIdx] = updatedMeals[openIdx].withEnd(timeStr);
        }
        await fb.updateTimeRecord(dateStr, TimeRecord(
          date: dateStr, wake: existing?.wake,
          study: existing?.study, studyEnd: existing?.studyEnd,
          outing: existing?.outing, returnHome: existing?.returnHome,
          arrival: existing?.arrival, bedTime: timeStr,
          mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
          meals: updatedMeals,
        ));
        _log('🍽️ 식사 자동종료 (취침): $timeStr');
      }
      await _saveToggleState();

      await _notifyNativeResult(title: '🛏️ 수면시작', body: '취침 $timeStr — 좋은 밤 되세요');
      onNfcAction?.call('sleep', '🛏️', '취침시간 $timeStr 기록');
      _triggerWidgetUpdate();
    } catch (e) {
      _log('❌ Sleep 에러: $e');
      await _notifyNativeResult(title: '⚠️ NFC 처리 실패', body: '수면 기록 실패');
    }
  }


  // ══════════════════════════════════════════
  //  🍽️ 식사 토글 (meal)
  // ══════════════════════════════════════════

  Future<void> _handleMealToggle(String dateStr, String timeStr) async {
    _log('🍽️ 식사 토글: 현재 isMealing=$_isMealing → ${!_isMealing}');
    try {
      final fb = FirebaseService();
      final records = await fb.getTimeRecords();
      final existing = records[dateStr];
      final currentMeals = List<MealEntry>.from(existing?.meals ?? []);

      if (!_isMealing) {
        // ★ #7: 식사 시작 시 공부 상태 저장
        _wasStudyingBeforeMeal = _isStudying;
        _log('💾 식사 전 공부 상태 저장: $_wasStudyingBeforeMeal');

        // 식사 시작 — 새 MealEntry 추가
        _isMealing = true;
        currentMeals.add(MealEntry(start: timeStr));

        await fb.updateTimeRecord(dateStr, TimeRecord(
          date: dateStr, wake: existing?.wake,
          study: existing?.study, studyEnd: existing?.studyEnd,
          outing: existing?.outing, returnHome: existing?.returnHome,
          arrival: existing?.arrival, bedTime: existing?.bedTime,
          mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
          meals: currentMeals,
        ));
        _log('✅ 식사 시작 (${currentMeals.length}번째): $timeStr');
        await _notifyNativeResult(title: '🍽️ 식사 시작', body: '식사 시작 $timeStr (${currentMeals.length}번째)');
        onNfcAction?.call('meal_start', '🍽️', '식사 시작 $timeStr');
      } else {
        // 식사 종료 — 마지막 열린 MealEntry에 end 설정
        _isMealing = false;
        final openIdx = currentMeals.lastIndexWhere((m) => m.end == null);
        if (openIdx >= 0) {
          currentMeals[openIdx] = currentMeals[openIdx].withEnd(timeStr);
        }

        await fb.updateTimeRecord(dateStr, TimeRecord(
          date: dateStr, wake: existing?.wake,
          study: existing?.study, studyEnd: existing?.studyEnd,
          outing: existing?.outing, returnHome: existing?.returnHome,
          arrival: existing?.arrival, bedTime: existing?.bedTime,
          mealStart: existing?.mealStart, mealEnd: existing?.mealEnd,
          meals: currentMeals,
        ));
        _log('✅ 식사 종료: $timeStr');

        final lastMeal = openIdx >= 0 ? currentMeals[openIdx] : null;
        final durMsg = lastMeal?.durationFormatted != null ? ' (${lastMeal!.durationFormatted})' : '';

        // ★ #7: 식사 전 공부 중이었으면 공부 상태 유지 + 복귀 알림
        if (_wasStudyingBeforeMeal) {
          _isStudying = true;
          _wasStudyingBeforeMeal = false;
          _log('📚 공부 상태 복귀 (식사 전 공부 중이었음)');
          await _notifyNativeResult(
            title: '🍽️ 식사 종료 → 📚 공부 복귀',
            body: '식사 종료 $timeStr$durMsg — 공부 모드로 복귀합니다');
          onNfcAction?.call('meal_end_study_resume', '📚', '식사 종료$durMsg → 공부 복귀');
        } else {
          await _notifyNativeResult(title: '🍽️ 식사 종료', body: '식사 종료 $timeStr$durMsg');
          onNfcAction?.call('meal_end', '🍽️', '식사 종료 $timeStr$durMsg');
        }
      }
      await _saveToggleState();
      _triggerWidgetUpdate();
    } catch (e) {
      _log('❌ Meal 에러: $e');
      await _notifyNativeResult(title: '⚠️ NFC 처리 실패', body: '식사 기록 실패');
    }
  }


  void _triggerWidgetUpdate() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('widget_needs_update', true);
      } catch (_) {}
    });
  }

  // ══════════════════════════════════════════
  //  토글 상태 저장/복원
  // ══════════════════════════════════════════

  Future<void> _saveToggleState() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = _studyDate(); // ★ FIX: 04:00 기준
    await prefs.setBool('nfc_is_out', _isOut);
    await prefs.setBool('nfc_is_studying', _isStudying);
    await prefs.setBool('nfc_is_mealing', _isMealing);
    await prefs.setBool('nfc_was_studying_before_meal', _wasStudyingBeforeMeal);
    await prefs.setString('nfc_toggle_date', dateStr);
    _log('토글 저장: isOut=$_isOut, isStudying=$_isStudying, isMealing=$_isMealing, wasStudyBM=$_wasStudyingBeforeMeal ($dateStr)');
  }

  Future<void> _restoreToggleState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('nfc_toggle_date');
    final today = _studyDate(); // ★ FIX: 04:00 기준

    if (savedDate == today) {
      _isOut = prefs.getBool('nfc_is_out') ?? false;
      _isStudying = prefs.getBool('nfc_is_studying') ?? false;
      _isMealing = prefs.getBool('nfc_is_mealing') ?? false;
      _wasStudyingBeforeMeal = prefs.getBool('nfc_was_studying_before_meal') ?? false;
    } else {
      _isOut = false;
      _isStudying = false;
      _isMealing = false;
      _wasStudyingBeforeMeal = false;
      await _saveToggleState();
    }
  }

  // ══════════════════════════════════════════
  //  NDEF 쓰기
  // ══════════════════════════════════════════

  Future<bool> writeNdefToTag({
    required NfcTagRole role,
    required String tagId,
    required Function(String) onStatus,
  }) async {
    if (!_nfcAvailable) return false;

    if (_silentReaderEnabled) {
      await disableSilentReader();
    }

    try { NfcManager.instance.stopSession(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));

    final completer = Completer<bool>();
    onStatus('📱 태그를 가까이 대세요...');

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (NfcTag tag) async {
        try {
          final uri = 'cheonhong://nfc?role=${role.name}&tagId=$tagId';
          _log('NDEF 쓰기 URI: $uri');
          final uriRecord = NdefRecord.createUri(Uri.parse(uri));
          final aarRecord = NdefRecord(
            typeNameFormat: NdefTypeNameFormat.nfcExternal,
            type: Uint8List.fromList('android.com:pkg'.codeUnits),
            identifier: Uint8List(0),
            payload: Uint8List.fromList('com.cheonhong.cheonhong_studio'.codeUnits),
          );
          final message = NdefMessage([uriRecord, aarRecord]);

          bool written = false;
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            if (ndef.isWritable) {
              await ndef.write(message);
              written = true;
            } else {
              onStatus('❌ 태그가 쓰기 금지 상태입니다');
            }
          } else {
            onStatus('❌ NDEF 미지원 태그입니다');
          }

          NfcManager.instance.stopSession();
          if (written) {
            _log('✅ NDEF 쓰기 성공');
            onStatus('✅ NDEF 쓰기 완료!');
          }
          if (!completer.isCompleted) completer.complete(written);
        } catch (e) {
          _log('❌ NDEF 쓰기 실패: $e');
          NfcManager.instance.stopSession(errorMessage: 'NDEF 쓰기 실패');
          onStatus('❌ 쓰기 실패: $e');
          if (!completer.isCompleted) completer.complete(false);
        }
      },
      onError: (error) async {
        onStatus('❌ NFC 세션 오류');
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        try { NfcManager.instance.stopSession(); } catch (_) {}
        onStatus('⏰ 시간 초과');
        completer.complete(false);
      }
    });

    return completer.future;
  }

  // ══════════════════════════════════════════
  //  태그 CRUD
  // ══════════════════════════════════════════

  Future<NfcTagConfig> registerTag({
    required String name,
    required NfcTagRole role,
    required String nfcUid,
  }) async {
    final tag = NfcTagConfig(
      id: 'nfc_tag_${DateTime.now().millisecondsSinceEpoch}',
      name: name, role: role, nfcId: nfcUid,
      createdAt: DateTime.now().toIso8601String(),
    );
    _tags.add(tag);
    await FirebaseService().saveNfcTags(_tags);
    return tag;
  }

  Future<void> removeTag(String tagId) async {
    _tags.removeWhere((NfcTagConfig t) => t.id == tagId);
    await FirebaseService().saveNfcTags(_tags);
  }

  Future<void> updateTagRole(String tagId, NfcTagRole newRole) async {
    final idx = _tags.indexWhere((NfcTagConfig t) => t.id == tagId);
    if (idx < 0) return;
    final old = _tags[idx];
    _tags[idx] = NfcTagConfig(
      id: old.id, name: old.name, role: newRole,
      nfcId: old.nfcId, createdAt: old.createdAt,
    );
    await FirebaseService().saveNfcTags(_tags);
  }

  Future<void> _loadTags() async {
    try {
      _tags = await FirebaseService().getNfcTags();
    } catch (_) {
      _tags = [];
    }
  }

  // ══════════════════════════════════════════
  //  이동시간 계산 유틸
  // ══════════════════════════════════════════

  Future<Map<String, int?>> getTodayTravelSummary() async {
    final dateStr = _studyDate(); // ★ FIX: 04:00 기준
    try {
      final records = await FirebaseService().getTimeRecords();
      final tr = records[dateStr];
      if (tr == null) return {};
      return {
        'commuteTo': tr.commuteToMinutes,
        'commuteFrom': tr.commuteFromMinutes,
        'stayTime': tr.stayMinutes,
      };
    } catch (_) {
      return {};
    }
  }
  // ══════════════════════════════════════════
  //  알림 권한 + 네이티브 알림
  // ══════════════════════════════════════════

  /// Android 13+ 알림 권한 요청 (1회만)
  Future<void> _requestNotificationPermissionOnce() async {
    if (_notifPermissionRequested) return;
    _notifPermissionRequested = true;
    try {
      await _nfcChannel.invokeMethod('requestNotificationPermission');
      _log('✅ 알림 권한 요청 완료');
    } catch (e) {
      _log('⚠️ 알림 권한 요청 실패 (무시): $e');
    }
  }

  /// 네이티브 알림 표시 (NFC 처리 결과를 상단바에 표시)
  Future<void> _notifyNativeResult({
    required String title,
    required String body,
  }) async {
    try {
      await _nfcChannel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
      });
      _log('📢 알림 표시: $title — $body');
    } catch (e) {
      _log('⚠️ 알림 표시 실패 (무시): $e');
    }
  }
}
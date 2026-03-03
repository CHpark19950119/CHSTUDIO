import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// CHEONHONG STUDIO — Overwatch 자동감지 서비스
/// Cloud Functions 폴링 설정 관리 + 감지 결과 실시간 스트림
/// ═══════════════════════════════════════════════════════════

class OverwatchPollingService {
  static final OverwatchPollingService _inst = OverwatchPollingService._();
  factory OverwatchPollingService() => _inst;
  OverwatchPollingService._();

  static const String _uid = 'sJ8Pxusw9gR0tNR44RhkIge7OiG2';
  static const String _settingsPath = 'users/$_uid/settings/overwatchPolling';
  static const String _snapshotPath = 'users/$_uid/settings/overwatchSnapshot';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── 설정 CRUD ───

  Future<OverwatchPollingSettings> getSettings() async {
    final doc = await _db.doc(_settingsPath).get();
    if (!doc.exists || doc.data() == null) {
      return OverwatchPollingSettings();
    }
    return OverwatchPollingSettings.fromMap(doc.data()!);
  }

  Future<void> saveSettings(OverwatchPollingSettings settings) async {
    await _db.doc(_settingsPath).set(settings.toMap(), SetOptions(merge: true));
  }

  Future<bool> toggleEnabled() async {
    final s = await getSettings();
    final newEnabled = !s.enabled;
    await _db.doc(_settingsPath).update({'enabled': newEnabled});
    return newEnabled;
  }

  /// ★ 직접 활성/비활성 설정
  Future<void> setActive(bool active) async {
    await _db.doc(_settingsPath).update({'enabled': active});
  }

  /// ★ 수동 확인 (triggerManualPoll 래핑)
  Future<Map<String, dynamic>?> manualCheck() => triggerManualPoll();

  Future<void> setBattletag(String battletag) async {
  await _db.doc(_settingsPath).set({
    'battletag': battletag,
    'verified': false,        // ← 이거 추가
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

  Future<void> removeBattletag() async {
    await _db.doc(_settingsPath).update({
      'battletag': FieldValue.delete(),
      'verified': false,
      'enabled': false,
    });
    await _db.doc(_snapshotPath).delete();
  }

  // ─── 실시간 스트림 ───

  Stream<OverwatchPollingSettings> watchSettings() {
    return _db.doc(_settingsPath).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return OverwatchPollingSettings();
      }
      return OverwatchPollingSettings.fromMap(snap.data()!);
    });
  }

  Stream<OverwatchSnapshot?> watchSnapshot() {
    return _db.doc(_snapshotPath).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return OverwatchSnapshot.fromMap(snap.data()!);
    });
  }

  Future<Map<String, dynamic>?> consumeLastDetection() async {
    final doc = await _db.doc(_settingsPath).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || data['lastDetection'] == null) return null;
    final detection = Map<String, dynamic>.from(data['lastDetection'] as Map);
    await _db.doc(_settingsPath).update({
      'lastDetection': FieldValue.delete(),
    });
    return detection;
  }

  /// ★ Cloud Function 수동 트리거 (즉시 폴링)
  Future<Map<String, dynamic>?> triggerManualPoll() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('pollOverwatchManual');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('[Overwatch] 수동 폴링 실패: $e');
      return null;
    }
  }
}

// ═══ 데이터 모델 ═══

class OverwatchPollingSettings {
  final String? battletag;
  final bool enabled;
  final bool verified;
  final String? playerName;
  final String? avatar;
  final int intervalMinutes;
  final DateTime? lastVerified;
  final Map<String, dynamic>? lastDetection;

  OverwatchPollingSettings({
    this.battletag,
    this.enabled = false,
    this.verified = false,
    this.playerName,
    this.avatar,
    this.intervalMinutes = 30,
    this.lastVerified,
    this.lastDetection,
  });

  bool get isConfigured => battletag != null && battletag!.isNotEmpty;
  /// verified 체크 제거 — Cloud Function 없이도 동작하도록
  bool get isActive => isConfigured && enabled;

  factory OverwatchPollingSettings.fromMap(Map<String, dynamic> m) {
    return OverwatchPollingSettings(
      battletag: m['battletag'] as String?,
      enabled: m['enabled'] ?? false,
      verified: m['verified'] ?? false,
      playerName: m['playerName'] as String?,
      avatar: m['avatar'] as String?,
      intervalMinutes: (m['intervalMinutes'] as num?)?.toInt() ?? 30,
      lastVerified: m['lastVerified'] != null
          ? (m['lastVerified'] as Timestamp).toDate()
          : null,
      lastDetection: m['lastDetection'] != null
          ? Map<String, dynamic>.from(m['lastDetection'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        if (battletag != null) 'battletag': battletag,
        'enabled': enabled,
        'verified': verified,
        if (playerName != null) 'playerName': playerName,
        if (avatar != null) 'avatar': avatar,
        'intervalMinutes': intervalMinutes,
      };
}

class OverwatchSnapshot {
  final int gamesPlayed;
  final int timePlayed;
  final Map<String, dynamic>? rank;
  final DateTime? lastPolled;
  final Map<String, dynamic>? raw;

  OverwatchSnapshot({
    this.gamesPlayed = 0,
    this.timePlayed = 0,
    this.rank,
    this.lastPolled,
    this.raw,
  });

  String get formattedTime {
    final hours = timePlayed ~/ 3600;
    final mins = (timePlayed % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  factory OverwatchSnapshot.fromMap(Map<String, dynamic> m) {
    return OverwatchSnapshot(
      gamesPlayed: (m['gamesPlayed'] as num?)?.toInt() ?? 0,
      timePlayed: (m['timePlayed'] as num?)?.toInt() ?? 0,
      rank: m['rank'] != null
          ? Map<String, dynamic>.from(m['rank'] as Map)
          : null,
      lastPolled: m['lastPolled'] != null
          ? (m['lastPolled'] as Timestamp).toDate()
          : null,
      raw: m['raw'] != null
          ? Map<String, dynamic>.from(m['raw'] as Map)
          : null,
    );
  }
}
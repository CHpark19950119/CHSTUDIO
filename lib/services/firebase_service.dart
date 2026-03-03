import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  FirebaseFirestore get _db => firestore;

  static const String _uid = 'sJ8Pxusw9gR0tNR44RhkIge7OiG2';
  String get uid => _uid;
  static const String _studyDoc = 'users/$_uid/data/study';
  static const String _mindDoc = 'users/$_uid/data/mind';
  static const String _settingsDoc = 'users/$_uid/data/settings';
  static const String _alarmSettingsDoc = 'users/$_uid/settings/alarm';
  static const String _focusModeDoc = 'users/$_uid/settings/focusMode';
  static const String _appUsageCol = 'users/$_uid/appUsageStats';
  static const String _locationHistoryCol = 'users/$_uid/locationHistory';
  static const String _knownPlacesDoc = 'users/$_uid/data/knownPlaces';
  static const String _behaviorTimelineCol = 'users/$_uid/behaviorTimeline';
  static const String _nfcTagsDoc = 'users/$_uid/settings/nfcTags';
  static const String _nfcEventsCol = 'users/$_uid/nfcEvents';
  // v8.5: 수면 관리
  static const String _sleepSettingsDoc = 'users/$_uid/settings/sleep';
  static const String _sleepRecordsCol = 'users/$_uid/sleepRecords';
  // F2: 메모
  static const String _memosCol = 'users/$_uid/memos';

  static const String _timeRecordsField = 'timeRecords';
  static const String _studyTimeRecordsField = 'studyTimeRecords';
  static const String _focusCyclesField = 'focusCycles';

  Future<Map<String, dynamic>?> getStudyData() async {
    final doc = await _db.doc(_studyDoc).get();
    return doc.data();
  }

  Future<Map<String, TimeRecord>> getTimeRecords() async {
    final data = await getStudyData();
    if (data == null || data[_timeRecordsField] == null) return {};
    final raw = data[_timeRecordsField] as Map<String, dynamic>;
    return raw.map((date, value) => MapEntry(
          date, TimeRecord.fromMap(date, value as Map<String, dynamic>)));
  }

  Future<void> updateTimeRecord(String date, TimeRecord record) async {
    // B9 FIX: update + dot notation으로 해당 날짜 레코드 전체 교체
    // (merge:true는 null 필드를 삭제 못함 → 토글 OFF 반영 안 되는 원인)
    try {
      await _db.doc(_studyDoc).update({
        '$_timeRecordsField.$date': record.toMap(),
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      // 문서가 아직 없을 때 (최초 실행)
      await _db.doc(_studyDoc).set({
        _timeRecordsField: {date: record.toMap()},
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    }
  }

  /// 하루 기록 완전 삭제 (FieldValue.delete 사용)
  Future<void> deleteTimeRecord(String date) async {
    await _db.doc(_studyDoc).update({
      '$_timeRecordsField.$date': FieldValue.delete(),
      'lastModified': DateTime.now().millisecondsSinceEpoch,
      'lastDevice': 'android',
    });
  }

  Future<Map<String, StudyTimeRecord>> getStudyTimeRecords() async {
    final data = await getStudyData();
    if (data == null || data[_studyTimeRecordsField] == null) return {};
    final raw = data[_studyTimeRecordsField] as Map<String, dynamic>;
    return raw.map((date, value) => MapEntry(
          date, StudyTimeRecord.fromMap(date, value as Map<String, dynamic>)));
  }

  Future<void> updateStudyTimeRecord(
      String date, StudyTimeRecord record) async {
    if (record.effectiveMinutes == 0 && record.totalMinutes == 0) return;
    // 7순위 FIX: dot notation으로 해당 날짜만 업데이트 (다른 필드 보존)
    try {
      await _db.doc(_studyDoc).update({
        '$_studyTimeRecordsField.$date': record.toMap(),
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      // 문서 없을 때 fallback
      await _db.doc(_studyDoc).set({
        _studyTimeRecordsField: {date: record.toMap()},
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
  }

  Future<List<FocusCycle>> getFocusCycles(String date) async {
    final data = await getStudyData();
    if (data == null || data[_focusCyclesField] == null) return [];
    final raw = data[_focusCyclesField] as Map<String, dynamic>;
    if (raw[date] == null) return [];
    final dayData = raw[date] as List<dynamic>;
    return dayData
        .map((c) => FocusCycle.fromMap(c as Map<String, dynamic>))
        .toList();
  }

  /// 저널(일지) 전체 목록 반환
  Future<List<Map<String, dynamic>>> getJournals() async {
    final data = await getStudyData();
    if (data == null || data['journals'] == null) return [];
    final raw = data['journals'] as List<dynamic>;
    return raw
        .map((j) => Map<String, dynamic>.from(j as Map))
        .toList();
  }

  Future<void> saveFocusCycle(String date, FocusCycle cycle) async {
    final cycles = await getFocusCycles(date);
    final idx = cycles.indexWhere((c) => c.id == cycle.id);
    if (idx >= 0) {
      cycles[idx] = cycle;
    } else {
      cycles.add(cycle);
    }
    // 7순위 FIX: dot notation으로 해당 날짜만 업데이트
    try {
      await _db.doc(_studyDoc).update({
        '$_focusCyclesField.$date': cycles.map((c) => c.toMap()).toList(),
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      await _db.doc(_studyDoc).set({
        _focusCyclesField: {
          date: cycles.map((c) => c.toMap()).toList(),
        },
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
  }

  /// [F7] focusCycles 전체 덮어쓰기 (삭제용)
  Future<void> overwriteFocusCycles(String date, List<FocusCycle> cycles) async {
    // 7순위 FIX: dot notation으로 해당 날짜만 교체
    try {
      await _db.doc(_studyDoc).update({
        '$_focusCyclesField.$date': cycles.map((c) => c.toMap()).toList(),
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      await _db.doc(_studyDoc).set({
        _focusCyclesField: {
          date: cycles.map((c) => c.toMap()).toList(),
        },
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
  }

  /// [F5] 실시간 포커스 진행 상태 업데이트
  Future<void> updateLiveFocus(String date, Map<String, dynamic> data) async {
    try {
      await _db.doc(_studyDoc).update({
        'liveFocus': data,
        'lastModified': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      await _db.doc(_studyDoc).set({
        'liveFocus': data,
        'lastModified': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    }
  }

  /// [F5] 실시간 포커스 상태 삭제
  Future<void> clearLiveFocus(String date) async {
    await _db.doc(_studyDoc).update({
      'liveFocus': FieldValue.delete(),
      'lastModified': DateTime.now().millisecondsSinceEpoch,
      'lastDevice': 'android',
    });
  }

  // ─── 알람 설정 ───

  Future<AlarmSettings> getAlarmSettings() async {
    final doc = await _db.doc(_alarmSettingsDoc).get();
    if (!doc.exists) return AlarmSettings();
    return AlarmSettings.fromMap(doc.data()!);
  }

  Future<void> saveAlarmSettings(AlarmSettings settings) async {
    await _db.doc(_alarmSettingsDoc).set(settings.toMap());
  }

  // ─── 집중모드 설정 ───

  Future<FocusModeConfig> getFocusModeConfig() async {
    final doc = await _db.doc(_focusModeDoc).get();
    if (!doc.exists) return FocusModeConfig();
    return FocusModeConfig.fromMap(doc.data()!);
  }

  Future<void> saveFocusModeConfig(FocusModeConfig config) async {
    await _db.doc(_focusModeDoc).set(config.toMap());
  }

  // ─── 앱 사용 통계 ───

  Future<void> saveAppUsageStats(
      String date, List<AppUsageStat> stats) async {
    await _db.collection(_appUsageCol).doc(date).set({
      'date': date,
      'stats': stats.map((s) => s.toMap()).toList(),
      '_updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── 위치 기록 ───

  Future<void> saveLocationRecord(
      String date, LocationRecord record) async {
    await _db.collection(_locationHistoryCol).doc(date).set({
      'date': date,
      'records': FieldValue.arrayUnion([record.toMap()]),
      '_updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<LocationRecord>> getLocationRecords(String date) async {
    final doc =
        await _db.collection(_locationHistoryCol).doc(date).get();
    if (!doc.exists || doc.data() == null) return [];
    final raw = doc.data()!['records'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((r) => LocationRecord.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ─── 등록 장소 ───

  Future<void> saveKnownPlaces(List<KnownPlace> places) async {
    await _db.doc(_knownPlacesDoc).set({
      'places': places.map((p) => p.toMap()).toList(),
      '_updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<KnownPlace>> getKnownPlaces() async {
    final doc = await _db.doc(_knownPlacesDoc).get();
    if (!doc.exists || doc.data() == null) return [];
    final raw = doc.data()!['places'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((p) => KnownPlace.fromMap(p as Map<String, dynamic>))
        .toList();
  }

  // ─── 행동 타임라인 ───

  Future<void> saveBehaviorTimeline(
      String date, BehaviorTimelineEntry entry) async {
    await _db.collection(_behaviorTimelineCol).doc(date).set({
      'date': date,
      'entries': FieldValue.arrayUnion([entry.toMap()]),
      '_updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<BehaviorTimelineEntry>> getBehaviorTimeline(
      String date) async {
    final doc =
        await _db.collection(_behaviorTimelineCol).doc(date).get();
    if (!doc.exists || doc.data() == null) return [];
    final raw = doc.data()!['entries'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((e) =>
            BehaviorTimelineEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ─── NFC 태그 CRUD ───

  Future<void> saveNfcTags(List<NfcTagConfig> tags) async {
    await _db.doc(_nfcTagsDoc).set({
      'tags': tags.map((t) => t.toMap()).toList(),
      '_updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<NfcTagConfig>> getNfcTags() async {
    final doc = await _db.doc(_nfcTagsDoc).get();
    if (!doc.exists || doc.data() == null) return [];
    final raw = doc.data()!['tags'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((t) => NfcTagConfig.fromMap(t as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveNfcEvent(String date, NfcEvent event) async {
    await _db.collection(_nfcEventsCol).doc(date).set({
      'date': date,
      'events': FieldValue.arrayUnion([event.toMap()]),
      '_updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<NfcEvent>> getNfcEvents(String date) async {
    final doc = await _db.collection(_nfcEventsCol).doc(date).get();
    if (!doc.exists || doc.data() == null) return [];
    final raw = doc.data()!['events'] as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      return NfcEvent(
        id: m['id'] ?? '',
        date: m['date'] ?? '',
        timestamp: m['timestamp'] ?? '',
        role: NfcTagRole.values.firstWhere(
          (r) => r.name == (m['role'] ?? 'wake'),
          orElse: () => NfcTagRole.wake,
        ),
        tagName: m['tagName'] ?? '',
        action: m['action'] as String?,
      );
    }).toList();
  }

  // ══════════════════════════════════════════
  //  v8.5: 수면 관리 (#32~38)
  // ══════════════════════════════════════════

  Future<SleepSettings> getSleepSettings() async {
    final doc = await _db.doc(_sleepSettingsDoc).get();
    if (!doc.exists) return SleepSettings();
    return SleepSettings.fromMap(doc.data()!);
  }

  Future<void> saveSleepSettings(SleepSettings settings) async {
    await _db.doc(_sleepSettingsDoc).set(settings.toMap());
  }

  Future<void> saveSleepRecord(String date, SleepRecord record) async {
    await _db.collection(_sleepRecordsCol).doc(date).set({
      ...record.toMap(),
      '_updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<SleepRecord?> getSleepRecord(String date) async {
    final doc = await _db.collection(_sleepRecordsCol).doc(date).get();
    if (!doc.exists || doc.data() == null) return null;
    return SleepRecord.fromMap(date, doc.data()!);
  }

  // ─── F2: 메모 CRUD ───

  Future<void> saveMemo(Memo memo) async {
    await _db.collection(_memosCol).doc(memo.id).set({
      ...memo.toMap(),
      '_updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMemo(String memoId) async {
    await _db.collection(_memosCol).doc(memoId).delete();
  }

  Future<List<Memo>> getMemos({bool includeCompleted = false}) async {
    Query<Map<String, dynamic>> q = _db.collection(_memosCol)
        .orderBy('pinned', descending: true);
    final snap = await q.get();
    final memos = snap.docs
        .map((d) => Memo.fromMap(d.data()))
        .toList();
    if (!includeCompleted) {
      memos.removeWhere((m) => m.completed);
    }
    // 고정 먼저, 그 다음 최신순
    memos.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return memos;
  }

  Stream<List<Memo>> watchMemos() {
    return _db.collection(_memosCol)
        .snapshots()
        .map((snap) {
          final memos = snap.docs
              .map((d) => Memo.fromMap(d.data()))
              .where((m) => !m.completed)
              .toList();
          memos.sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          return memos;
        });
  }

  // ─── 실시간 스트림 ───

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchStudyData() {
    return _db.doc(_studyDoc).snapshots();
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ═══════════════════════════════════════════════════════════
  //  3순위: 학습 진행도 CRUD
  //  Firebase 경로: users/{uid}/data/study → progressGoals (배열)
  //  웹앱과 동일 스키마 사용
  // ═══════════════════════════════════════════════════════════

  static const String _progressGoalsField = 'progressGoals';

  /// 전체 진행도 목표 가져오기
  Future<List<ProgressGoal>> getProgressGoals() async {
    final data = await getStudyData();
    if (data == null || data[_progressGoalsField] == null) return [];
    final raw = data[_progressGoalsField] as List<dynamic>;
    return raw
        .map((g) => ProgressGoal.fromMap(Map<String, dynamic>.from(g as Map)))
        .toList();
  }

  /// 진행도 목표 전체 저장 (dot notation으로 필드별 쓰기)
  Future<void> saveProgressGoals(List<ProgressGoal> goals) async {
    try {
      await _db.doc(_studyDoc).update({
        _progressGoalsField: goals.map((g) => g.toMap()).toList(),
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      await _db.doc(_studyDoc).set({
        _progressGoalsField: goals.map((g) => g.toMap()).toList(),
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
  }

  /// 단일 목표 추가
  Future<void> addProgressGoal(ProgressGoal goal) async {
    final goals = await getProgressGoals();
    goals.add(goal);
    await saveProgressGoals(goals);
  }

  /// 단일 목표 업데이트
  Future<void> updateProgressGoal(ProgressGoal updated) async {
    final goals = await getProgressGoals();
    final idx = goals.indexWhere((g) => g.id == updated.id);
    if (idx >= 0) {
      goals[idx] = updated;
    } else {
      goals.add(updated);
    }
    await saveProgressGoals(goals);
  }

  /// 단일 목표 삭제
  Future<void> deleteProgressGoal(String goalId) async {
    final goals = await getProgressGoals();
    goals.removeWhere((g) => g.id == goalId);
    await saveProgressGoals(goals);
  }

  /// 진행도 목표 실시간 스트림
  Stream<List<ProgressGoal>> watchProgressGoals() {
    return _db.doc(_studyDoc).snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data[_progressGoalsField] == null) return [];
      final raw = data[_progressGoalsField] as List<dynamic>;
      return raw
          .map(
              (g) => ProgressGoal.fromMap(Map<String, dynamic>.from(g as Map)))
          .toList();
    });
  }

  // ─── 날짜 기록 이관 ───

  /// fromDate의 timeRecords, studyTimeRecords, focusCycles를 toDate로 이관
  /// 이관 후 fromDate 데이터를 삭제하고, toDate의 timeRecord를 overrides로 덮어쓸 수 있음
  Future<void> migrateDateRecords({
    required String fromDate,
    required String toDate,
    Map<String, String?>? timeRecordOverrides,
  }) async {
    final data = await getStudyData();
    if (data == null) return;

    final batch = <String, dynamic>{};

    // 1) timeRecords 이관
    final trRaw = data[_timeRecordsField] as Map<String, dynamic>?;
    if (trRaw != null && trRaw[fromDate] != null) {
      final fromTr = Map<String, dynamic>.from(trRaw[fromDate] as Map<String, dynamic>);
      // overrides 적용
      if (timeRecordOverrides != null) {
        for (final entry in timeRecordOverrides.entries) {
          if (entry.value != null) {
            fromTr[entry.key] = entry.value;
          } else {
            fromTr.remove(entry.key);
          }
        }
      }
      batch['$_timeRecordsField.$toDate'] = fromTr;
      batch['$_timeRecordsField.$fromDate'] = FieldValue.delete();
    }

    // 2) studyTimeRecords 이관
    final strRaw = data[_studyTimeRecordsField] as Map<String, dynamic>?;
    if (strRaw != null && strRaw[fromDate] != null) {
      batch['$_studyTimeRecordsField.$toDate'] = strRaw[fromDate];
      batch['$_studyTimeRecordsField.$fromDate'] = FieldValue.delete();
    }

    // 3) focusCycles 이관
    final fcRaw = data[_focusCyclesField] as Map<String, dynamic>?;
    if (fcRaw != null && fcRaw[fromDate] != null) {
      batch['$_focusCyclesField.$toDate'] = fcRaw[fromDate];
      batch['$_focusCyclesField.$fromDate'] = FieldValue.delete();
    }

    if (batch.isNotEmpty) {
      batch['lastModified'] = DateTime.now().millisecondsSinceEpoch;
      batch['lastDevice'] = 'android';
      await _db.doc(_studyDoc).update(batch);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  데일리 일기 CRUD — users/{uid}/dailyDiary/{date}
  // ═══════════════════════════════════════════════════════════

  String get _diaryCol => 'users/$_uid/dailyDiary';

  Future<void> saveDailyDiary(DailyDiary diary) async {
    await _db.collection(_diaryCol).doc(diary.date).set(diary.toMap());
  }

  Future<DailyDiary?> getDailyDiary(String date) async {
    final doc = await _db.collection(_diaryCol).doc(date).get();
    if (!doc.exists || doc.data() == null) return null;
    return DailyDiary.fromMap(doc.data()!);
  }

  Future<void> deleteDailyDiary(String date) async {
    await _db.collection(_diaryCol).doc(date).delete();
  }

  Future<List<DailyDiary>> getRecentDiaries({int days = 7}) async {
    final snap = await _db.collection(_diaryCol)
        .orderBy('date', descending: true)
        .limit(days)
        .get();
    return snap.docs
        .where((d) => d.data().isNotEmpty)
        .map((d) => DailyDiary.fromMap(d.data()))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  UL-6: 쉬는날 CRUD — users/{uid}/data/study → restDays (배열)
  // ═══════════════════════════════════════════════════════════

  static const String _restDaysField = 'restDays';

  /// 쉬는날 목록 가져오기
  Future<List<String>> getRestDays() async {
    final data = await getStudyData();
    if (data == null || data[_restDaysField] == null) return [];
    final raw = data[_restDaysField] as List<dynamic>;
    return raw.map((e) => e.toString()).toList();
  }

  /// 쉬는날 토글 (있으면 제거, 없으면 추가)
  Future<bool> toggleRestDay(String date) async {
    final days = await getRestDays();
    final isRest = days.contains(date);
    if (isRest) {
      days.remove(date);
    } else {
      days.add(date);
    }
    try {
      await _db.doc(_studyDoc).update({
        _restDaysField: days,
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      await _db.doc(_studyDoc).set({
        _restDaysField: days,
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
    return !isRest; // true = 쉬는날로 지정됨
  }

  /// 특정 날짜가 쉬는날인지 확인
  Future<bool> isRestDay(String date) async {
    final days = await getRestDays();
    return days.contains(date);
  }

  /// 쉬는날 실시간 스트림
  Stream<List<String>> watchRestDays() {
    return _db.doc(_studyDoc).snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data[_restDaysField] == null) return <String>[];
      final raw = data[_restDaysField] as List<dynamic>;
      return raw.map((e) => e.toString()).toList();
    });
  }

  // ═══════════════════════════════════════════════════
  // ORDER PORTAL — Generic field access
  // ═══════════════════════════════════════════════════

  /// study doc 전체 데이터 반환
  Future<Map<String, dynamic>?> getData() async {
    final doc = await _db.doc(_studyDoc).get();
    return doc.data();
  }

  /// study doc 특정 필드 업데이트 (dot notation safe)
  Future<void> updateField(String field, dynamic value) async {
    try {
      await _db.doc(_studyDoc).update({
        field: value,
        'lastModified': FieldValue.serverTimestamp(),
        'lastDevice': 'android',
      });
    } catch (e) {
      // doc 없으면 set
      await _db.doc(_studyDoc).set({
        field: value,
        'lastModified': FieldValue.serverTimestamp(),
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  2-C: 커스텀 학습과제 CRUD — studyData.customStudyTasks.{date}
  // ═══════════════════════════════════════════════════════════

  static const String _customTasksField = 'customStudyTasks';

  /// 특정 날짜의 학습과제 목록 가져오기
  Future<List<String>> getCustomStudyTasks(String date) async {
    final data = await getStudyData();
    if (data == null || data[_customTasksField] == null) return [];
    final all = data[_customTasksField] as Map<String, dynamic>;
    final dayTasks = all[date];
    if (dayTasks == null) return [];
    return (dayTasks as List<dynamic>).map((e) => e.toString()).toList();
  }

  /// 학습과제 추가
  Future<void> addCustomStudyTask(String date, String task) async {
    final tasks = await getCustomStudyTasks(date);
    tasks.add(task);
    await _saveCustomStudyTasks(date, tasks);
  }

  /// 학습과제 수정
  Future<void> editCustomStudyTask(String date, int index, String newTask) async {
    final tasks = await getCustomStudyTasks(date);
    if (index >= 0 && index < tasks.length) {
      tasks[index] = newTask;
      await _saveCustomStudyTasks(date, tasks);
    }
  }

  /// 학습과제 삭제
  Future<void> deleteCustomStudyTask(String date, int index) async {
    final tasks = await getCustomStudyTasks(date);
    if (index >= 0 && index < tasks.length) {
      tasks.removeAt(index);
      await _saveCustomStudyTasks(date, tasks);
    }
  }

  Future<void> _saveCustomStudyTasks(String date, List<String> tasks) async {
    try {
      await _db.doc(_studyDoc).update({
        '$_customTasksField.$date': tasks,
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      await _db.doc(_studyDoc).set({
        _customTasksField: {date: tasks},
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  2-D: 한줄 일기 — studyData.dayDiaries.{date}
  // ═══════════════════════════════════════════════════════════

  static const String _dayDiariesField = 'dayDiaries';

  /// 한줄 일기 저장
  Future<void> saveDayDiary(String date, String content) async {
    try {
      await _db.doc(_studyDoc).update({
        '$_dayDiariesField.$date': content,
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      });
    } catch (e) {
      await _db.doc(_studyDoc).set({
        _dayDiariesField: {date: content},
        'lastModified': DateTime.now().millisecondsSinceEpoch,
        'lastDevice': 'android',
      }, SetOptions(merge: true));
    }
  }

  /// 한줄 일기 읽기
  Future<String?> getDayDiary(String date) async {
    final data = await getStudyData();
    if (data == null || data[_dayDiariesField] == null) return null;
    final all = data[_dayDiariesField] as Map<String, dynamic>;
    return all[date] as String?;
  }

  /// 전체 한줄 일기 맵 가져오기
  Future<Map<String, String>> getAllDayDiaries() async {
    final data = await getStudyData();
    if (data == null || data[_dayDiariesField] == null) return {};
    final all = data[_dayDiariesField] as Map<String, dynamic>;
    return all.map((k, v) => MapEntry(k, v.toString()));
  }
}
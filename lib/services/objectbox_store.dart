import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart' as hive;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../objectbox.g.dart';
import '../models/focus_entity.dart';
import '../models/models.dart';

class ObjectBoxStore {
  static ObjectBoxStore? _instance;
  late final Store _store;
  late final Box<FocusCycleEntity> focusCycleBox;

  ObjectBoxStore._();

  static Future<ObjectBoxStore> init() async {
    if (_instance != null) return _instance!;
    final instance = ObjectBoxStore._();
    final dir = await getApplicationDocumentsDirectory();
    instance._store = await openStore(directory: '${dir.path}/objectbox');
    instance.focusCycleBox = instance._store.box<FocusCycleEntity>();
    _instance = instance;
    debugPrint('[ObjectBox] store opened, ${instance.focusCycleBox.count()} entities');

    // ★ 일회성 Hive → ObjectBox 전체 마이그레이션
    await instance._migrateFromHive();

    return instance;
  }

  /// Hive focus_data 박스의 모든 세션을 ObjectBox로 이관
  Future<void> _migrateFromHive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('obx_migrated') == true) {
        debugPrint('[ObjectBox] migration already done, skipping');
        return;
      }
      debugPrint('[ObjectBox] starting Hive → ObjectBox migration');

      final box = await hive.Hive.openBox('focus_data');
      int total = 0;

      for (final key in box.keys) {
        if (key is! String || !key.startsWith('sessions_')) continue;
        final raw = box.get(key);
        if (raw == null) continue;

        try {
          final list = List<dynamic>.from(raw is String ? jsonDecode(raw) : raw);
          for (final e in list) {
            try {
              if (e is! Map) continue;
              final m = Map<String, dynamic>.from(e);
              final cycle = FocusCycle.fromMap(m);
              // 고스트 세션 스킵
              if (cycle.studyMin + cycle.lectureMin == 0 && cycle.restMin == 0) continue;
              focusCycleBox.put(FocusCycleEntity.fromCycle(cycle));
              total++;
            } catch (_) {}
          }
        } catch (_) {}
      }

      await prefs.setBool('obx_migrated', true);
      if (total > 0) debugPrint('[ObjectBox] migrated $total sessions from Hive');
    } catch (e) {
      debugPrint('[ObjectBox] migration error: $e');
    }
  }

  static ObjectBoxStore get instance {
    if (_instance == null) throw StateError('ObjectBoxStore not initialized. Call init() first.');
    return _instance!;
  }

  // ── FocusCycle CRUD ──

  /// 세션 저장 (중복 ID → 자동 replace)
  void putCycle(FocusCycleEntity entity) {
    focusCycleBox.put(entity);
  }

  /// 날짜별 세션 조회
  List<FocusCycleEntity> getCyclesByDate(String date) {
    return focusCycleBox
        .query(FocusCycleEntity_.date.equals(date))
        .build()
        .find();
  }

  /// 월별 세션 조회 (prefix 매칭)
  List<FocusCycleEntity> getCyclesByMonth(String monthPrefix) {
    return focusCycleBox
        .query(FocusCycleEntity_.date.startsWith(monthPrefix))
        .build()
        .find();
  }

  /// ID로 삭제
  bool removeCycleByFcId(String fcId) {
    final entity = focusCycleBox
        .query(FocusCycleEntity_.fcId.equals(fcId))
        .build()
        .findFirst();
    if (entity != null) {
      return focusCycleBox.remove(entity.obxId);
    }
    return false;
  }

  /// 날짜별 전체 삭제
  int removeCyclesByDate(String date) {
    final ids = focusCycleBox
        .query(FocusCycleEntity_.date.equals(date))
        .build()
        .findIds();
    return focusCycleBox.removeMany(ids);
  }

  void close() {
    _store.close();
    _instance = null;
  }
}

import 'dart:convert';
import 'package:objectbox/objectbox.dart';
import 'models.dart';

@Entity()
class FocusCycleEntity {
  @Id()
  int obxId;

  /// 원래 FocusCycle.id ("fc_1774937924754")
  @Unique(onConflict: ConflictStrategy.replace)
  String fcId;

  /// "yyyy-MM-dd"
  @Index()
  String date;

  String startTime;
  String? endTime;
  String subject;
  int studyMin;
  int lectureMin;
  int effectiveMin;
  int restMin;

  /// FocusSegment 리스트를 JSON 문자열로 저장
  String segmentsJson;

  FocusCycleEntity({
    this.obxId = 0,
    required this.fcId,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.subject,
    this.studyMin = 0,
    this.lectureMin = 0,
    this.effectiveMin = 0,
    this.restMin = 0,
    this.segmentsJson = '[]',
  });

  /// FocusCycle → Entity
  factory FocusCycleEntity.fromCycle(FocusCycle c) {
    return FocusCycleEntity(
      fcId: c.id,
      date: c.date,
      startTime: c.startTime,
      endTime: c.endTime,
      subject: c.subject,
      studyMin: c.studyMin,
      lectureMin: c.lectureMin,
      effectiveMin: c.studyMin + c.lectureMin,
      restMin: c.restMin,
      segmentsJson: jsonEncode(c.segments.map((s) => s.toMap()).toList()),
    );
  }

  /// Entity → FocusCycle
  FocusCycle toCycle() {
    List<FocusSegment> segs = [];
    try {
      final list = jsonDecode(segmentsJson) as List<dynamic>;
      segs = list
          .map((s) => FocusSegment.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList();
    } catch (_) {}

    return FocusCycle(
      id: fcId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      subject: subject,
      segments: segs,
      studyMin: studyMin,
      lectureMin: lectureMin,
      effectiveMin: studyMin + lectureMin,
      restMin: restMin,
    );
  }
}

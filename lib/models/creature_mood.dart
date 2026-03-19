import 'dart:math';

/// 크리처 무드 — 알림/이벤트별 감정 표현
enum CreatureMood {
  neutral,   // 기본
  worried,   // 데이터 이상, 누락 감지
  curious,   // 분기 이벤트 질문
  proud,     // 장시간 공부, 좋은 하루
  sleepy,    // 늦은 밤
}

/// SafetyCheck별 크리처 메시지 뱅크
class CreatureMessages {
  static final _rng = Random();
  static String? _lastMsg;

  /// 랜덤 선택 (같은 메시지 연속 방지)
  static String pick(List<String> pool) {
    if (pool.length == 1) return pool.first;
    String msg;
    do {
      msg = pool[_rng.nextInt(pool.length)];
    } while (msg == _lastMsg && pool.length > 1);
    _lastMsg = msg;
    return msg;
  }

  // ── homeDayConfirm ──
  static const homeDayConfirm = [
    '오늘 집에 있을 거야?',
    '밖에 안 나가?',
    '오늘은 홈데이?',
  ];

  // ── autoWakeConfirm ──
  static const autoWakeConfirm = [
    '일어난 거 맞지?',
    '기상한 거야?',
    '눈 떴어?',
  ];

  // ── studyEndConfirm ──
  static const studyEndConfirm = [
    '아직 공부 중이야?',
    '공부 계속하는 거야?',
    '4시간 넘었는데, 아직 하고 있어?',
  ];

  // ── lateMealReminder ──
  static const lateMealReminder = [
    '밥 먹었어?',
    '배 안 고파?',
    '식사 시간 지났는데?',
  ];

  // ── abnormalData ──
  static const abnormalData = [
    '데이터가 이상해...',
    '시간 기록이 꼬인 것 같아',
    '기록 한번 확인해봐',
  ];

  // ── wakeMiss ──
  static const wakeMiss = [
    '아직 자고 있어?',
    '언제 일어나?',
    '좀 일어나...',
  ];

  // ── writeVerifyFail ──
  static const writeVerifyFail = [
    '저장이 안 됐을 수도 있어',
    '데이터 확인해봐',
    '기록 저장에 문제가 있었어',
  ];

  /// SafetyCheck 이름으로 메시지 풀 가져오기
  static List<String> poolFor(String checkName) {
    switch (checkName) {
      case 'homeDayConfirm': return homeDayConfirm;
      case 'autoWakeConfirm': return autoWakeConfirm;
      case 'studyEndConfirm': return studyEndConfirm;
      case 'lateMealReminder': return lateMealReminder;
      case 'abnormalData': return abnormalData;
      case 'wakeMiss': return wakeMiss;
      default: return ['확인해봐'];
    }
  }

  /// 시간대별 톤 — 늦은 밤은 무드 sleepy
  static CreatureMood moodForCheck(String checkName) {
    final hour = DateTime.now().hour;
    if (hour >= 23 || hour < 5) return CreatureMood.sleepy;

    switch (checkName) {
      case 'homeDayConfirm':
      case 'autoWakeConfirm':
      case 'studyEndConfirm':
      case 'lateMealReminder':
        return CreatureMood.curious;
      case 'abnormalData':
        return CreatureMood.worried;
      default:
        return CreatureMood.neutral;
    }
  }
}

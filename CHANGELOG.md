# CHEONHONG STUDIO — CHANGELOG

## 세션 시작 시 반드시 읽을 것
> 이 섹션만 읽으면 현재 상태 파악 가능. 상세 히스토리는 하단.

### 현재 버전: v10.10.0 (2026-03-17)
- **이번 세션 변경사항:**
  - DailyGrade 점수 시스템 전체 제거 (순공시간 표시로 대체)
  - "다영에게 알리기" 스낵바 제거
  - 텔레그램 알림: 외출/귀가만 유지 (기상/공부/식사/취침 제거)
  - 외출/귀가 UI 즉시 반영 (NfcService Single Source of Truth)
  - 데일리 로그: 무한 '준비' 제거 (NFC 상태 기반 라벨)
  - 앱 재설치 후 movement 상태 자동 복원
  - CF onIotWrite: data/iot → today+study 듀얼라이트 (Single Writer)
  - Todo ↔ Progress 연결: goalId 필드 추가, 투두 완료 시 진행도 자동 반영

### 미커밋 파일
- `functions/index.js` — onIotWrite CF 신규, checkMovementPending 듀얼라이트
- `lib/services/nfc_service.dart` — movement listener, forceState, outingTime/returnTime
- `lib/services/fcm_service.dart` — geofence → iot 기록 간소화
- `lib/screens/home_screen.dart` — DailyGrade 제거, NFC 시간 즉시 반영
- `lib/screens/home_daily_log.dart` — NFC 상태 기반 세그먼트 라벨
- `lib/screens/home_routine_card.dart` — 다영 알리기 제거
- `lib/services/nfc_action_part.dart` — 외출/귀가만 텔레그램
- `lib/services/todo_service.dart` — goalId 기반 진행도 자동 반영
- `lib/models/plan_models.dart` — TodoItem.goalId, goalUnits 추가
- `lib/models/models.dart` — DailyGrade 클래스 삭제
- `lib/screens/calendar_*.dart`, `statistics_screen.dart`, `plan_service.dart` — grade 참조 제거
- `lib/app_init.dart` — 초기화 순서 개선 (Phase 4a/4b)
- `lib/screens/settings_screen.dart` — 공부 장소 카드 제거

### 미배포
- `functions/index.js` — `firebase deploy --only functions` 필요

### 다음 할 일
- [ ] CF functions 배포 (onIotWrite 활성화)
- [ ] 투두에서 진행도 목표 연결 UI (목표 선택 드롭다운)
- [ ] 경제학 등 신규 과목 로드맵 설정
- [ ] 크리쳐 알람 시스템 재설계

### 보류 작업
- 소설 「허락」 제1부 확장 (핸드오프: `assets/roadmap/HANDOFF_소설_허락_제1부.md`)

---

## 히스토리

### 2026-03-17 — v10.10.0
- DailyGrade 전체 제거 + 순공시간 UI 대체
- 외출/귀가 UI 즉시 반영 아키텍처 (iot → NfcService → home)
- 데일리 로그 스마트 라벨 (NFC 상태 기반)
- Todo ↔ Progress goalId 연결
- 텔레그램 외출/귀가만 유지
- CF onIotWrite Single Writer 패턴

### 2026-03-16 — v10.9.1
- 로드맵 v13 이식, 소설 핸드오프 문서 작성

### 2026-03-15 — v10.9.0
- CF 기상감지 + FCM + 빅스비 외출/귀가 + 공부장소 매칭
- 헤드위그 봇 movement 기반 응답
- 빅스비 NotificationListener 연동

### 2026-03-14 — v10.8.5
- 기상 감지: DayState.idle + 7시 이후 방문 열림

### 2026-03-13 — v10.8.2~v10.8.3
- 헤드위그 텔레그램 위치 봇 + Wake 시간대 설정
- Order v6 커맨드센터, 습관 2단계, 목표 체크리스트

### 2026-03-12 — v10.7.0~v10.8.0
- V9→V11→V13 인생 로드맵, 소설 v4 탑재
- 홈 모션 고급화, 기록탭 차트 모션

### 2026-03-11 — v10.5.0~v10.6.0
- 수면 자동 감지, 문감지 센서, 자동 백업, 일일/주간 리포트
- 버스 도착정보 GBIS API

### 2026-03-10 — v10.2~v10.4.1
- NFC DayState FSM + Geofence
- ORDER v5 리빌드 + HOME 대시보드 v2
- 웹앱 아카이브, 진행도 1차/2차 분리, Todo 강화

### 2026-03-09 이전
- v9.x: 캐시 동기화, 기록탭, 도서관 배치도, Focus Zone
- v6.0: Phase C 아키텍처
- v5.x: Study Creature (Flame)
- v4.x: 3-layer 캐시 + Optimistic UI

---

## 참조

### Firestore 문서 구조 (Phase C)
| 문서 | 용도 | 크기 |
|------|------|------|
| data/today | 홈 전용 (timeRecords, todos, orderData) | ~2KB |
| data/study | 레거시 + 스트림 (전체 데이터) | ~50KB |
| data/iot | IoT 센서 + movement (CF 트리거) | ~1KB |
| data/creature | 캐릭터 | ~1KB |
| data/liveFocus | 실시간 포커스 | ~1KB |
| history/{yyyy-MM} | 월별 아카이브 | ~7KB/월 |

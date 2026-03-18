# Session Handoff
> 이 파일은 Claude Code 세션 간 작업 연속성을 위한 핸드오프 문서.
> 세션 종료 시 자동 업데이트됨. 다음 세션 시작 시 이 파일부터 읽는다.

## 마지막 세션
- **날짜**: 2026-03-19
- **버전**: v10.14.0 (미반영, 커밋만)
- **커밋**: `ac6d286` feat: 크리처 알람 v2 + 데이터 무결성 + 습관 확장 + UI 개선

## 이번 세션 완료 작업

### 1. 크리처 알람 시스템 v2
- 분기 이벤트 4개: homeDayConfirm, autoWakeConfirm, studyEndConfirm, lateMealReminder
- 크리처 무드: neutral/worried/curious/proud/sleepy + 오버레이 색상 변화
- 메시지 뱅크: SafetyCheck별 3개 한국어 랜덤 (creature_mood.dart)

### 2. 데이터 무결성 가디언
- TimeRecord.validate() — 포맷/순서 검증 → 포맷에러 시 쓰기 차단
- Write-back verify — 3초 후 서버 읽기 비교 → 재시도
- 듀얼 문서 동기화 — study↔today doc 비교 → lastModified 기준 복구
- 캐시 신선도 — 30분+ → 서버 리프레시

### 3. DataAuditService (신규)
- 앱 시작 1일 1회: TimeRecord 정리, 듀얼 문서 동기화, 14일+ 데이터 삭제, OrderData 중복 감지
- `runForced()` — 설정 화면에서 수동 실행 가능

### 4. 쓰기 보호 강화
- silent `.catchError((_) {})` 6곳 → debugPrint 로깅
- Order `_save()` 뮤텍스 + 큐잉 (동시 쓰기 방지)
- Rollover 중복 방지 (`_rollingOver` 플래그 + date 먼저 마킹)

### 5. 칩거 모드 연결 + 토글
- SafetyNet homeDayConfirm → Firestore noOuting → DayService notify → 홈 UI 전환
- 칩거 배너에 X 버튼 (수동 해제)
- rollover 시 자동 리셋

### 6. 진행도 1차/2차 탭 분리
- 기존 칩 필터 → TabBar (전체 | 1차 PSAT | 2차 전공)
- 1차/2차 탭: 라운드 요약 카드 + 과목별 미니카드 그리드

### 7. 습관 autoTrigger 확장
- 트리거 종류: wake, sleep + study, outing, meal (5개)
- 시간 조건부: triggerTime 설정 시 해당 시간에 조건 체크
- UI: 오토뱃지 (⚡📚공부 22:00), 시트에 트리거 6칩 + 시간 피커

### 8. 데일리로그 공부→포커스/휴식 세분화
- FocusCycle 데이터로 studyStart~studyEnd 구간 분할
- 포커스 세션 = "공부📖", 나머지 = "휴식☕"

### 9. 오더 목표 컴팩트 뷰
- 카드 높이 절반 (제목+D-Day+%+프로그레스바 2줄)

## 미커밋 파일
- `CODEMAGIC_BUILD.md` (untracked, 이전 세션)

## 결정사항
- 투두→진행도 목표 연결 UI — 보류 (별로)
- 칩거 감지 기준: 기상 후 3시간(180분)
- 데일리로그: 포커스 외 시간 = "휴식" (공부 아님)

## 다음 할 일
- [ ] CHANGELOG.md 업데이트 (v10.14.0)
- [ ] 폰 테스트 후 버그 수정
- [ ] DataAuditService 설정 화면 연동 (수동 실행 버튼)
- [ ] Codemagic CI 검증

## 알려진 이슈
- Codemagic CI 미검증
- 서명: release 빌드가 debug keystore 사용 중 (build.gradle.kts line 36)

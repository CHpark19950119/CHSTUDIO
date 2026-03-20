# Session Handoff
> 이 파일은 Claude Code 세션 간 작업 연속성을 위한 핸드오프 문서.
> 세션 종료 시 자동 업데이트됨. 다음 세션 시작 시 이 파일부터 읽는다.

## 마지막 세션
- **날짜**: 2026-03-20
<<<<<<< Updated upstream
- **버전**: v10.14.0+
- **커밋**: `5a536c0` chore: .gitignore에 .env 추가

## 이번 세션 완료 작업

### 1. 도어센서 기상 감지 재작성
- **핵심 수정**: Tuya 이벤트 로그 API (`/v1.0/devices/{id}/logs`) 도입
- 1분 폴링 사이 놓치는 짧은 문 열림(10~30초)을 이벤트 로그로 잡음
- 기존: 폴링 시점 `doorcontact_state`만 확인 → 놓침 빈번
- 변경: 매 폴링 시 최근 2분 이벤트 로그 조회 → 어떤 열림도 잡음
- `openedToday` + `firstOpenTime` 이벤트 로그 타임스탬프 기반

### 2. 새벽 전등 오작동 수정
- **원인**: bedTime 미기록 상태에서 mmWave none→presence 시 전등 ON
- **수정**: `sleepGuard` 도입 — bedTime OR (야간 23~07시 + 침대 zone) → 전등 자동화 억제
- 기존 bedTime 가드만으로는 취침 초기 30분(stationarySince 미달)에 무방비

### 3. mmWave 거리 중앙값 필터 + 임계값 조정
- `distHistory`: 최근 5개 거리 롤링 윈도우 → median 필터
- `filteredDistance`: 필터된 거리값 Firestore 저장
- 침대/책상 임계값: **200cm → 120cm** (기본값)
- Firestore `iot.config.bedThresholdCm`으로 런타임 조정 가능
- 다리 움직임 200cm+ 스파이크 → 중앙값으로 필터링

### 4. Flutter 앱 resume 시 day rollover
- `main.dart` `didChangeAppLifecycleState(resumed)` → `checkDayRollover()` 추가
- 밤새 앱 백그라운드 → 아침에 열면 어제 UI 보이던 문제 해결

### 5. Flutter presence 카드 개선
- `filteredDistance` 우선 사용 (fallback: raw distance)
- 임계값 Firestore config 연동 (`iot.config.bedThresholdCm`)
- 하드코딩 200cm → configurable 120cm 기본값
=======
- **버전**: v10.14.0
- **커밋**: `9fca909` feat: 스탠드 전원순환 모드 제어 + SESSION 업데이트

## 이번 세션 완료 작업

### 1. 자동 기상 감지 수정 (`3bcd50c`)
- Tuya 센서 극성 반전 수정 (true=open)
- openedToday 플래그 — 7시 전 문 열림 대응
- FCM notification 페이로드 (Doze 우회)
- 앱 _recoverWakeFromFirestore() 캐시 우회

### 2. IoT 자동화 확장 (`4c19e7e`)
- mmWave presence 폴링 (pollDoorSensor 통합, 매 1분)
- 취침 자동 감지 (peaceful + ≤200cm + 23~07시 + 30분)
- 전등 제어: 외출 OFF, 귀가 ON(18시+), 취침 OFF
- 방 비움(none 5분) → 전등 OFF (`f8776bb`)
- 방 복귀(none→presence + 18~07시) → 전등 ON
- FCM sleep 처리 (fg + bg)
- 홈 presence 카드 (StreamBuilder)

### 3. 홈데이 리브랜딩 (`27ec870`, `b522d4c`)
- 칩거 → 홈데이 전체 리네임
- 홈 UI 통일 (별도 페이지 제거 → 배경 그라데이션 전환)
- 홈데이 헤더 인라인
- 캘린더 홈데이 표시 (인디고 틴트 + 도트)

### 4. AI 비서 텔레그램 봇 (`5c06cc7`, `2b7c824`)
- Claude Sonnet 4 + tool use
- 9개 tool: add_todo, add_habit, add_goal, today_summary, set_light, set_desk_light, list_todos, complete_todo, iot_status, query_sensor
- 자연어 → Firestore CRUD + IoT 제어
- 내 봇 웹훅 등록 완료

### 5. 고시 크롤러 (`b522d4c`)
- pollGosiNotice(매일 08:00) + checkGosiManual
- **미해결**: gosi.kr GCP IP 차단 (ECONNRESET)

### 6. 스탠드 자동화 시도 (`9fca909`)
- deskLightCycle() 전원순환 모드 제어
- **결론**: 무선충전 배터리 스탠드라 플러그 제어 불가
>>>>>>> Stashed changes

## 미커밋 파일
- 없음

## 결정사항
<<<<<<< Updated upstream
- Tuya 이벤트 로그 API로 폴링 사이 놓침 보완 (웹훅 불필요)
- 침대 임계값 120cm — 실제 사용하면서 Firestore에서 런타임 조정 가능
- sleepGuard = bedTime OR (야간+침대zone) — 이중 보호
- 거리 중앙값 5개 윈도우 — 스파이크 제거에 충분

## 다음 할 일
- [ ] 내일 아침 기상 감지 테스트 (이벤트 로그 방식 확인)
- [ ] 오늘 밤 전등 오작동 테스트 (sleepGuard 확인)
- [ ] 임계값 120cm 실측 확인 → 필요시 Firestore config 조정
- [ ] 홈 대시보드 리디자인 (나열식 카드 → 리듬+그루핑)
- [ ] 고시 크롤러 대안 (로컬 Python 또는 다른 클라우드)
=======
- Tuya 웹훅 불필요 — 1분 폴링 충분
- bedTime = 최우선 가드 (전등/취침 재감지 잠금)
- 스탠드 자동화 → SwitchBot Bot 또는 Tuya 스마트전구로 교체 필요
- 홈 대시보드 리디자인 예정 (카드 나열 → 정보 밀도+그루핑)

## 다음 할 일
- [ ] 아침 자동 기상 테스트 (극성 수정 확인)
- [ ] 밤 자동 취침 테스트 (mmWave 30분)
- [ ] 홈 대시보드 리디자인
- [ ] AI 비서 tool 확장 (습관목록, 목표목록, 메모추가)
- [ ] 고시 크롤러 대안 (로컬 Python)
>>>>>>> Stashed changes
- [ ] 크리처 알람 식사 리마인더 확장
- [ ] 헤드위그 mmWave 연동 (실제 상태 기반 응답)

## 알려진 이슈
- gosi.kr GCP IP 차단
- 무선충전 스탠드 자동화 불가
- Codemagic CI 미검증
- 서명: release 빌드가 debug keystore 사용 중

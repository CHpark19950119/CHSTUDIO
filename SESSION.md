# Session Handoff
> 이 파일은 Claude Code 세션 간 작업 연속성을 위한 핸드오프 문서.
> 세션 종료 시 자동 업데이트됨. 다음 세션 시작 시 이 파일부터 읽는다.

## 마지막 세션
- **날짜**: 2026-03-20
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

## 미커밋 파일
- 없음

## 결정사항
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
- [ ] 크리처 알람 식사 리마인더 확장

## 알려진 이슈
- gosi.kr GCP IP 차단 (ECONNRESET)
- Codemagic CI 미검증
- 서명: release 빌드가 debug keystore 사용 중

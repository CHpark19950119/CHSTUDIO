# Session Handoff
> 이 파일은 Claude Code 세션 간 작업 연속성을 위한 핸드오프 문서.
> 세션 종료 시 자동 업데이트됨. 다음 세션 시작 시 이 파일부터 읽는다.

## 마지막 세션
- **날짜**: 2026-03-20
- **버전**: v10.14.1
- **커밋**: IoT 자동화 5대 버그 수정 + 임계값 220cm

## 이번 세션 완료 작업

### 1. 도어센서 기상 감지 재작성
- Tuya 이벤트 로그 API (`/v1.0/devices/{id}/logs`) 도입
- 1분 폴링 사이 놓치는 짧은 문 열림을 이벤트 로그로 잡음
- `openedToday` + `firstOpenTime` 이벤트 로그 타임스탬프 기반

### 2. 새벽 전등 오작동 수정
- `sleepGuard` 도입 — bedTime OR (야간 23~07시 + 침대 zone) → 전등 자동화 억제

### 3. mmWave 거리 중앙값 필터 + 임계값 조정
- `distHistory`: 최근 5개 거리 롤링 윈도우 → median 필터
- 침대/책상 임계값: **220cm** (침대 ~150, 책상 300+)
- Firestore `iot.config.bedThresholdCm`으로 런타임 조정 가능

### 4. Flutter 앱 resume 시 day rollover
- `didChangeAppLifecycleState(resumed)` → `checkDayRollover()` 추가

### 5. 텔레그램-Claude Code 브릿지
- `telegram_claude.js` — 새 봇(CHSTUDIO Code)으로 원격 Claude Code 실행
- `--resume SESSION_ID`로 단일 세션 유지

## 미커밋 파일
- `telegram_claude.js` (untracked)

## 결정사항
- Tuya 이벤트 로그 API로 폴링 사이 놓침 보완
- 침대 임계값 220cm (실측: 침대 ~150, 책상 300+)
- sleepGuard = bedTime OR (야간+침대zone) — 이중 보호
- 거리 중앙값 5개 윈도우 — 스파이크 제거
- 텔레그램 브릿지 봇 별도 토큰 사용 (AI 비서 봇과 분리)

## 다음 할 일
- [ ] 내일 아침 기상 감지 테스트 (이벤트 로그 방식)
- [ ] 오늘 밤 전등 오작동 테스트 (sleepGuard)
- [ ] 임계값 220cm 실측 확인 → 필요시 Firestore config 조정
- [ ] 홈 대시보드 리디자인
- [ ] 고시 크롤러 대안 (로컬 Python)
- [ ] AI 비서 tool 확장
- [ ] 크리처 알람 식사 리마인더 확장
- [ ] 헤드위그 mmWave 연동

## 알려진 이슈
- gosi.kr GCP IP 차단
- 무선충전 스탠드 자동화 불가
- Codemagic CI 미검증
- 서명: release 빌드가 debug keystore 사용 중

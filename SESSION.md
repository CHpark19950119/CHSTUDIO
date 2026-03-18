# Session Handoff
> 이 파일은 Claude Code 세션 간 작업 연속성을 위한 핸드오프 문서.
> 세션 종료 시 자동 업데이트됨. 다음 세션 시작 시 이 파일부터 읽는다.

## 마지막 세션
- **날짜**: 2026-03-18
- **버전**: v10.13.1

## 작업 중이던 것
### 1. 집 칩거(Home Day) 모드 — 신규 기능 (미커밋)
- `_isHomeDay` getter: 기상 후 3시간+ 외출 없으면 자동 감지, 또는 수동 `_noOuting`
- `_homeDayBanner()`: 홈 대시보드에 칩거 배너 (시간대별 메시지 + 재택 시간)
- `_homeDayPage()`: 칩거 전용 대시보드 (~200줄) — 히어로카드, 퀵액션, 컴팩트 레이아웃
- `home_routine_card.dart`: 외출 없으면 🏡 칩거 표시
- `home_daily_log.dart`: `_noOuting` → `_isHomeDay` 4곳 교체
- **상태**: 코드 작성 완료, 미커밋, 미테스트

### 2. 포커스 화장실 버튼 제거 (미커밋)
- `focus_screen.dart`: `_imBathroomBtn`, `_showBathroomDialog`, `_brOption` 삭제 (~64줄)
- **상태**: 완료

### 3. 문 열림 테스트 버튼 (미커밋)
- `settings_screen.dart`: "🚪 문 열림 테스트" 버튼 (idle→문열림→awake 검증)
- `door_sensor_service.dart`: `emitTestEvent()` 추가
- `wake_service.dart`: `resetForTest()` 추가
- **상태**: 완료

### 4. Auto-wake 버그 수정 (미커밋)
- `day_action_part.dart`: 이미 기상 기록 있을 때 auto-wake → 상태만 복원 (Firestore 안 건드림)
- **상태**: 완료

### 5. Codemagic CI 설정 (미커밋)
- `codemagic.yaml`: master push 트리거 추가
- `codemagic_build.sh`: 빌드 스크립트 (untracked)
- **상태**: 설정 완료, 미검증

## 미커밋 파일 (9 + 1 untracked)
| 파일 | 변경 | 목적 |
|------|------|------|
| `codemagic.yaml` | +6 | CI 트리거 설정 |
| `codemagic_build.sh` | new | 빌드 스크립트 |
| `lib/screens/focus/focus_screen.dart` | -64 | 화장실 버튼 제거 |
| `lib/screens/home_daily_log.dart` | ~8 | _noOuting→_isHomeDay |
| `lib/screens/home_routine_card.dart` | ~12 | 칩거 모드 표시 |
| `lib/screens/home_screen.dart` | +321 | 칩거 배너+대시보드+_isHomeDay |
| `lib/screens/settings_screen.dart` | +49 | 문 열림 테스트 버튼 |
| `lib/services/day_action_part.dart` | ~11 | auto-wake 버그 수정 |
| `lib/services/door_sensor_service.dart` | +13 | emitTestEvent() |
| `lib/services/wake_service.dart` | +8 | resetForTest() |

## 결정사항
- 칩거 감지 기준: 기상 후 **3시간**(180분) — 너무 짧으면 오탐 가능
- `_homeDayPage()`는 만들어졌지만 아직 탭/라우팅에 연결 안 됨 (배너만 표시 중)

## 다음 할 일
- [ ] 미커밋 변경사항 커밋
- [ ] 빌드 + 폰 테스트
- [ ] `_homeDayPage()` 실제 연결 (탭 0에서 칩거 시 자동 전환?)
- [ ] 습관 autoTrigger UI
- [ ] 오염된 Firestore 데이터 정리
- [ ] 투두→진행도 목표 연결 UI

## 알려진 이슈
- `_homeDayPage()`가 호출되는 경로 없음 — 위젯만 존재
- Codemagic CI 미검증

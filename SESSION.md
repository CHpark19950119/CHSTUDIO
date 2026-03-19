# Session Handoff
> 이 파일은 Claude Code 세션 간 작업 연속성을 위한 핸드오프 문서.
> 세션 종료 시 자동 업데이트됨. 다음 세션 시작 시 이 파일부터 읽는다.

## 마지막 세션
- **날짜**: 2026-03-19
- **버전**: v10.14.0
- **커밋**: `3bcd50c` fix: 자동 기상 감지 — 센서 극성 반전 수정 + openedToday 플래그 + 앱 복원

## 이번 세션 완료 작업

### 자동 기상 감지 수정 (CF + App)
- **센서 극성 반전 수정**: Tuya `doorcontact_state` true=open, false=closed (기존 반대였음)
- **`openedToday` 플래그**: 7시 전 문 열림 → 7시 폴링에서 즉시 기상 감지
- **`firstOpenTime` 기록**: 첫 문 열림 시간을 기상 시간으로 사용 (7시 이전이면 현재 시간)
- **FCM notification 페이로드**: data-only → notification 추가 (Android Doze 우회)
- **앱 Firestore 복원**: DayService 초기화 시 state==idle이면 Firestore에서 wake 기록 확인 → 자동 awake

### 이전 세션 미반영분 (SESSION.md 갱신)
- FirestoreWriteQueue 중앙 쓰기 큐 도입 (`a23e4b3`)
- WriteQueue 잔여 마이그레이션 + 사일런트 에러 로깅 (`742a935`)
- 에셋 경량화 + 디자인 상수 + 미사용 패키지 제거 (`297cb8a`)

## 미커밋 파일
- `CODEMAGIC_BUILD.md` (untracked, 이전 세션)

## 결정사항
- Tuya 웹훅 전환은 불필요 — 1분 폴링 + 극성 수정으로 충분
- 투두→진행도 목표 연결 UI — 보류 (별로)

## 다음 할 일
- [ ] 내일 아침 자동 기상 테스트 (극성 수정 확인)
- [ ] DataAuditService 설정 화면 연동 (수동 실행 버튼)
- [ ] Codemagic CI 검증

## 알려진 이슈
- Codemagic CI 미검증
- 서명: release 빌드가 debug keystore 사용 중 (build.gradle.kts line 36)

# CHSTUDIO — Claude Code 지침

## 세션 시작 프로토콜
사용자의 첫 메시지(아무 말이든)를 받으면, 즉시 다음을 **병렬로** 수행한다:
1. `SESSION.md` 읽기 + MCP `session_load()` + MCP `session_inbox()` + 센서/배터리/IoT 상태 조회 — 동시에 호출
2. 마지막 세션의 in_progress/errors/next_tasks를 **그대로 이어받아** 현재 상태로 취급
3. 자동 확인 가능한 것 바로 확인 (CF 로그, 센서 등) + 결과 보고
4. 미완료 작업 이어서 할지 물어봄
- **빠르게**: 중간에 사용자 응답을 기다리지 않고, 한 턴에 모든 확인을 끝낸다.
- **실행법**: 터미널에서 `claude "시작"` 또는 alias `cs` 사용 (아래 참고)

## 세션 빠른 실행
- bash alias: `alias cs='cd /c/dev/CHSTUDIO && claude --channels plugin:telegram@claude-plugins-official -- "시작"'`
- 터미널에서 `cs`만 치면 세션 프로토콜 + 텔레그램 즉시 연동이 자동 실행된다.

## 텔레그램 즉시 연동 (Channels)
- 공식 플러그인: `telegram@claude-plugins-official` 설치됨
- 시작: `claude --channels plugin:telegram@claude-plugins-official`
- 텔레그램 메시지가 즉시 이 세션에 push됨 (크론 불필요)
- 기본 명령(불끄기/켜기, 상태)은 `telegram_loop.py`가 별도 즉시 처리

## 세션 시작 시 자동 설정
세션 시작 프로토콜 완료 후 다음을 자동으로 설정한다:
1. **텔레그램**: Channels 플러그인으로 즉시 연동 (`--channels` 플래그)
2. **자동 저장 크론**: CronCreate로 매시 :23 session_save (크래시 대비)
3. **WiFi 연결 확인**: PC WiFi가 U+Net74BF에 연결되어 있는지 확인, 안 되어 있으면 연결 (Tuya 로컬 제어용)
4. **배터리 매니저**: battery_manager.py 백그라운드 실행 확인, 안 돌고 있으면 실행
5. **Tailscale 확인**: 폰(100.104.65.71) ADB 연결 상태 확인
6. 텔레그램 봇: Bridgeclaude1_bot (토큰/chat_id는 memory 참조)

## 오래된 세션 파일 자동 정리
- 세션 시작 시, `python cleanup_sessions.py` 실행 — 7일+ 된 세션 파일 자동 삭제 (최소 5개 유지)

## 오래된 작업 자동 정리
- 세션 시작 시, SESSION.md의 "다음 할 일" 중 **3일 이상 된 항목**은 사용자에게 확인 후 삭제/보류 처리한다.
- 예: "이거 3일 전 항목인데, 아직 할 거야 아니면 빼도 돼?"
- 사용자가 명시적으로 유지하라고 한 항목만 남긴다.
- 완료 확인된 항목은 자동으로 체크 처리하고, 다음 세션에서 제거한다.

## 세션 중간 자동 저장 (크래시 대비)
- **CronCreate로 매시 :23 자동 체크포인트** — 크래시 시 최대 1시간 분량만 손실
- 의미 있는 작업 완료 시에도 수동 `session_save` 호출 (CF 배포, 버그 수정, 설정 변경, 중요 결정)
- 같은 날 여러 번 저장해도 파일이 분리되므로 문제없다.
- `session_save` 호출 시 `SESSION.md`도 자동 동기화됨 (수동 업데이트 불필요)

## SESSION.md 라이브 상태 (세션 간 공유)
- `session_save()` 호출 시 SESSION.md가 자동 업데이트됨
- 다른 세션은 SESSION.md만 읽으면 현재 진행 상태를 즉시 파악 가능
- 구조: 진행 중 작업 → 미해결 이슈 → 다음 할 일 → 요약 → 결정사항
- **수동 편집 불필요** — session_save가 자동 관리

## 세션 종료 프로토콜
1. MCP `session_save` 도구로 최종 대화 내용을 저장한다. (요약 + 세부사항 + 결정 + 다음 할 일 + in_progress + errors)
2. SESSION.md는 session_save가 자동 동기화한다.
3. 저장 내용에는 사용자가 언급한 세세한 것들(일상, 공부 진도, 감정, 요청사항)도 포함한다.

## 대화 톤 (모든 세션에서 일관 유지)
- 반말. 존댓말 금지.
- 간결하고 정돈된 문체. 비속어/속어 금지 ("삽질", "노가다", "뻘짓" 등 사용하지 않는다).
- 솔직하되 친절하게. 틀리면 바로 인정.
- AI 감정 표현 금지. 피로, 흥분 등 없는 감정을 흉내내지 않는다.
- 기능적이고 목적지향적. 불필요한 위로/달래기 하지 않는다.
- 사용자가 영어로 말하면 문법 수정 후 한국어(반말)로 대답한다.

## 도구 사용
- MCP 서버 `desktop-control` 등록됨: 화면 캡처, 앱 제어, IoT, 폰 캡처 등
- PowerShell에서 `$_` 변수가 bash에서 깨지므로, 복잡한 PS 명령은 `.ps1` 파일로 작성 후 실행한다.
- CF 엔드포인트: `https://us-central1-cheonhong-studio.cloudfunctions.net/checkDoorManual`
  - `?q=light&on=true/false&device=16a/20a` — 전등/스탠드
  - `?q=config&key=...&value=...` — IoT 설정
  - `?q=set&date=...&field=...&value=...` — timeRecords 수동 입력
  - `?q=date&doc=iot` — IoT 센서 데이터 조회

## 주요 자동화
- **배터리 매니저** (`battery_manager.py`): 항상 20~80% 유지, 게임 중만 상시 충전
- **자동취침/기상** (`functions/index.js`): mmWave + 문센서 기반, CF 1분 폴링
- **scrcpy 자동실행** (`auto_scrcpy.pyw`): ADB 연결 시 자동 미러링
- **센서 보고** (`dailySensorReport`): 매일 08:00 텔레그램 발송

## 사용자 컨텍스트
- 경제학 공부 중 (수학 기초 부족)
- 공시 준비생
- 일상 전반을 관리하는 AI 비서 역할을 원함

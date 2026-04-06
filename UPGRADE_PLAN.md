# CHSTUDIO AI 시스템 업그레이드 설계서

> **확정된 계획** — 2026-04-01 사용자 승인 완료
> 이 문서는 제안서가 아니라 실행 계획이다.

---

## 목차

- [A. Claude Code 인프라 업그레이드](#a-claude-code-인프라-업그레이드)
  - [A1. 텔레그램 안정성](#a1-텔레그램-안정성)
  - [A2. 에이전트 관리](#a2-에이전트-관리)
  - [A3. 세션 핸드오프 자동화](#a3-세션-핸드오프-자동화)
  - [A4. MCP 서버 복원력](#a4-mcp-서버-복원력)
  - [A5. 멀티채널 접근](#a5-멀티채널-접근)
- [B. 생활 관리 시스템](#b-생활-관리-시스템)
  - [B1. 일일 리듬 AI](#b1-일일-리듬-ai)
  - [B2. 공시 학습 보조](#b2-공시-학습-보조)
  - [B3. 인생 발굴 (31년 아카이브)](#b3-인생-발굴-31년-아카이브)
  - [B4. 정서 웰빙](#b4-정서-웰빙)
- [C. 콘텐츠 & 엔터테인먼트](#c-콘텐츠--엔터테인먼트)
  - [C1. 이미지 소싱 Pro](#c1-이미지-소싱-pro)
  - [C2. TTS 시나리오 엔진](#c2-tts-시나리오-엔진)
  - [C3. 미디어 큐레이션](#c3-미디어-큐레이션)
- [D. 앱 코드 품질](#d-앱-코드-품질)
  - [D1. Flutter Analyze Zero](#d1-flutter-analyze-zero)
  - [D2. 서비스 레이어 정리](#d2-서비스-레이어-정리)
  - [D3. UI 다듬기](#d3-ui-다듬기)
- [실행 타임라인](#실행-타임라인)

---

## A. Claude Code 인프라 업그레이드

### A1. 텔레그램 안정성

#### 현재 상태
- `claude --channels plugin:telegram@claude-plugins-official`로 텔레그램 연동
- 세션 중간에 채널 플러그인이 랜덤으로 끊김
- 끊기면 사용자가 메시지를 보내도 Claude가 수신 못 함
- 수동으로 세션 재시작해야 복구됨
- `--continue` 옵션으로 이어받으면 MCP까지 같이 끊기는 경우 발생

#### 문제점
1. 끊김 감지 메커니즘 없음 — 끊겨도 Claude 세션 자체는 계속 돌아감
2. 자동 복구 없음 — 사용자가 직접 터미널에서 재시작해야 함
3. 끊김 시 텔레그램 메시지 유실 — 버퍼링/재전송 없음
4. 사용자가 외출 중이면 PC 접근 불가 → 복구 불가능

#### 해결안: Watchdog 프로세스

```
telegram_watchdog.py
├── 텔레그램 Bot API 직접 폴링 (getUpdates, 30초 long-polling)
├── Claude 세션 상태 모니터링 (프로세스 존재 확인)
├── 끊김 감지 시 자동 재시작
├── 미수신 메시지 버퍼 → 재시작 후 전달
└── 상태 리포트 (1시간마다 텔레그램으로 heartbeat)
```

**핵심 구조:**
- `telegram_watchdog.py` — 독립 프로세스, battery_manager.py처럼 항상 실행
- Bot API `getUpdates`로 새 메시지 직접 감지
- Claude 세션의 텔레그램 채널이 응답하는지 확인 (heartbeat 파일 체크)
- 끊김 판정: 메시지 수신 후 60초 내 heartbeat 없으면 끊김으로 판정
- 복구: `claude --continue --channels plugin:telegram@claude-plugins-official` 재실행
- 미수신 메시지는 `.telegram_buffer.json`에 저장 → 재시작 후 세션에 전달

**구현 단계:**
1. `telegram_watchdog.py` 스켈레톤 작성 — Bot API getUpdates 루프
2. Claude 세션 heartbeat 체크 로직 (`.claude_heartbeat` 파일 타임스탬프)
3. 끊김 감지 + 자동 재시작 로직
4. 메시지 버퍼링 + 재전달
5. 상태 heartbeat (1시간마다 텔레그램으로 "alive" 전송)
6. battery_manager.py와 통합 (같이 시작/모니터링)

**우선순위:** **높음** — 텔레그램이 주 통신 수단이라 끊기면 전체 시스템 무력화

---

### A2. 에이전트 관리

#### 현재 상태
- Claude Code의 백그라운드 에이전트(`Agent` 도구)로 병렬 작업 실행 가능
- 2026-04-01 사고: 이미지 소싱 에이전트가 스크립트를 무한 재생성+실행 → 1900장 사진 폭탄
- 에이전트에 실행 횟수/시간 제한 없음
- kill 해도 새 프로세스 생성하며 반복

#### 문제점
1. 에이전트에 내장 제한 없음 — 무한 루프 가능
2. 출력 모니터링 없음 — 폭주해도 감지 어려움
3. kill switch 없음 — 프로세스 kill해도 재생성
4. 리소스 소모 제한 없음 — 디스크/네트워크/텔레그램 API 무제한 사용

#### 해결안: Agent Wrapper + 가드레일

**agent_guard.py** — 에이전트 실행 래퍼:

```python
# 사용 예시
agent_guard.run(
    task="이미지 소싱",
    max_files=30,          # 최대 파일 수
    max_duration=300,      # 최대 5분
    max_telegram_msgs=20,  # 텔레그램 전송 제한
    output_dir="/tmp/agent_work/",
    on_limit="stop_and_report"
)
```

**핵심 구조:**
- 모든 에이전트 작업을 `agent_guard.py`를 통해 실행
- 실행 전 제한값 필수 설정 (없으면 기본값 적용: 파일 30개, 5분, 텔레그램 20건)
- 실시간 모니터링: 파일 생성 수, 네트워크 요청 수, 실행 시간
- 제한 초과 시 즉시 중단 + 텔레그램으로 리포트
- kill switch: `.agent_kill` 파일 생성 시 모든 에이전트 즉시 중단
- 실행 로그: `.agent_log.json`에 모든 에이전트 실행 이력 기록

**CLAUDE.md 규칙 추가:**
```
## 에이전트 실행 규칙
- 백그라운드 에이전트 실행 시 반드시 agent_guard.py 사용
- 파일 생성/전송 작업은 반드시 상한선 설정
- 이미지 소싱: 기본 max_files=20, max_telegram_msgs=15
- 대량 작업(50건 이상): 사용자 사전 확인 필수
```

**구현 단계:**
1. `agent_guard.py` 코어 — 제한 체크 + 프로세스 관리
2. 텔레그램 전송 카운터 (`sent_urls.json` 활용)
3. kill switch 메커니즘 (`.agent_kill` 파일)
4. CLAUDE.md에 에이전트 규칙 추가
5. image_fetcher.py에 `--limit` 옵션 내장 (독립 실행 시에도 제한)

**우선순위:** **긴급 — Phase 1 (완료)** — 재발 방지 필수. image_fetcher `--limit` 옵션은 구현됨.

---

### A3. 세션 핸드오프 자동화

#### 현재 상태
- `SESSION.md`를 수동으로 관리 (session_save MCP가 업데이트)
- 세션 종료 시 session_save 호출 → SESSION.md 갱신
- 새 세션 시작 시 SESSION.md 읽기 → 이전 컨텍스트 복원
- 매시 :23 자동 저장 크론 설정

#### 문제점
1. session_save 호출 전 크래시 → 최대 1시간 작업 손실
2. SESSION.md는 요약본 — 세부 대화 맥락(감정, 일상 이야기 등) 손실
3. 이전 세션의 코드 변경 사항을 새 세션이 파악하려면 git diff 필요
4. 여러 세션이 동시 실행 시 SESSION.md 충돌 가능
5. 세션 이관 시 MCP 상태(크론, 연결 등) 복원 안 됨

#### 해결안: 3단계 자동 핸드오프

**Level 1 — 자동 체크포인트 강화 (즉시):**
- 매시 :23 자동 저장 유지 + **의미 있는 작업 완료 시 즉시 저장** (이미 규칙 있음, 준수 강화)
- `SESSION.md`에 **대화 요약 섹션** 추가 — 기술 작업뿐 아니라 잡담/감정/일상도 기록
- 크래시 복구: `.session_checkpoint.json` 매 5분 자동 저장 (MCP 크론)

**Level 2 — 세션 컨텍스트 보존 (이번 주):**
- `.sessions/` 디렉토리에 세션별 상세 로그 저장
- 세션 시작 시 `git log --since="last session"` 자동 실행 → 코드 변경 사항 파악
- 환경 상태 자동 체크리스트: WiFi, battery_manager, MCP, Tailscale, ADB
- 이전 세션의 미완료 작업을 자동으로 현재 세션 TODO에 추가

**Level 3 — 무중단 이관 (다음 주):**
- 세션 종료 전 자동 체크: 실행 중인 크론, 백그라운드 프로세스, 열린 파일 목록
- 새 세션 시작 시 자동 복원: 크론 재설정, battery_manager 확인, 텔레그램 연결
- `session_resume.py` — 이전 세션의 상태를 완전히 복원하는 원스탑 스크립트

**구현 단계:**
1. `.session_checkpoint.json` 자동 저장 로직 (5분 크론)
2. SESSION.md 포맷 확장 — 대화 컨텍스트 섹션 추가
3. 세션 시작 프로토콜에 git diff 자동 실행 추가
4. `session_resume.py` 스크립트 작성
5. CLAUDE.md 세션 프로토콜 업데이트

**우선순위:** **높음** — 매 세션 시작마다 10분씩 날리는 문제 해결

---

### A4. MCP 서버 복원력

#### 현재 상태
- `desktop-control` MCP 서버: 화면 캡처, 앱 제어, 폰 제어, IoT 등
- 세션 `--continue`로 이어받으면 MCP 연결이 끊기는 경우 발생
- 끊기면 phone_unlock, phone_tap 등 폰 제어 도구 전부 사용 불가
- 복구: 새 세션 시작만이 유일한 방법

#### 문제점
1. MCP 연결 끊김 감지 없음 — 도구 호출 시 에러로 처음 인지
2. 자동 재연결 없음
3. MCP 없이 대체 수단 없음 (직접 ADB 명령은 가능하지만 MCP 도구처럼 편하지 않음)
4. `--continue` 시 MCP 서버 프로세스가 새로 뜨지 않는 버그

#### 해결안: Health Check + Fallback

**MCP Health Monitor:**
- 세션 시작 시 MCP 도구 1개 테스트 호출 (예: 화면 해상도 조회)
- 실패 시 자동 재시작 시도
- 재시작도 실패 시 fallback 모드 전환

**Fallback 매핑 (MCP 없을 때 직접 명령):**

| MCP 도구 | Fallback 명령 |
|---|---|
| `phone_unlock()` | `adb shell input keyevent WAKEUP && adb shell input swipe 540 2000 540 1000 && adb shell input text 0119 && adb shell input keyevent ENTER` |
| `phone_tap(x,y)` | `adb shell input tap {x*2} {y*2}` |
| `phone_screenshot()` | `adb exec-out screencap -p > /tmp/screen.png` |
| `phone_focus(s,m)` | `adb shell am start -d "cheonhong://focus?subject={s}&mode={m}"` |
| `iot_light(d,on)` | `python -c "import tinytuya; ..."` (tinytuya 직접) |
| `bt_connect(d)` | PowerShell BT 스크립트 직접 실행 |

**CLAUDE.md에 fallback 규칙 추가:**
```
## MCP Fallback
- MCP 도구 호출 실패 시, 위 fallback 매핑 테이블 참조하여 직접 명령 실행
- 3회 연속 실패 시 텔레그램으로 "MCP 끊김" 알림
- 새 세션 시작 권고
```

**구현 단계:**
1. 세션 시작 프로토콜에 MCP 헬스체크 추가
2. fallback 매핑 테이블을 CLAUDE.md에 추가
3. MCP 실패 시 자동 fallback 전환 로직 (CLAUDE.md 규칙)
4. 텔레그램 알림 연동

**우선순위:** **중간** — MCP 없어도 ADB 직접 명령으로 대부분 가능, 편의성 문제

---

### A5. 멀티채널 접근

#### 현재 상태
- 유일한 외부 접근: 텔레그램 (Channels 플러그인)
- 텔레그램이 끊기면 PC 앞에 있지 않는 한 Claude와 통신 불가
- 야사 전송에 텔레그램이 최적이라 대체보다 보완 필요

#### 문제점
1. 단일 채널 의존 — 텔레그램 끊기면 접근 불가
2. 텔레그램 Bot API 제한: 파일 크기 50MB, 히스토리 검색 불가
3. 데스크탑에서 Claude 세션 직접 접근은 터미널만 가능

#### 해결안: Discord 백업 + Fakechat 브라우저 접근

**Discord 백업 채널:**
- `discord.py` 봇으로 별도 채널 운영
- 텔레그램 끊김 시 자동으로 Discord로 전환
- Discord는 파일 크기 제한이 더 관대 (25MB free, 50MB Nitro)
- 명령 체계 통일: 텔레그램과 동일한 명령어

**Fakechat 브라우저 접근 (Tailscale 경유):**
- Fakechat: 로컬 웹 UI → Claude 세션에 메시지 전달
- Tailscale 네트워크 내에서만 접근 가능 (보안)
- 폰 브라우저에서 `http://100.67.227.107:PORT` 접속
- 텔레그램/Discord 둘 다 안 될 때 최후 수단

**채널 우선순위:**
1. 텔레그램 (기본, 야사 전송 최적)
2. Discord (백업, 텔레그램 끊김 시)
3. Fakechat (최후 수단, Tailscale 내부만)

**구현 단계:**
1. Discord 봇 생성 + `discord_channel.py` 작성
2. Claude 세션에 Discord 메시지 전달 메커니즘
3. Fakechat 설정 (로컬 웹서버 + Tailscale 포트 노출)
4. 채널 자동 전환 로직 (`channel_router.py`)
5. telegram_watchdog.py와 통합 — 끊김 시 자동 Discord 전환

**우선순위:** **낮음 (Phase 3)** — A1 텔레그램 안정성 해결이 먼저, 그 다음 백업 채널

---

## B. 생활 관리 시스템

### B1. 일일 리듬 AI

#### 현재 상태
- PL7 블루투스 스피커로 TTS 알람 (`tts_say.py`)
- battery_manager.py가 mmWave 센서로 재실/부재 감지
- Tuya 자동화로 기상 감지 (문 열림 → NotificationListener → Firestore)
- 취침은 mmWave 기반 CF 판정
- 일일 리듬 불규칙: 06:28 취침 등 극단적 패턴 반복

#### 문제점
1. 알람만 있고 수면 유도 없음 — 늦게까지 야사/게임하다 취침 지연
2. 자극 루프 감지 없음 — 게임(ADB로 확인 가능) + 야사(텔레그램 전송 로그) 패턴 미추적
3. 정시 체크인이 비일관적 — 크론 있지만 체크인 내용이 형식적
4. 운동 추적 없음
5. 목표 취침 시간(1:00)과 실제의 괴리 추적/개입 없음

#### 해결안: 일일 리듬 관리 엔진

**자동 감지 시스템:**

```
daily_rhythm.py (또는 battery_manager.py 확장)
├── 자극 루프 감지
│   ├── ADB: 현재 실행 앱 확인 (게임, 브라우저 등)
│   ├── 텔레그램 로그: 야사 전송 시간대 + 빈도
│   ├── mmWave: 심야 재실 + 화면 ON → 자극 루프 판정
│   └── 감지 시: 텔레그램 알림 "지금 뭐 하는 중이야?" + 경과 시간
├── 수면 유도
│   ├── 목표 취침 30분 전: PL7 TTS "취침 준비" + 조명 디밍
│   ├── 목표 취침 시간: PL7 TTS "잘 시간이야" + 조명 OFF
│   ├── 초과 시: 15분마다 부드러운 리마인드 (3회까지)
│   └── 극단: 충전 OFF (80% 이상일 때만) — 사용자 사전 동의 필요
├── 기상 관리
│   ├── 알람: PL7 TTS (현재 작동 중)
│   ├── 미기상 시: 5분 간격 재알람 (3회)
│   ├── 기상 확인: mmWave + 문 열림 + 폰 잠금해제
│   └── 기상 후: 오늘 일정/할 일 브리핑
├── 매 정시 체크인
│   ├── 현재 활동 확인 (ADB 포그라운드 앱)
│   ├── 순공시간 현황
│   ├── 남은 할 일
│   └── 간단한 코멘트 (강압적이지 않게)
└── 운동 추적
    ├── NFC 태그: 운동 시작/종료
    ├── 또는 수동 입력 (텔레그램 "운동 30분")
    └── Firestore 기록 + 주간 통계
```

**핵심 원칙:**
- **강압적이지 않게** — 알림은 정보 전달, 결정은 사용자
- **감지 먼저, 질문 나중** — "뭐 해?" 대신 "게임 2시간째인데, 괜찮아?"
- **점진적 개입** — 1차 알림 → 2차 리마인드 → 3차 직접적 코멘트
- **예외 존중** — 사용자가 "오늘은 늦게 잘 거야" 하면 해당 날 수면 유도 중단

**구현 단계:**
1. battery_manager.py에 ADB 포그라운드 앱 체크 추가
2. 자극 루프 감지 로직 (게임 30분+, 브라우저 심야 1시간+)
3. 수면 유도 크론: 목표 취침 30분 전부터 활성화
4. 기상 후 브리핑 자동화 (Firestore 오늘 데이터 + 날씨 + 일정)
5. 정시 체크인 내용 강화 (ADB 앱 + 순공 + 할 일)
6. Firestore `timeRecords.{date}.exercise` 필드 추가

**우선순위:** **높음 (Phase 2)** — 리듬 정상화가 공부/생활 전체의 기반

---

### B2. 공시 학습 보조

#### 현재 상태
- 외무영사직 7급 공시 준비 중
- 과목: 자료해석, 영어, 경제학 (수학 기초 부족)
- Focus 세션으로 공부 시간 추적 중
- 공부 내용 분석/취약점 파악은 미구현

#### 문제점
1. 공부 시간만 추적하고 내용/효율은 추적 안 함
2. 자료해석 연습 지원 없음
3. 경제학 개념 질문에 대한 맞춤형 설명 없음
4. 취약 단원/개념 자동 파악 없음
5. 오답 패턴 분석 없음

#### 해결안: 학습 보조 시스템

**자료해석 트레이너:**
- 기출 문제 PDF → 텔레그램으로 매일 3문제 전송
- 시간 제한 (문제당 3분) + 타이머
- 정답률/소요시간 Firestore 기록
- 취약 유형 자동 분류 (표, 그래프, 증감률, 비율 등)

**경제학 개념 카드:**
- 사용자가 모르는 개념 질문 → 수학 기초부터 설명
- 설명 이력 Firestore 저장 → 반복 질문 시 이전 설명 참조
- 주간 복습: 이번 주 질문한 개념 요약 전송

**포커스 세션 인텔리전스:**
- Focus 세션 시작 시 과목 선택 → 해당 과목 오늘 목표 표시
- 세션 종료 시 "뭐 공부했어?" 간단 입력 → 학습 로그
- 주간 리포트: 과목별 시간 배분 + 목표 대비 달성률

**구현 단계:**
1. Firestore `study_log.{date}` 구조 설계
2. 자료해석 문제 DB 구축 (기출 PDF 파싱)
3. 텔레그램 일일 문제 전송 크론
4. 경제학 질문-답변 로그 시스템
5. 주간 학습 리포트 자동 생성 (`generate_weekly_report.py` 확장)
6. 앱 Focus 세션에 학습 내용 입력 UI 추가

**우선순위:** **중간 (Phase 4)** — 리듬 정상화 후 학습 효율 최적화

---

### B3. 인생 발굴 (31년 아카이브)

#### 현재 상태
- 로드맵 v13 (`박천홍_인생로드맵_v13.html`) — 15호기, 성적 심리 심층 분석
- 소설 v4 (`허락_제1부_흙_v4.html`) — 자전적 소설
- Google Timeline 데이터 있음 (`timeline_data.json`)
- 카카오톡 백업 없음 (추출 필요)
- 카드 기록 분석 미시작

#### 문제점
1. 과거 데이터가 흩어져 있음 — 사진, 카톡, 카드, 위치 각각 별도
2. 시간순 통합 타임라인 없음
3. 로드맵 v13이 이미 방대하지만 실제 데이터 기반 검증 안 됨
4. 기억의 빈 구간 채우기 어려움

#### 해결안: Life Archaeology 파이프라인

**데이터 소스별 추출:**

| 소스 | 추출 방법 | 데이터 |
|---|---|---|
| 사진 | EXIF 메타데이터 파싱 | 날짜, 위치, 기기 |
| Google Timeline | `timeline_data.json` 파싱 | 방문 장소, 이동 경로, 시간대 |
| 카카오톡 | 앱 백업 → 텍스트 추출 | 대화, 날짜, 상대방 |
| 카드 기록 | 앱/PDF → 파싱 | 지출, 장소, 날짜, 금액 |
| SNS | Instagram/Facebook 데이터 다운로드 | 게시물, 날짜, 사진 |
| 앱 Firestore | 기존 앱 데이터 | 학습, 습관, 타임레코드 |

**통합 타임라인:**
```
life_timeline.py
├── 소스별 파서 (photo_parser, kakao_parser, card_parser, timeline_parser)
├── 통합 이벤트 DB (SQLite or Firestore)
│   ├── date, source, type, content, location, people, mood
│   └── 인덱스: 날짜별, 사람별, 장소별
├── 시각화
│   ├── HTML 타임라인 (연도별/월별)
│   ├── 지도 뷰 (방문 장소 히트맵)
│   └── 관계 그래프 (사람별 상호작용 빈도)
└── 로드맵 v14 연동
    ├── 실제 데이터로 로드맵 사실 검증
    ├── 빈 구간 발견 → 사용자에게 질문
    └── 새 에피소드 발굴
```

**Known Places 매핑** (기존 프로젝트 `project_known_places.md` 연장):
- `geocode_cache.json` 활용 — Nominatim 부정확 보정
- 자주 가는 장소 자동 태깅 (집, 학교, 도서관, 이화여대 등)

**구현 단계:**
1. Google Timeline 파서 (`timeline_data.json` → 구조화된 이벤트)
2. 사진 EXIF 파서 (폰 사진 폴더 스캔)
3. 카카오톡 백업 추출 가이드 + 파서
4. 통합 이벤트 DB 설계 (SQLite)
5. HTML 타임라인 시각화
6. 로드맵 v14 연동 — 데이터 기반 사실 검증

**우선순위:** **중간 (Phase 3)** — 데이터 수집이 먼저, 분석은 점진적

---

### B4. 정서 웰빙

#### 현재 상태
- 사용자는 우울증을 명시적으로 부정함 — 우울증 치료 프레임 금지
- 실제 문제: 심야 자극 루프 (게임 → 야사 → 늦은 취침 → 늦은 기상 → 하루 망침)
- 앱에 Creature 시스템 있음 (`data/creature`) — 보상/동기부여용
- 데일리 로그에 무드 기록 기능 있음

#### 문제점
1. 자극 루프가 수면/학습 양쪽을 파괴하는 핵심 문제
2. "의지력으로 해결" 접근은 실패 반복
3. 동기부여 시스템(Creature)이 실제 행동 변화로 이어지지 않음
4. 감정/컨디션 추적이 불규칙

#### 해결안: 환경 설계 기반 행동 관리

**이것은 치료가 아니라 환경 설계다.**

**자극 관리 자동화:**
- 심야(00:00~) 자극 콘텐츠 접근 시 → 감지 + 부드러운 알림
- "차단"이 아니라 "인지" — "야사 보기 시작한 지 40분이야"
- 사용자가 설정한 규칙 자동 적용 (예: "1시 이후 야사 요청하면 리마인드")
- 이미지 소싱 시간대 제한: 사용자 설정 가능 (기본: 22:00~01:00)

**수면 위생 자동화** (B1과 연동):
- 취침 1시간 전: 조명 디밍 (tinytuya)
- 취침 30분 전: PL7 "곧 잘 시간이야" + 블루라이트 필터 리마인드
- 취침 시간: 조명 OFF
- 다음 날 기상 시: 전날 취침/기상 시간 + 수면 시간 리포트

**동기부여 강화:**
- Creature 시스템을 실제 행동과 연동 강화
  - 목표 시간 취침 → 보상
  - 순공 목표 달성 → 보상
  - 자극 루프 없이 하루 보냄 → 보상
- 주간 스코어보드: 텔레그램으로 주간 요약 전송

**핵심 원칙:**
- 우울증 프레임 절대 사용 금지
- 강압/차단 아님 — 인지 + 환경 설계
- 사용자가 "오늘은 괜찮아" 하면 즉시 중단
- 데이터 기반: 실제 패턴을 보여주고 사용자가 판단

**구현 단계:**
1. B1 자극 루프 감지 구현 (ADB 앱 체크)
2. 이미지 소싱 시간대 설정 기능
3. 수면 위생 자동화 (tinytuya 조명 + PL7 TTS)
4. Creature 보상 연동 강화 (앱 코드 수정)
5. 주간 행동 리포트 자동 생성

**우선순위:** **높음 — B1과 동시 진행** — 자극 관리 = 수면 관리 = 학습 관리

---

## C. 콘텐츠 & 엔터테인먼트

### C1. 이미지 소싱 Pro

#### 현재 상태
- `image_fetcher.py` — Reddit JSON + RedGifs + xhamster Photos
- 카테고리: anal, asian, latin, general, amateur, body, duo, pretty, celeb 등
- `--send` 옵션으로 텔레그램 직접 전송
- `--user` 모드로 특정 유저 게시물 수집
- `sent_urls.json`으로 중복 방지
- 사고 이력: 에이전트 폭주로 1900장 전송 (2026-04-01)
- CF Workers 프록시: `img-proxy.cjsghd8064.workers.dev` (ISP 차단 우회)

#### 문제점
1. 에이전트 실행 시 제한 없음 → 폭주 가능 (A2로 해결 중)
2. 취향 학습 없음 — 매번 같은 카테고리 수동 지정
3. 품질 필터링 미흡 — 썸네일, 저해상도, 광고 이미지 혼입
4. 새 크리에이터 발굴 자동화 없음
5. 아카이브 관리 없음 — 전송 후 로컬 임시 파일만 삭제

#### 해결안: 이미지 소싱 v2

**image_fetcher.py 업그레이드:**

```python
# 새 기능
--limit N          # 세션당 최대 전송 수 (기본: 30)
--quality          # 품질 필터: 해상도 800x600+, 파일 100KB+
--discover         # 새 크리에이터/서브 자동 발굴
--gallery-all      # 갤러리 포스트 내 전체 이미지 전송
--taste            # 취향 기반 자동 선별
--archive          # 로컬 아카이브에 저장 (전송과 별도)
--schedule         # 일일 자동 소싱 (크론 등록)
```

**취향 학습 시스템:**
- `taste_profile.json` — 사용자 반응 기록
  - 텔레그램 리액션 분석: 하트/따봉 = 좋아함, 없음 = 보통
  - 카테고리별 선호도 점수
  - 특정 크리에이터 선호도
- 자동 추천: 선호도 높은 카테고리 + 유사 서브 자동 확장
- 주간 취향 리포트

**품질 필터링 강화:**
- 해상도 체크: 800x600 미만 스킵
- 파일 크기: 100KB 미만 스킵 (썸네일)
- 중복 해시: `sent_urls.json` + 이미지 해시 (perceptual hash)
- 광고/스팸 필터: 텍스트 오버레이 감지 (간단한 이미지 분석)

**새 크리에이터 발굴:**
- 좋아하는 서브의 Top 포스터 자동 추출
- `--user` 히스토리에서 유사 크리에이터 추천
- 주 1회 "이번 주 발견" 텔레그램 전송

**아카이브 관리:**
- `.image_archive/` 디렉토리 — 카테고리별 정리
- 최대 용량 제한 (기본: 5GB, 초과 시 오래된 것부터 삭제)
- 즐겨찾기 보호 (삭제 안 됨)

**구현 단계:**
1. `--limit` 옵션 추가 (완료)
2. `--quality` 필터 구현 (해상도/크기 체크)
3. `--gallery-all` 갤러리 전체 이미지 지원
4. `taste_profile.json` + 취향 학습 기초
5. 새 크리에이터 발굴 (`--discover`)
6. 아카이브 관리 (`--archive`)
7. 일일 자동 소싱 크론

**우선순위:** **Phase 1 일부 완료** — `--limit` 구현됨. 나머지는 Phase 3~4

---

### C2. TTS 시나리오 엔진

#### 현재 상태
- `edge_tts_play.py` — Edge TTS로 시나리오 재생 (무료, 한국어 ko-KR-SunHiNeural)
- `tts_say.py` — 단발 TTS (알람, 알림용)
- ElevenLabs Starter 계정: 크레딧 소진, 4/25 리셋
- ElevenLabs Free 계정: 10,000자, premade 보이스만
- 시나리오 파일: `scenarios/gold_digger*.txt`
- PL7 블루투스 스피커로 출력

#### 문제점
1. ElevenLabs 크레딧 소진 → 고품질 TTS 사용 불가 (4/25 리셋까지)
2. Edge TTS는 무료지만 자연스러움 떨어짐 (에로틱 톤 부족)
3. 시나리오 풀이 빈약 — 3개 파일만 존재
4. 시나리오 자동 생성 없음
5. 다중 보이스 지원 미흡 (Edge TTS는 가능하지만 미구현)

#### 해결안: TTS 시나리오 엔진 v2

**2단계 TTS 전략:**

| 기간 | 엔진 | 용도 |
|---|---|---|
| ~4/25 | Edge TTS (ko-KR-SunHiNeural) | 일반 시나리오 |
| ~4/25 | ElevenLabs Free (10K자) | 핵심 장면만 |
| 4/25~ | ElevenLabs Starter (리셋) | 고품질 전체 |
| 상시 | Edge TTS | 알람/알림/일반 |

**시나리오 풀 확장:**
```
scenarios/
├── gold_digger_v3.txt          # 기존
├── office_after_hours.txt      # 직장 설정
├── study_break.txt             # 공부 중 휴식
├── morning_routine.txt         # 아침 루틴
├── video_call.txt              # 영상통화 설정
├── neighbor.txt                # 이웃 설정
├── trainer.txt                 # PT 설정
└── custom/                     # 사용자 커스텀
```

**시나리오 자동 생성:**
- 사용자 선호 키워드 + 설정 기반 자동 생성
- Claude가 직접 시나리오 작성 (텔레그램 요청 시)
- 템플릿 시스템: 설정(장소/인물) + 전개(5단계) + 클라이맥스
- 다양성 보장: 최근 재생 시나리오 추적 → 겹치지 않게

**다중 보이스 지원:**
```python
VOICES = {
    "main": "ko-KR-SunHiNeural",      # 기본 여성
    "whisper": "ko-KR-SunHiNeural",    # 속삭임 (rate=-30%)
    "male": "ko-KR-InJoonNeural",      # 남성 (나레이션용)
    "en_f": "en-US-AvaNeural",         # 영어 여성
}
# 시나리오에서 @voice:whisper 태그로 전환
```

**구현 단계:**
1. Edge TTS 다중 보이스 구현 (`edge_tts_play.py` 확장)
2. 시나리오 5개 추가 작성
3. 시나리오 자동 생성 함수 (`generate_scenario.py`)
4. ElevenLabs 크레딧 리셋 후 (4/25) 고품질 전환
5. 재생 이력 추적 + 다양성 보장
6. 텔레그램에서 "시나리오 틀어줘" 명령 지원

**우선순위:** **중간 (Phase 2~4)** — Edge TTS 기반으로 먼저, ElevenLabs는 4/25 이후

---

### C3. 미디어 큐레이션

#### 현재 상태
- 이미지 소싱은 사용자 요청 시에만 실행
- 일일/주간 자동 큐레이션 없음
- 새 크리에이터 발굴은 수동

#### 문제점
1. 매번 수동 요청 필요 — "야사 보내줘"
2. 시간대별 최적화 없음 (심야에 집중되는 경향)
3. 다양성 부족 — 같은 카테고리 반복

#### 해결안: 자동 큐레이션 시스템

**Daily Best Picks:**
- 매일 정해진 시간(사용자 설정, 기본 22:00)에 자동 전송
- 카테고리 로테이션: 매일 다른 조합
  - 월: favorite, 화: duo, 수: pretty, 목: asian, 금: amateur, 토: celeb, 일: random mix
- 장당 5~8장 (폭주 방지)
- 취향 프로필 반영

**New Creator Discovery:**
- 주 1회 (일요일): "이번 주 발견" 전송
- 좋아하는 서브의 Top 3 새 포스터
- RedGifs trending에서 취향 매칭
- 크리에이터 프로필 링크 포함

**품질 게이트:**
- 썸네일 자동 제거 (100KB 미만)
- 저해상도 제거 (800x600 미만)
- 이미 전송한 것 제거 (sent_urls.json)
- 광고성 이미지 필터 (텍스트 오버레이 감지)

**구현 단계:**
1. `daily_curator.py` — 일일 자동 소싱 + 전송
2. 카테고리 로테이션 스케줄
3. 품질 게이트 통합
4. 크론 등록 (매일 22:00)
5. 주간 크리에이터 발견 리포트

**우선순위:** **낮음 (Phase 4)** — C1 이미지 소싱 Pro가 먼저

---

## D. 앱 코드 품질

### D1. Flutter Analyze Zero

#### 현재 상태
- `flutter analyze` 경고 22개 → **0개로 수정 완료** (커밋 6e871f7)
- 남은 것: deprecated API 사용 info 6개 (deprecated_member_use_from_same_package)
- pre-commit hook 미설정

#### 문제점
1. 새 코드 작성 시 경고 재발 가능
2. deprecated API 교체 안 하면 Flutter 업그레이드 시 빌드 실패 위험
3. 자동 체크 없음

#### 해결안: Analyze Zero 유지 + Pre-commit Hook

**Pre-commit Hook:**
```bash
#!/bin/bash
# .git/hooks/pre-commit
echo "Running flutter analyze..."
cd /c/dev/CHSTUDIO
result=$(flutter analyze --no-pub 2>&1)
if echo "$result" | grep -q "error •\|warning •"; then
    echo "BLOCKED: flutter analyze errors/warnings found"
    echo "$result" | grep "error •\|warning •"
    exit 1
fi
echo "flutter analyze passed"
```

**Deprecated API 교체 계획:**
- `withOpacity()` → `Color.fromRGBO()` 또는 `colorScheme` 활용
- 다음 Flutter stable 업그레이드 전에 교체 완료

**구현 단계:**
1. pre-commit hook 설치 (즉시)
2. deprecated API 목록 정리 (6개)
3. 교체 코드 작성 + 테스트
4. Flutter 버전 업그레이드 시 검증

**우선순위:** **완료 + 유지** — hook 설치만 남음

---

### D2. 서비스 레이어 정리

#### 현재 상태
- ObjectBox 마이그레이션 완료 (Hive → ObjectBox, 커밋 c078e85)
- Singleton 패턴 서비스: FirebaseService, TodoService, PlanService, FocusService 등
- 3-Layer Cache: LocalCache → Firestore SDK cache → Server
- Stream + FutureBuilder 혼용 → 무한 루프 위험 패턴 존재

#### 문제점
1. 죽은 코드 경로 존재 — Hive 잔재, 구 라이브러리 참조
2. 에러 핸들링 비일관 — 일부 서비스는 try-catch, 일부는 `.onError()`
3. Firestore 타임아웃 다수 발생 (네트워크 불안정 시)
4. `_load()` 패턴이 서비스마다 다름

#### 해결안: 서비스 레이어 표준화

**Phase 1 — 죽은 코드 제거:**
- Hive import/참조 전부 제거
- 사용 안 하는 서비스 메서드 제거
- `flutter analyze` + IDE unused 체크

**Phase 2 — 에러 핸들링 통일:**
```dart
// 표준 패턴
Future<T?> safeFirestoreOp<T>(Future<T> Function() op, {
  Duration timeout = const Duration(seconds: 8),
  T? fallback,
}) async {
  try {
    return await op().timeout(timeout);
  } on TimeoutException {
    debugPrint('[Firestore] timeout');
    return fallback;
  } catch (e) {
    debugPrint('[Firestore] error: $e');
    return fallback;
  }
}
```

**Phase 3 — `_load()` 패턴 통일:**
- 모든 서비스: `_isLoading` guard + `Completer` dedup + 전체 timeout
- 표준 베이스 클래스 또는 mixin 도입 검토

**구현 단계:**
1. Hive 잔재 코드 검색 + 제거
2. 미사용 메서드/변수 정리 (IDE 기반)
3. `safeFirestoreOp` 유틸 함수 작성
4. 각 서비스에 에러 핸들링 통일 적용
5. `_load()` 패턴 표준화

**우선순위:** **낮음 (Phase 4)** — 기능에 영향 없는 리팩토링

---

### D3. UI 다듬기

#### 현재 상태
- Home Dashboard v2: STATUS → TODAY → LOG 그룹핑
- Focus Screen: v2 리팩토링 완료 (거치대/서브타이머 제거, 일시정지 추가)
- Calendar: history/{month} 3단 fallback
- Order: 단일 커맨드 센터 (v6)

#### 문제점
1. Home 위젯 간 시각적 일관성 부족 (일부 카드형, 일부 리스트형)
2. Focus 화면 post-v2 미세 조정 필요
3. Calendar 대량 데이터 로드 시 성능 저하
4. 적록색약 대응 미흡 — 빨강/초록 구분에 의존하는 UI 요소

#### 해결안: UI 다듬기 로드맵

**Home Dashboard:**
- 위젯 카드 스타일 통일 (BotanicalTheme 기반)
- 로딩 상태 스켈레톤 UI 추가
- 반응형: 작은 화면에서 레이아웃 깨지는 부분 수정

**Focus Screen:**
- 타이머 애니메이션 미세 조정
- 세션 종료 후 요약 카드 개선
- 과목별 색상 커스텀 지원

**Calendar Performance:**
- 월별 데이터 lazy loading (현재 월 + 앞뒤 1개월만)
- 캐시 활용 강화 (이미 로드한 월은 재요청 안 함)
- 달력 셀 위젯 최적화 (`const` 활용)

**적록색약 대응:**
- 빨강/초록 → 파랑/주황 대체 팔레트 옵션
- 색상만으로 정보 전달하지 않기 (아이콘/패턴 병용)
- BotanicalTheme에 색약 모드 추가

**구현 단계:**
1. 위젯 카드 스타일 통일 (BotanicalTheme)
2. Calendar lazy loading 구현
3. 적록색약 팔레트 옵션 추가
4. Focus 후처리 UI 개선
5. 전체 스크린 반응형 테스트

**우선순위:** **낮음 (Phase 4)** — 기능 완성 후 다듬기

---

## 실행 타임라인

### Phase 1: 긴급 (2026-04-01, 완료)
| 항목 | 상태 | 비고 |
|---|---|---|
| A2 에이전트 관리 | **완료** | image_fetcher `--limit` 추가, CLAUDE.md 규칙 추가 |
| C1 이미지 소싱 `--limit` | **완료** | 폭주 재발 방지 |
| D1 Flutter Analyze Zero | **완료** | 22개 → 0개 (6e871f7) |

### Phase 2: 이번 주 (04/01 ~ 04/07)
| 항목 | 예상 소요 | 의존성 |
|---|---|---|
| A1 텔레그램 Watchdog | 2~3시간 | 없음 |
| A3 세션 핸드오프 Level 1~2 | 1~2시간 | 없음 |
| B1 일일 리듬 AI (기본) | 2~3시간 | battery_manager.py |
| B4 자극 관리 (기본) | B1과 동시 | B1 |
| C2 TTS 시나리오 5개 추가 | 1시간 | 없음 |
| D1 pre-commit hook | 10분 | 없음 |

### Phase 3: 다음 주 (04/07 ~ 04/14)
| 항목 | 예상 소요 | 의존성 |
|---|---|---|
| B3 인생 발굴 - Timeline 파서 | 3~4시간 | timeline_data.json |
| B3 사진 EXIF 파서 | 2시간 | 사진 폴더 접근 |
| A5 Discord 백업 채널 | 2시간 | 없음 |
| A4 MCP Fallback 테이블 | 1시간 | 없음 |
| C1 이미지 품질 필터 | 1~2시간 | 없음 |
| C2 Edge TTS 다중 보이스 | 1시간 | 없음 |

### Phase 4: 지속 (04/14~)
| 항목 | 예상 소요 | 비고 |
|---|---|---|
| B2 공시 학습 보조 | 지속적 | 자료해석 문제 DB 구축부터 |
| C1 취향 학습 시스템 | 2~3시간 | taste_profile.json |
| C2 ElevenLabs 전환 (4/25~) | 1시간 | 크레딧 리셋 대기 |
| C3 일일 자동 큐레이션 | 2시간 | C1 완성 후 |
| D2 서비스 레이어 정리 | 4~5시간 | 점진적 |
| D3 UI 다듬기 | 지속적 | 점진적 |
| A3 세션 핸드오프 Level 3 | 2시간 | Level 1~2 완료 후 |
| A5 Fakechat 설정 | 1시간 | Discord 이후 |

### 마일스톤 체크포인트

| 날짜 | 목표 |
|---|---|
| 04/03 | A1 Watchdog 실행 + B1 일일 리듬 기본 작동 |
| 04/07 | Phase 2 전체 완료 + 1주일 리듬 데이터 수집 |
| 04/14 | Phase 3 완료 + 인생 타임라인 초안 |
| 04/25 | ElevenLabs 리셋 + TTS 엔진 전환 |
| 04/30 | 전체 시스템 안정화 + Phase 4 진행 중 |

---

## 파일 구조 (예상)

```
C:\dev\CHSTUDIO\
├── UPGRADE_PLAN.md              # 이 문서
├── battery_manager.py           # 배터리 + IoT + mmWave (기존)
├── telegram_watchdog.py         # [신규] A1 텔레그램 안정성
├── agent_guard.py               # [신규] A2 에이전트 관리
├── session_resume.py            # [신규] A3 세션 자동 복원
├── daily_rhythm.py              # [신규] B1 일일 리듬 (또는 battery_manager 확장)
├── life_timeline.py             # [신규] B3 인생 발굴
├── image_fetcher.py             # C1 이미지 소싱 (기존, 확장)
├── daily_curator.py             # [신규] C3 미디어 큐레이션
├── edge_tts_play.py             # C2 TTS 시나리오 (기존, 확장)
├── generate_scenario.py         # [신규] C2 시나리오 자동 생성
├── tts_say.py                   # TTS 단발 (기존)
├── taste_profile.json           # [신규] C1 취향 프로필
├── scenarios/                   # C2 시나리오 풀 (확장)
├── .agent_log.json              # [신규] A2 에이전트 실행 이력
├── .telegram_buffer.json        # [신규] A1 미수신 메시지 버퍼
└── .session_checkpoint.json     # [신규] A3 자동 체크포인트
```

---

## 핵심 원칙

1. **안정성 우선** — 새 기능보다 기존 시스템이 안 끊기는 게 먼저
2. **자동화 최대** — 사용자 개입 최소화, 감지 → 판단 → 실행 자동
3. **제한 내장** — 모든 자동화에 상한선, 폭주 방지
4. **점진적 구현** — 한 번에 다 하지 않고, Phase별로 안정화 후 다음
5. **데이터 기반** — 감/직관이 아니라 실제 데이터로 판단
6. **사용자 존중** — 강압 금지, 알림은 정보 전달, 결정은 사용자

---

> 이 문서는 실행하면서 계속 업데이트한다. 각 Phase 완료 시 상태 갱신.
> 마지막 업데이트: 2026-04-01

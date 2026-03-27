# TTS 시나리오 라이브러리

## 사용법
```bash
python erotic_tts.py scenarios/파일명.txt
python erotic_tts.py scenarios/파일명.txt --speed 0.9 --pause 1.5
```

## 시나리오 목록

### 기본
| 파일 | 설정 | 음성 | 강도 |
|------|------|------|------|
| default.txt | 3P (두 여자) | Hyein + Yura | ★★★★ |
| late_night.txt | 심야 | - | ★★★ |

### 설정별
| 파일 | 설정 | 음성 | 강도 |
|------|------|------|------|
| sensual_massage.txt | 마사지 | Selly | ★★ |
| office_affair.txt | 사무실 3P | Jennie + Minzy | ★★★★ |
| solo_shower.txt | 샤워 | Hyein | ★★★ |
| intense_domination.txt | S&M | Jini | ★★★★★ |
| forbidden_teacher.txt | 과외 선생 | Han | ★★★★ |
| midnight_call.txt | 폰섹스 | Yura | ★★★ |
| gym_encounter.txt | 헬스장 | Minzy | ★★★★ |

### 소설 (치유 로맨스 시리즈)
| 파일 | 장 | 설정 | 강도 |
|------|-----|------|------|
| novel_first_night.txt | 단편 | 첫날밤 | ★★★ |
| novel_healing_romance.txt | 1편 | 카페→첫날밤 | ★★★ |
| novel_healing_ch2.txt | 2편 | 도서관→시험기간 | ★★★ |
| novel_healing_ch3.txt | 3편 | 바다 여행 | ★★★★ |
| novel_healing_ch4.txt | 4편 | 동거 일상 | ★★★ |

### 테스트
| 파일 | 용도 |
|------|------|
| tag_test.txt | v3 오디오 태그 테스트 |
| sample_test.txt | 기본 테스트 |

## 음성 목록
| 이름 | 코드 | 특징 |
|------|------|------|
| Hyein | hyein | 기본, 여친형 |
| Yura | yura | 적극적 |
| Selly | selly | 나레이션, 감성적 |
| Jennie | jennie | 도도한, 상사형 |
| Minzy | minzy | 귀여운, 후배형 |
| Jini | jini | S, 명령적 |
| Han | han | 성숙한, 선생형 |

## 시나리오 작성법
```
# 제목 — 설명
@음성이름: 대사 텍스트
@음성이름: @speed:0.8 느린 대사
@음성이름: [whispers] 속삭임 [moans] 신음 [gasp] 헉 [screams] 비명 [crying] 울음
```

### 속도 태그
- `@speed:0.7` — 매우 느림 (빌드업)
- `@speed:0.8` — 느림 (감성)
- `@speed:1.0` — 기본
- `@speed:1.2` — 빠름 (클라이맥스)
- `@speed:1.3` — 매우 빠름 (절정)

### v3 오디오 태그
[whispers] [moans] [gasp] [screams] [crying] [laughs] [sighs]
[rushed] [slows down] [drawn out] [inhales deeply] [exhales sharply]
[frustrated] [angry] [gulps] [stammers] [pause] [long pause]
CAPITALIZATION — 강조

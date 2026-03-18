## Codemagic 원격 빌드

릴리즈 APK 빌드 시 로컬 빌드(`flutter build apk --release`) 대신 Codemagic 원격 빌드를 사용한다.

### 빌드 방법
1. 변경사항을 `git add`, `git commit`, `git push`한다.
2. 프로젝트 루트의 `codemagic_build.sh`를 실행한다: `bash codemagic_build.sh`
3. 스크립트가 자동으로 빌드 트리거 → 완료 대기 → APK 다운로드 → `adb install`까지 처리한다.
4. 빌드는 약 8~10분 소요된다. 30초 간격으로 상태를 폴링하므로 별도 작업 불필요.
5. **Codemagic 빌드 실패 시(무료 분수 소진, API 오류 등) 자동으로 로컬 빌드(`flutter build apk --release`)로 폴백한다.**

### 빌드 시간 비교
- 첫 빌드 시 로컬(`flutter build apk --release`)과 Codemagic 빌드를 모두 실행하여 소요 시간을 비교한다.
- 완료 후 텔레그램으로 결과를 보고한다.

### 텔레그램 보고
빌드 완료 시 Hermes Bot 텔레그램으로 다음 형식으로 보고한다:

```
📦 빌드 완료!
⏱ Codemagic: X분 Y초
⏱ 로컬: X분 Y초
🏆 승자: [Codemagic/로컬] (X분 차이)
✅ 설치 완료
```

### 주의사항
- `flutter build apk --release`를 로컬에서 직접 실행하지 않는다. (비교 테스트 제외)
- 빌드 전 반드시 `git push`가 선행되어야 한다.
- 빌드 실패 시 Codemagic 웹(https://codemagic.io)에서 로그를 확인한다.

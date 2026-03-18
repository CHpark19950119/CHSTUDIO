#!/bin/bash
# Codemagic 빌드 후 자동 설치 스크립트
# Claude Code에서 실행: bash codemagic_build.sh

API_TOKEN="gRqUxvh1o9db8V5sk6I-2fIVCvfD0oeJSczJ1QFVMe4"
APP_ID="69ba7db3a9fa7faef6860042"
WORKFLOW_ID="android-release"
BRANCH="master"

echo "=== Codemagic 빌드 시작 ==="

# 1. git push (이미 push된 상태면 스킵)
git push 2>/dev/null

# 2. 빌드 트리거
BUILD_RESPONSE=$(curl -s -X POST \
  "https://api.codemagic.io/builds" \
  -H "Content-Type: application/json" \
  -H "x-auth-token: $API_TOKEN" \
  -d "{
    \"appId\": \"$APP_ID\",
    \"workflowId\": \"$WORKFLOW_ID\",
    \"branch\": \"$BRANCH\"
  }")

BUILD_ID=$(echo "$BUILD_RESPONSE" | python -c "import sys,json; print(json.load(sys.stdin)['buildId'])" 2>/dev/null)

if [ -z "$BUILD_ID" ]; then
  echo "Codemagic 빌드 트리거 실패 — 로컬 빌드로 전환"
  flutter build apk --release
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  echo "=== 로컬 빌드 완료! ==="
  exit 0
fi

echo "빌드 ID: $BUILD_ID"
echo "빌드 진행 중... (약 8~10분 소요)"

# 3. 빌드 완료 대기
while true; do
  sleep 30
  STATUS_RESPONSE=$(curl -s \
    "https://api.codemagic.io/builds/$BUILD_ID" \
    -H "x-auth-token: $API_TOKEN")
  
  STATUS=$(echo "$STATUS_RESPONSE" | python -c "import sys,json; print(json.load(sys.stdin)['build']['status'])" 2>/dev/null)
  
  echo "상태: $STATUS"
  
  if [ "$STATUS" = "finished" ]; then
    echo "빌드 성공!"
    break
  elif [ "$STATUS" = "failed" ] || [ "$STATUS" = "canceled" ]; then
    echo "Codemagic 빌드 실패 — 로컬 빌드로 전환"
    flutter build apk --release
    adb install -r build/app/outputs/flutter-apk/app-release.apk
    echo "=== 로컬 빌드 완료! ==="
    exit 0
  fi
done

# 4. APK 다운로드 URL 추출
APK_URL=$(echo "$STATUS_RESPONSE" | python -c "
import sys, json
data = json.load(sys.stdin)
artifacts = data['build'].get('artefacts', [])
for a in artifacts:
    if a['name'].endswith('.apk'):
        print(a['url'])
        break
" 2>/dev/null)

if [ -z "$APK_URL" ]; then
  echo "APK URL을 찾을 수 없음"
  exit 1
fi

echo "APK 다운로드 중..."
curl -s -L -o app-release.apk "$APK_URL"

# 5. adb install
echo "APK 설치 중..."
adb install -r app-release.apk

echo "=== 완료! ==="
rm -f app-release.apk

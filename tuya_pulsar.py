"""Tuya Pulsar — 문센서 이벤트 실시간 수신
Tuya Message Service (WebSocket) — dp_report 이벤트를 push로 받음.
쿼터 소모 최소: 폴링 0, 이벤트 수신만.

사용법:
  python tuya_pulsar.py
"""
import sys
import json
import time
import hashlib
import hmac
import threading
import websocket
import requests

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# Tuya credentials (새 프로젝트)
ACCESS_ID = 'dn95ku3nuhk9n98fvmsa'
ACCESS_SECRET = 'bd10042419294178b364589e34d6314e'
REGION = 'us'  # Western America

# Pulsar WebSocket URL
WS_URL = f'wss://mqe.tuyaus.com:8285/ws/v2/consumer/persistent/out/{ACCESS_ID}/out/{ACCESS_ID}-sub/sub-001'

# CF URL for Firestore updates
CF_URL = "https://us-central1-cheonhong-studio.cloudfunctions.net/checkDoorManual"

# Device IDs
DOOR_SENSOR_ID = 'ebe81df2474265f26ec7p5'

def tuya_sign(t):
    """Tuya HMAC-SHA256 서명"""
    msg = ACCESS_ID + str(t)
    return hmac.new(ACCESS_SECRET.encode(), msg.encode(), hashlib.sha256).hexdigest()

def get_token():
    """Tuya API 토큰 획득"""
    t = str(int(time.time() * 1000))
    content_hash = hashlib.sha256(b'').hexdigest()
    path = '/v1.0/token?grant_type=1'
    str_to_sign = f'GET\n{content_hash}\n\n{path}'
    msg = ACCESS_ID + t + str_to_sign
    sign = hmac.new(ACCESS_SECRET.encode(), msg.encode(), hashlib.sha256).hexdigest().upper()

    headers = {
        'client_id': ACCESS_ID,
        'sign': sign,
        't': t,
        'sign_method': 'HMAC-SHA256',
    }
    r = requests.get(f'https://openapi.tuyaus.com{path}', headers=headers, timeout=10)
    data = r.json()
    if data.get('success'):
        return data['result']['access_token']
    return None

def on_message(ws, message):
    """Pulsar 메시지 수신 핸들러"""
    try:
        data = json.loads(message)
        print(f'[Pulsar] 메시지: {json.dumps(data, indent=2)[:300]}')

        # dp_report 이벤트 처리
        if 'data' in data:
            payload = data.get('data', {})
            device_id = payload.get('devId', '')

            if device_id == DOOR_SENSOR_ID:
                # 문센서 이벤트
                status = payload.get('status', [])
                for s in status:
                    code = s.get('code', '')
                    value = s.get('value', '')
                    print(f'[Door] {code} = {value}')

                    if code == 'doorcontact_state':
                        is_open = value
                        print(f'[Door] {"열림" if is_open else "닫힘"}')
                        # Firestore에 기록
                        try:
                            requests.get(
                                f'{CF_URL}?q=config&key=door_state&value={"open" if is_open else "closed"}',
                                timeout=10
                            )
                        except:
                            pass
    except Exception as e:
        print(f'[Pulsar] 파싱 에러: {e}')

def on_error(ws, error):
    print(f'[Pulsar] 에러: {error}')

def on_close(ws, close_status_code, close_msg):
    print(f'[Pulsar] 연결 종료: {close_status_code} {close_msg}')

def on_open(ws):
    print('[Pulsar] 연결 성공! 이벤트 대기 중...')

def connect():
    """Pulsar WebSocket 연결"""
    token = get_token()
    if not token:
        print('[Pulsar] 토큰 획득 실패')
        return

    t = str(int(time.time() * 1000))
    sign = tuya_sign(int(t))

    headers = {
        'Connection': 'Upgrade',
        'username': ACCESS_ID,
        'password': sign,
    }

    ws = websocket.WebSocketApp(
        WS_URL,
        header=headers,
        on_open=on_open,
        on_message=on_message,
        on_error=on_error,
        on_close=on_close,
    )

    # 재연결 루프
    while True:
        try:
            ws.run_forever(ping_interval=30)
        except Exception as e:
            print(f'[Pulsar] 연결 실패: {e}')
        print('[Pulsar] 5초 후 재연결...')
        time.sleep(5)

if __name__ == '__main__':
    print('Tuya Pulsar — 문센서 이벤트 수신 시작')
    connect()

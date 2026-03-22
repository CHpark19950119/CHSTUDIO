"""
배터리 매니저 — 외출 시에만 20~80% 유지
5분마다 체크: mmWave none(방 비어있음) → 배터리 관리
집에 있으면 항상 충전 ON
"""
import time
import psutil
import requests

CF_URL = "https://us-central1-cheonhong-studio.cloudfunctions.net/checkDoorManual"
LOW = 20
HIGH = 80
INTERVAL = 300  # 5분

plug_on = None

def set_plug(on: bool):
    global plug_on
    if plug_on == on:
        return
    try:
        r = requests.get(f"{CF_URL}?q=light&on={'true' if on else 'false'}&device=20a", timeout=15)
        plug_on = on
        print(f"[Plug] {'ON' if on else 'OFF'}")
    except Exception as e:
        print(f"[Plug] error: {e}")

def is_home():
    """mmWave 센서로 재실 확인"""
    try:
        r = requests.get(f"{CF_URL}?q=date&doc=iot", timeout=15)
        data = r.json()
        state = data.get("presence", {}).get("state", "none")
        return state != "none"
    except:
        return True  # 확인 불가 시 집에 있다고 간주 (충전 유지)

def check():
    b = psutil.sensors_battery()
    if b is None:
        return

    pct = b.percent
    home = is_home()

    if home:
        # 집에 있으면 항상 충전
        if not plug_on:
            print(f"[Battery] {pct}% — 재실, 충전 ON")
            set_plug(True)
        return

    # 외출 중 → 배터리 관리
    if pct >= HIGH:
        print(f"[Battery] {pct}% >= {HIGH}% — 외출 중, 충전 OFF")
        set_plug(False)
    elif pct <= LOW:
        print(f"[Battery] {pct}% <= {LOW}% — 외출 중, 충전 ON")
        set_plug(True)
    else:
        state = "충전중" if b.power_plugged else "방전중"
        print(f"[Battery] {pct}% ({state}) — 외출 중, 유지")

if __name__ == "__main__":
    print(f"배터리 매니저 시작 (외출 시 {LOW}~{HIGH}%, {INTERVAL}초 간격)")
    plug_on = True  # 초기: 충전 중
    try:
        while True:
            check()
            time.sleep(INTERVAL)
    except KeyboardInterrupt:
        print("\n종료. 충전 ON 복원.")
        set_plug(True)

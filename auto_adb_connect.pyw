"""
ADB 자동 재연결 스크립트
Tailscale 설정 후 시작 프로그램에 등록하면 자동으로 폰 연결 유지.
.pyw 확장자로 콘솔 창 없이 실행됨.

사용법:
  1. PHONE_IP를 폰의 Tailscale IP로 변경
  2. python auto_adb_connect.pyw (또는 더블클릭)
"""

import subprocess
import time
import logging
from pathlib import Path

PHONE_IP = "100.x.x.x"  # TODO: Tailscale 설정 후 폰 IP로 변경
PORT = 5555
CHECK_INTERVAL = 60  # 초

LOG_FILE = Path(__file__).parent / "adb_connect.log"
logging.basicConfig(
    filename=str(LOG_FILE),
    level=logging.INFO,
    format="%(asctime)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


def is_connected():
    """ADB 연결 상태 확인"""
    try:
        result = subprocess.run(
            ["adb", "devices"],
            capture_output=True, text=True, timeout=10
        )
        return f"{PHONE_IP}:{PORT}" in result.stdout
    except Exception:
        return False


def connect():
    """ADB 연결 시도"""
    try:
        result = subprocess.run(
            ["adb", "connect", f"{PHONE_IP}:{PORT}"],
            capture_output=True, text=True, timeout=15
        )
        return "connected" in result.stdout.lower()
    except Exception as e:
        logging.error(f"Connect failed: {e}")
        return False


def main():
    logging.info("ADB auto-connect started")

    while True:
        if not is_connected():
            logging.info(f"Disconnected. Reconnecting to {PHONE_IP}:{PORT}...")
            if connect():
                logging.info("Reconnected successfully")
            else:
                logging.warning("Reconnect failed, retrying next cycle")
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()

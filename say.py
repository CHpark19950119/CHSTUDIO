"""즉시 TTS — 텍스트를 받아서 바로 음성으로 재생"""
import asyncio, ctypes, os, sys, tempfile, time
import edge_tts

VOICE = "ko-KR-SunHiNeural"
RATE = "+30%"
PITCH = "+5Hz"
TTS_PATH = os.path.join(tempfile.gettempdir(), "say_tts.mp3")
winmm = ctypes.windll.winmm

def mci(cmd):
    buf = ctypes.create_unicode_buffer(256)
    winmm.mciSendStringW(cmd, buf, 255, 0)
    return buf.value

def play(path):
    mci("close say_audio")
    mci(f'open "{path}" type mpegvideo alias say_audio')
    mci("play say_audio")
    length = 10000
    try: length = int(mci("status say_audio length"))
    except: pass
    elapsed = 0
    while elapsed < length + 500:
        time.sleep(0.1); elapsed += 100
        try:
            if int(mci("status say_audio position")) >= length: break
        except: break
    mci("close say_audio")

async def tts(text):
    c = edge_tts.Communicate(text, VOICE, rate=RATE, pitch=PITCH)
    await c.save(TTS_PATH)

def connect_pl7():
    """PL7 블루투스 스피커 연결 시도"""
    try:
        import subprocess
        # btcom으로 오디오 디바이스 연결 (PL7)
        subprocess.run(
            ["powershell", "-Command",
             "Get-PnpDevice -Class AudioEndpoint | Where-Object {$_.FriendlyName -like '*PL7*'} | Enable-PnpDevice -Confirm:$false"],
            timeout=10, capture_output=True
        )
    except:
        pass  # PL7 없으면 기본 스피커로 재생


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="즉시 TTS 재생")
    parser.add_argument("text", nargs="*", help="읽을 텍스트")
    parser.add_argument("--pl7", action="store_true", help="PL7 스피커 연결")
    parser.add_argument("--repeat", type=int, default=1, help="반복 횟수")
    args = parser.parse_args()

    text = " ".join(args.text) if args.text else sys.stdin.read().strip()
    if not text:
        sys.exit(0)

    if args.pl7:
        connect_pl7()

    asyncio.run(tts(text))
    for i in range(args.repeat):
        play(TTS_PATH)
        if i < args.repeat - 1:
            time.sleep(1)

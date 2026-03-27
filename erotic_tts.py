"""Erotic TTS Playlist Player — ElevenLabs v3 Multi-Voice
시나리오 파일을 읽어서 순차 재생. Ctrl+C로 종료.
음성 전환: 대사 앞에 @음성이름: 붙이면 해당 음성으로 전환.

사용법:
  python erotic_tts.py [시나리오파일]
  기본: scenarios/default.txt
"""
import ctypes, os, sys, tempfile, time

from elevenlabs.client import ElevenLabs
from elevenlabs import VoiceSettings

API_KEY = "21acbeee4b058cbd4f7ca671d5706f4940af8870530be294275538f35412a9c1"
MODEL = "eleven_v3"
SETTINGS = VoiceSettings(
    stability=0.45,
    similarity_boost=0.80,
    style=0.10,
    use_speaker_boost=True,
)
PAUSE_BETWEEN = 1.0
SPEED = 1.0  # 0.7~1.3 범위, 기본 1.0 (--speed 인자로 조절)
TTS_DIR = os.path.join(tempfile.gettempdir(), "erotic_tts")
os.makedirs(TTS_DIR, exist_ok=True)

VOICES = {
    "minzy": "QaVYJESdOtUP82UYCoA1",
    "jennie": "z6Kj0hecH20CdetSElRT",
    "selly": "ETPP7D0aZVdEj12Aa7ho",
    "hyein": "6Vgh4FaCc0SCcWPwcyXa",
    "jini": "0oqpliV6dVSr9XomngOW",
    "yura": "F7wT70V3u09d2rY9pNa6",
    "han": "8jHHF8rMqMlg8if2mOUe",
}
DEFAULT_VOICE = "hyein"

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

client = ElevenLabs(api_key=API_KEY)
winmm = ctypes.windll.winmm

def mci(cmd):
    buf = ctypes.create_unicode_buffer(256)
    winmm.mciSendStringW(cmd, buf, 255, 0)
    return buf.value

def play_mp3(path):
    mci("close ettsplay")
    mci(f'open "{path}" type mpegvideo alias ettsplay')
    mci("play ettsplay")
    length = 10000
    try: length = int(mci("status ettsplay length"))
    except: pass
    elapsed = 0
    while elapsed < length + 500:
        time.sleep(0.1); elapsed += 100
        try:
            if int(mci("status ettsplay position")) >= length: break
        except: break
    mci("close ettsplay")

def parse_line(line, current_voice):
    """@voice: text 형식 파싱. 없으면 현재 음성 유지."""
    if line.startswith("@"):
        colon = line.find(":")
        if colon > 0:
            voice_name = line[1:colon].strip().lower()
            text = line[colon+1:].strip()
            if voice_name in VOICES:
                return voice_name, text
    return current_voice, line

def parse_speed_tag(text):
    """@speed:1.2 태그 파싱. 없으면 글로벌 SPEED 사용."""
    import re
    m = re.match(r'@speed:([\d.]+)\s*(.*)', text, re.DOTALL)
    if m:
        return float(m.group(1)), m.group(2).strip()
    return None, text


def generate_tts(text, voice_id, output_path, speed=None):
    spd = speed or SPEED
    kwargs = dict(
        voice_id=voice_id,
        text=text,
        model_id=MODEL,
        voice_settings=SETTINGS,
    )
    if spd != 1.0:
        kwargs["speed"] = spd
    audio = client.text_to_speech.convert(**kwargs)
    with open(output_path, "wb") as f:
        for chunk in audio:
            f.write(chunk)

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Erotic TTS Player")
    parser.add_argument("scenario", nargs="?", default=os.path.join(
        os.path.dirname(__file__), "scenarios", "default.txt"
    ), help="시나리오 파일 경로")
    parser.add_argument("--speed", type=float, default=1.0, help="재생 속도 (0.7~1.3)")
    parser.add_argument("--pause", type=float, default=1.0, help="대사 간 간격 (초)")
    parser.add_argument("--voice", default=None, help="기본 음성 오버라이드")
    args = parser.parse_args()

    global SPEED, PAUSE_BETWEEN, DEFAULT_VOICE
    SPEED = args.speed
    PAUSE_BETWEEN = args.pause
    if args.voice and args.voice.lower() in VOICES:
        DEFAULT_VOICE = args.voice.lower()

    scenario_file = args.scenario

    if not os.path.exists(scenario_file):
        print(f"  시나리오 파일 없음: {scenario_file}")
        sys.exit(1)

    with open(scenario_file, "r", encoding="utf-8") as f:
        raw_lines = [l.strip() for l in f if l.strip() and not l.startswith("#")]

    if not raw_lines:
        print("  대사 없음")
        sys.exit(1)

    # 파싱: 음성 + 대사
    current_voice = DEFAULT_VOICE
    entries = []
    for line in raw_lines:
        current_voice, text = parse_line(line, current_voice)
        line_speed, text = parse_speed_tag(text)
        entries.append((current_voice, text, line_speed))

    voices_used = set(v for v, _, _ in entries)
    print(f"  시나리오: {scenario_file}")
    print(f"  대사 {len(entries)}개 | 음성: {', '.join(voices_used)} | 모델: v3 | 속도: {SPEED}")

    # 사전 생성
    paths = []
    print(f"  사전 생성 중...")
    for i, (voice, text, line_speed) in enumerate(entries):
        path = os.path.join(TTS_DIR, f"line_{i:03d}.mp3")
        generate_tts(text, VOICES[voice], path, speed=line_speed)
        paths.append(path)
        sys.stdout.write(f"\r  {i+1}/{len(entries)} 완료")
        sys.stdout.flush()
    print(f"\n  사전 생성 완료")

    print("=" * 40)
    print("  재생 시작 (Ctrl+C로 종료)")
    print("=" * 40)

    try:
        for i, (path, (voice, text, _)) in enumerate(zip(paths, entries)):
            print(f"  [{i+1}/{len(entries)}] ({voice}) {text[:45]}...")
            play_mp3(path)
            if i < len(entries) - 1:
                time.sleep(PAUSE_BETWEEN)
    except KeyboardInterrupt:
        mci("close ettsplay")
        print("\n  종료")
        return

    print("\n  재생 끝")

if __name__ == "__main__":
    main()

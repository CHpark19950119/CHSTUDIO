"""
이미지/비디오 소싱 자동화 스크립트
사용법:
  python image_fetcher.py --category anal --count 6
  python image_fetcher.py --sub leahgotti --count 10 --period week
  python image_fetcher.py --video --keyword "anal perfect ass" --count 3
  python image_fetcher.py --user Papisanon --count 10
"""

import argparse
import json
import os
import sys
import urllib.request
import re
from pathlib import Path

TEMP_DIR = Path(os.environ.get("TEMP", "/tmp"))
SENT_LOG = Path.home() / ".claude" / "sent_urls.json"

SUBS = {
    "anal": ["assholegonewild", "anal", "buttplug"],
    "asian": ["paag", "juicyasians", "AsiansGoneWild", "rice_cakes"],
    "latin": ["latinas", "latinasgw", "LatinaCuties"],
    "middle_east": ["hijabixxx"],
    "general": ["RealGirls", "gonewild", "BustyPetite"],
    "amateur": ["Amateur", "CoupleGW"],
    "body": ["fitgirls", "thickfit", "BubbleButts"],
}

HEADERS = {"User-Agent": "Claude/1.0 (contact: test@test.com)"}


def load_sent():
    if SENT_LOG.exists():
        try:
            return set(json.loads(SENT_LOG.read_text()))
        except:
            return set()
    return set()


def save_sent(sent):
    SENT_LOG.parent.mkdir(parents=True, exist_ok=True)
    SENT_LOG.write_text(json.dumps(list(sent)[-5000:]))  # 최근 5000개만 유지


def fetch_reddit(sub, period="month", limit=50):
    """Reddit 서브레딧에서 이미지 URL 수집"""
    url = f"https://old.reddit.com/r/{sub}/top/.json?t={period}&limit={limit}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        data = json.loads(resp.read())
    except Exception as e:
        print(f"  r/{sub}: {e}", file=sys.stderr)
        return []

    results = []
    for post in data.get("data", {}).get("children", []):
        d = post["data"]
        img_url = d.get("url", "")
        if img_url.endswith((".jpg", ".jpeg", ".png")):
            results.append({
                "url": img_url,
                "title": d.get("title", ""),
                "score": d.get("score", 0),
                "author": d.get("author", ""),
                "sub": sub,
                "type": "image",
            })
    return results


def fetch_reddit_user(username, limit=50):
    """Reddit 유저의 전체 포스트에서 이미지 수집"""
    url = f"https://old.reddit.com/user/{username}/submitted/.json?sort=top&t=all&limit={limit}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        data = json.loads(resp.read())
    except Exception as e:
        print(f"  u/{username}: {e}", file=sys.stderr)
        return []

    results = []
    for post in data.get("data", {}).get("children", []):
        d = post["data"]
        img_url = d.get("url", "")
        if img_url.endswith((".jpg", ".jpeg", ".png")):
            results.append({
                "url": img_url,
                "title": d.get("title", ""),
                "score": d.get("score", 0),
                "author": username,
                "sub": d.get("subreddit", ""),
                "type": "image",
            })
    return results


def fetch_redgifs(query, count=10):
    """RedGifs에서 비디오 검색"""
    # 토큰 획득
    req = urllib.request.Request(
        "https://api.redgifs.com/v2/auth/temporary",
        headers={"User-Agent": "Mozilla/5.0"},
    )
    try:
        token = json.loads(urllib.request.urlopen(req, timeout=10).read())["token"]
    except Exception as e:
        print(f"  RedGifs token error: {e}", file=sys.stderr)
        return []

    # 검색
    search_url = (
        f"https://api.redgifs.com/v2/gifs/search"
        f"?search_text={urllib.parse.quote(query)}&order=top&count={count}"
    )
    req2 = urllib.request.Request(
        search_url,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Authorization": f"Bearer {token}",
        },
    )
    try:
        data = json.loads(urllib.request.urlopen(req2, timeout=15).read())
    except Exception as e:
        print(f"  RedGifs search error: {e}", file=sys.stderr)
        return []

    return [
        {
            "url": g["urls"].get("hd", ""),
            "views": g.get("views", 0),
            "duration": g.get("duration", 0),
            "type": "video",
        }
        for g in data.get("gifs", [])
        if g["urls"].get("hd", "")
    ]


def download(url, index=0):
    """URL을 로컬에 다운로드"""
    ext = url.split(".")[-1].split("?")[0][:4]
    if ext not in ("jpg", "jpeg", "png", "mp4", "gif"):
        ext = "jpg"
    filename = f"fetched_{index}.{ext}"
    filepath = TEMP_DIR / filename

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        urllib.request.urlretrieve(url, filepath)
        size = filepath.stat().st_size
        if size < 1000:  # 에러 페이지
            filepath.unlink()
            return None
        return str(filepath)
    except Exception as e:
        print(f"  Download failed: {url[:60]}... — {e}", file=sys.stderr)
        return None


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description="Image/Video Fetcher")
    parser.add_argument("--category", "-c", help="카테고리 (anal, asian, latin, middle_east, general, amateur, body)")
    parser.add_argument("--sub", "-s", help="특정 서브레딧")
    parser.add_argument("--user", "-u", help="특정 Reddit 유저")
    parser.add_argument("--keyword", "-k", help="RedGifs 검색 키워드")
    parser.add_argument("--video", "-v", action="store_true", help="비디오 모드 (RedGifs)")
    parser.add_argument("--count", "-n", type=int, default=6, help="가져올 개수 (기본 6)")
    parser.add_argument("--period", "-p", default="month", help="기간 (day/week/month/year/all)")
    parser.add_argument("--download", "-d", action="store_true", help="다운로드도 수행")
    parser.add_argument("--no-dedup", action="store_true", help="중복 체크 비활성화")
    args = parser.parse_args()

    sent = set() if args.no_dedup else load_sent()
    results = []

    if args.video or args.keyword:
        query = args.keyword or "trending"
        print(f"RedGifs 검색: {query}")
        results = fetch_redgifs(query, args.count)

    elif args.user:
        print(f"u/{args.user} 포스트 수집")
        results = fetch_reddit_user(args.user, limit=args.count * 2)

    elif args.sub:
        print(f"r/{args.sub} 수집")
        results = fetch_reddit(args.sub, args.period, limit=args.count * 2)

    elif args.category:
        subs = SUBS.get(args.category, [])
        if not subs:
            print(f"알 수 없는 카테고리: {args.category}")
            print(f"사용 가능: {', '.join(SUBS.keys())}")
            return
        print(f"카테고리 '{args.category}' — {len(subs)}개 서브레딧")
        for sub in subs:
            results.extend(fetch_reddit(sub, args.period, limit=30))
    else:
        parser.print_help()
        return

    # 중복 제거
    if not args.no_dedup:
        results = [r for r in results if r["url"] not in sent]

    # 점수순 정렬
    results.sort(key=lambda x: x.get("score", x.get("views", 0)), reverse=True)
    results = results[: args.count]

    print(f"\n총 {len(results)}개 결과:")
    for i, r in enumerate(results):
        url = r["url"]
        if r["type"] == "video":
            print(f"  [{i+1}] {r.get('views', 0)} views, {r.get('duration', 0):.0f}s — {url}")
        else:
            print(f"  [{i+1}] [{r.get('score', 0)}] r/{r.get('sub', '')} — {r.get('title', '')[:50]}")
            print(f"       {url}")

        if args.download:
            path = download(url, i)
            if path:
                print(f"       → {path}")

        # 기록
        sent.add(url)

    if not args.no_dedup:
        save_sent(sent)
    print(f"\n완료. 중복 추적: {len(sent)}개 URL 기록됨.")


if __name__ == "__main__":
    import urllib.parse
    main()

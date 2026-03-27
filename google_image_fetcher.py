"""이미지 검색 + 다운로드 + 텔레그램 전송
Yandex(1순위) + Bing(2순위) — curl-cffi TLS 핑거프린팅으로 봇 탐지 우회.
Selenium 불필요.

사용법:
  python google_image_fetcher.py "검색어" --count 3 --download
  python google_image_fetcher.py "검색어" --count 5 --send
  python google_image_fetcher.py "검색어" --count 3 --download --send
  python google_image_fetcher.py "검색어" --engine bing  # Bing 사용
  python google_image_fetcher.py "검색어" --page 2       # 3번째 페이지부터

의존성: pip install curl-cffi
"""
import sys
import os
import re
import json
import time
import hashlib
import argparse
import tempfile
import urllib.parse
import urllib.request

# Windows cp949 stdout 깨짐 방지
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SENT_URLS_PATH = os.path.join(SCRIPT_DIR, 'sent_urls.json')

# 텔레그램 봇
TG_TOKEN = '8514127849:AAF8_F7SBfm51SGHtp9X5lva7yexdnFyapo'
TG_CHAT_ID = '8724548311'

# Yandex/Bing 자체 도메인 — 검색 결과에서 제외
_EXCLUDED_DOMAINS = (
    'yandex.', 'yastatic.net', 'avatars.mds.', 'bing.com', 'microsoft.com',
    'gstatic.com', 'google.com', 'googleapis.com',
)


def load_sent_urls():
    """sent_urls.json에서 이미 전송한 URL 목록 로드"""
    if os.path.exists(SENT_URLS_PATH):
        try:
            with open(SENT_URLS_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    return set(data)
                return set()
        except (json.JSONDecodeError, IOError):
            return set()
    return set()


def save_sent_urls(urls_set):
    """sent_urls.json에 전송한 URL 목록 저장"""
    with open(SENT_URLS_PATH, 'w', encoding='utf-8') as f:
        json.dump(list(urls_set), f, ensure_ascii=False, indent=2)


def _is_excluded(url):
    """검색엔진 자체 리소스 URL인지 확인"""
    low = url.lower()
    return any(d in low for d in _EXCLUDED_DOMAINS)


# ─────────────────────────────────────────────
#  검색 엔진 (curl-cffi: Chrome TLS 핑거프린팅)
# ─────────────────────────────────────────────

def _fetch(session, url, max_retries=3):
    """CAPTCHA 감지 시 재시도하는 HTTP GET

    Returns:
        (response_text, is_ok) — CAPTCHA가 3회 반복되면 빈 문자열 반환
    """
    for attempt in range(max_retries):
        try:
            r = session.get(url, timeout=15)
        except Exception as e:
            print(f'  [!] HTTP 오류: {e}')
            return '', False

        if r.status_code != 200:
            print(f'  [!] HTTP {r.status_code}')
            return '', False

        # CAPTCHA 감지
        if 'captcha' in r.text.lower() or 'showcaptcha' in r.url.lower():
            wait = 2 * (attempt + 1)
            print(f'  [!] CAPTCHA 감지 (시도 {attempt + 1}/{max_retries}), {wait}초 대기...')
            time.sleep(wait)
            continue

        return r.text, True

    print('  [!] CAPTCHA 우회 실패')
    return '', False


def search_yandex(query, count=5, sent_urls=None, page=0):
    """Yandex 이미지 검색 — NSFW 필터링 없음, curl-cffi TLS 우회

    Args:
        query: 검색어
        count: 가져올 이미지 수
        sent_urls: 중복 방지용 이미 전송한 URL set
        page: 시작 페이지 번호 (0부터)

    Returns:
        list of image URL strings
    """
    from curl_cffi import requests as cffi_requests

    if sent_urls is None:
        sent_urls = set()

    session = cffi_requests.Session(impersonate='chrome')
    results = []
    collected = set()

    pages_needed = max(1, (count + 29) // 30)  # 페이지당 ~30개

    for p in range(page, page + pages_needed):
        if len(results) >= count:
            break

        params = {
            'text': query,
            'nomisspell': '1',
            'noreask': '1',
            'family': 'no',  # SafeSearch OFF
        }
        if p > 0:
            params['p'] = str(p)

        url = 'https://yandex.com/images/search?' + urllib.parse.urlencode(params)
        print(f'[Yandex] 페이지 {p} 요청...')

        text, ok = _fetch(session, url)
        if not ok:
            break

        # 1순위: origUrl (HTML entity encoded JSON — data-state 속성 내부)
        urls_found = re.findall(
            r'&quot;origUrl&quot;:&quot;(https?:[^&]+?)&quot;', text
        )
        # 2순위: origUrl (일반 JSON)
        if not urls_found:
            urls_found = re.findall(
                r'"origUrl"\s*:\s*"(https?://[^"]+)"', text
            )
        # 3순위: img_href (entity)
        if not urls_found:
            urls_found = re.findall(
                r'&quot;img_href&quot;:&quot;(https?:[^&]+?)&quot;', text
            )
        # 4순위: img_href (JSON)
        if not urls_found:
            urls_found = re.findall(
                r'"img_href"\s*:\s*"(https?://[^"]+)"', text
            )

        print(f'[Yandex] 페이지 {p}: {len(urls_found)}개 URL 발견')

        for u in urls_found:
            if len(results) >= count:
                break
            # HTML entity 디코딩
            u = u.replace('&amp;', '&')
            if u in collected or u in sent_urls:
                continue
            if _is_excluded(u):
                continue
            collected.add(u)
            results.append(u)

        time.sleep(1)  # rate limit 방지

    print(f'[Yandex] 총 {len(results)}개 이미지 URL 추출')
    return results[:count]


def search_bing(query, count=5, sent_urls=None, page=0):
    """Bing 이미지 검색 — SafeSearch OFF, curl-cffi TLS 우회

    Args:
        query: 검색어
        count: 가져올 이미지 수
        sent_urls: 중복 방지용 이미 전송한 URL set
        page: 시작 페이지 번호 (0부터)

    Returns:
        list of image URL strings
    """
    from curl_cffi import requests as cffi_requests

    if sent_urls is None:
        sent_urls = set()

    session = cffi_requests.Session(impersonate='chrome')
    # SafeSearch OFF 쿠키
    session.cookies.set('SRCHHPGUSR', 'ADLT=OFF', domain='.bing.com')

    results = []
    collected = set()

    pages_needed = max(1, (count + 34) // 35)  # 페이지당 ~35개

    for p in range(page, page + pages_needed):
        if len(results) >= count:
            break

        first = p * 35
        params = {
            'q': query,
            'safeSearch': 'Off',
            'form': 'IRFLTR',
        }
        if first > 0:
            params['first'] = str(first)

        url = 'https://www.bing.com/images/search?' + urllib.parse.urlencode(params)
        print(f'[Bing] 페이지 {p} 요청...')

        text, ok = _fetch(session, url)
        if not ok:
            break

        # murl 패턴 (원본 이미지 URL)
        murls = re.findall(r'murl&quot;:&quot;(https?://[^&]+?)&quot;', text)
        print(f'[Bing] 페이지 {p}: {len(murls)}개 URL 발견')

        for u in murls:
            if len(results) >= count:
                break
            u = urllib.parse.unquote(u)
            if u in collected or u in sent_urls:
                continue
            if _is_excluded(u):
                continue
            collected.add(u)
            results.append(u)

        time.sleep(0.5)

    print(f'[Bing] 총 {len(results)}개 이미지 URL 추출')
    return results[:count]


def search_images(query, count=5, sent_urls=None, engine='yandex', page=0):
    """이미지 검색 통합 인터페이스

    Args:
        query: 검색어
        count: 가져올 이미지 수
        sent_urls: 중복 방지용 이미 전송한 URL set
        engine: 'yandex' 또는 'bing'
        page: 시작 페이지 번호

    Returns:
        list of image URL strings
    """
    print(f'[*] 검색: "{query}" (엔진: {engine}, 수량: {count})')

    if engine == 'bing':
        return search_bing(query, count=count, sent_urls=sent_urls, page=page)
    else:
        # Yandex 기본, 실패 시 Bing fallback
        results = search_yandex(query, count=count, sent_urls=sent_urls, page=page)
        if not results:
            print('[*] Yandex 결과 없음, Bing으로 전환...')
            results = search_bing(query, count=count, sent_urls=sent_urls, page=page)
        return results


# ─────────────────────────────────────────────
#  다운로드 / 텔레그램
# ─────────────────────────────────────────────

def download_image(url, dest_dir=None):
    """이미지 다운로드. 파일 경로 반환."""
    if dest_dir is None:
        dest_dir = tempfile.gettempdir()

    # URL에서 확장자 추출
    ext_match = re.search(r'\.(jpg|jpeg|png|gif|webp)', url.lower())
    ext = ext_match.group(1) if ext_match else 'jpg'

    # 파일명: URL 해시
    url_hash = hashlib.md5(url.encode()).hexdigest()[:12]
    filename = f'gimg_{url_hash}.{ext}'
    filepath = os.path.join(dest_dir, filename)

    if os.path.exists(filepath):
        print(f'  [=] 이미 존재: {filename}')
        return filepath

    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': (
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
            ),
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
            'Referer': 'https://yandex.com/',
        })
        resp = urllib.request.urlopen(req, timeout=15)
        data = resp.read()

        # 최소 크기 확인 (1KB 미만이면 유효하지 않음)
        if len(data) < 1024:
            print(f'  [!] 너무 작음 ({len(data)}B): {url[:80]}')
            return None

        with open(filepath, 'wb') as f:
            f.write(data)
        size_kb = len(data) / 1024
        print(f'  [v] 다운로드: {filename} ({size_kb:.1f}KB)')
        return filepath

    except Exception as e:
        print(f'  [!] 다운로드 실패: {e}')
        return None


def send_telegram_photo(filepath, caption=''):
    """텔레그램으로 사진 전송"""
    import mimetypes
    mime = mimetypes.guess_type(filepath)[0] or 'image/jpeg'
    boundary = '----PythonBoundary'
    filename = os.path.basename(filepath)

    with open(filepath, 'rb') as f:
        file_data = f.read()

    body = (
        f'--{boundary}\r\n'
        f'Content-Disposition: form-data; name="chat_id"\r\n\r\n{TG_CHAT_ID}\r\n'
        f'--{boundary}\r\n'
        f'Content-Disposition: form-data; name="caption"\r\n\r\n{caption}\r\n'
        f'--{boundary}\r\n'
        f'Content-Disposition: form-data; name="photo"; filename="{filename}"\r\n'
        f'Content-Type: {mime}\r\n\r\n'
    ).encode() + file_data + f'\r\n--{boundary}--\r\n'.encode()

    req = urllib.request.Request(
        f'https://api.telegram.org/bot{TG_TOKEN}/sendPhoto',
        data=body,
        headers={'Content-Type': f'multipart/form-data; boundary={boundary}'},
    )
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        result = json.loads(resp.read())
        ok = result.get('ok', False)
        if ok:
            print(f'  [T] 텔레그램 전송 완료: {filename}')
        else:
            print(f'  [!] 텔레그램 실패: {result}')
        return ok
    except Exception as e:
        print(f'  [!] 텔레그램 오류: {e}')
        return False


def send_telegram_url(url, caption=''):
    """URL로 직접 텔레그램 사진 전송 (다운로드 없이)"""
    data = urllib.parse.urlencode({
        'chat_id': TG_CHAT_ID,
        'photo': url,
        'caption': caption,
    }).encode()
    req = urllib.request.Request(
        f'https://api.telegram.org/bot{TG_TOKEN}/sendPhoto', data=data
    )
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        result = json.loads(resp.read())
        return result.get('ok', False)
    except Exception:
        return False


def main():
    parser = argparse.ArgumentParser(
        description='이미지 검색 + 다운로드 + 텔레그램 전송 (Yandex/Bing, curl-cffi)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            '예시:\n'
            '  python google_image_fetcher.py "cat meme" --count 3 --download\n'
            '  python google_image_fetcher.py "sunset" --count 5 --send\n'
            '  python google_image_fetcher.py "landscape" -c 3 -d -s\n'
            '  python google_image_fetcher.py "keyword" --engine bing\n'
            '  python google_image_fetcher.py "keyword" --page 2  # 3번째 페이지\n'
        )
    )
    parser.add_argument('query', help='검색어')
    parser.add_argument('-c', '--count', type=int, default=5, help='이미지 수 (기본 5)')
    parser.add_argument('-d', '--download', action='store_true', help='이미지 다운로드')
    parser.add_argument('-s', '--send', action='store_true', help='텔레그램 전송')
    parser.add_argument('--dest', default=None, help='다운로드 디렉토리 (기본: TEMP)')
    parser.add_argument('--no-dedup', action='store_true', help='중복 방지 비활성화')
    parser.add_argument('--engine', default='yandex', choices=['yandex', 'bing'],
                        help='검색 엔진 (기본: yandex)')
    parser.add_argument('--page', type=int, default=0, help='시작 페이지 (기본: 0)')
    args = parser.parse_args()

    # 중복 방지
    sent_urls = set() if args.no_dedup else load_sent_urls()

    # 검색
    urls = search_images(
        args.query,
        count=args.count,
        sent_urls=sent_urls,
        engine=args.engine,
        page=args.page,
    )

    if not urls:
        print('[!] 이미지를 찾지 못함')
        sys.exit(1)

    # URL 목록 출력
    print('\n--- 결과 ---')
    for i, url in enumerate(urls, 1):
        print(f'  {i}. {url}')

    downloaded_files = []

    # 다운로드
    if args.download or args.send:
        print('\n[*] 다운로드 시작...')
        for url in urls:
            filepath = download_image(url, dest_dir=args.dest)
            if filepath:
                downloaded_files.append((url, filepath))

    # 텔레그램 전송
    if args.send:
        print('\n[*] 텔레그램 전송...')
        sent_count = 0

        if downloaded_files:
            # 다운로드한 파일로 전송
            for url, filepath in downloaded_files:
                caption = f'{args.query} ({sent_count + 1}/{len(downloaded_files)})'
                ok = send_telegram_photo(filepath, caption=caption)
                if ok:
                    sent_urls.add(url)
                    sent_count += 1
                time.sleep(1)  # 텔레그램 rate limit 방지
        else:
            # URL 직접 전송 시도
            for i, url in enumerate(urls):
                caption = f'{args.query} ({i + 1}/{len(urls)})'
                ok = send_telegram_url(url, caption=caption)
                if ok:
                    sent_urls.add(url)
                    sent_count += 1
                    print(f'  [T] URL 전송 성공: {url[:80]}...')
                else:
                    # URL 전송 실패 시 다운로드 후 재시도
                    print(f'  [!] URL 전송 실패, 다운로드 후 재시도...')
                    filepath = download_image(url)
                    if filepath:
                        ok = send_telegram_photo(filepath, caption=caption)
                        if ok:
                            sent_urls.add(url)
                            sent_count += 1
                time.sleep(1)

        print(f'\n[*] 텔레그램 전송 완료: {sent_count}/{len(urls)}')

    # 중복 방지 저장
    if not args.no_dedup and urls:
        # 다운로드/전송 안 해도 검색한 URL은 기록
        for url in urls:
            sent_urls.add(url)
        save_sent_urls(sent_urls)
        print(f'[*] sent_urls.json 업데이트 (총 {len(sent_urls)}개)')

    print('[*] 완료')


if __name__ == '__main__':
    main()

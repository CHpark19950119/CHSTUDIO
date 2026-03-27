"""오래된 세션 파일 자동 삭제 — 7일 이상 된 .json 파일 제거"""
import os
import time
import sys

SESSIONS_DIR = os.path.join(os.path.dirname(__file__), '.sessions')
MAX_AGE_DAYS = 7
KEEP_MIN = 5  # 최소 5개는 유지

def cleanup():
    if not os.path.exists(SESSIONS_DIR):
        return

    files = []
    for f in os.listdir(SESSIONS_DIR):
        if f.endswith('.json'):
            path = os.path.join(SESSIONS_DIR, f)
            mtime = os.path.getmtime(path)
            files.append((mtime, path, f))

    files.sort(reverse=True)  # 최신순

    now = time.time()
    cutoff = now - (MAX_AGE_DAYS * 86400)
    deleted = 0

    for i, (mtime, path, name) in enumerate(files):
        if i < KEEP_MIN:
            continue  # 최소 유지 개수
        if mtime < cutoff:
            os.remove(path)
            deleted += 1
            print(f'삭제: {name}')

    print(f'정리 완료: {deleted}개 삭제, {len(files) - deleted}개 유지')

if __name__ == '__main__':
    cleanup()

"""세션 대화 백업 시스템 — .jsonl 파일에서 핵심 내용 추출
새 세션 시작 시 이전 세션의 핵심 맥락을 빠르게 복원.

사용법:
  python session_backup.py                  # 최근 세션 요약
  python session_backup.py --full           # 전체 대화 내용
  python session_backup.py --search "키워드" # 키워드 검색
"""
import os
import sys
import json
import glob
import argparse
from pathlib import Path
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SESSIONS_DIR = Path.home() / '.claude' / 'projects' / 'C--dev-CHSTUDIO'

def get_latest_session(n=1):
    """최근 n개 세션 .jsonl 파일 반환"""
    files = glob.glob(str(SESSIONS_DIR / '*.jsonl'))
    files.sort(key=os.path.getmtime, reverse=True)
    return files[:n]

def extract_messages(jsonl_path, role=None):
    """JSONL에서 메시지 추출"""
    messages = []
    with open(jsonl_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line.strip())
                msg = data.get('message', {})
                msg_role = msg.get('role', data.get('type', ''))
                content = msg.get('content', '')

                if role and msg_role != role:
                    continue

                # 텍스트 내용만 추출
                if isinstance(content, list):
                    texts = []
                    for c in content:
                        if isinstance(c, dict):
                            if c.get('type') == 'text':
                                texts.append(c.get('text', ''))
                            elif c.get('type') == 'tool_result':
                                texts.append(str(c.get('content', ''))[:200])
                        elif isinstance(c, str):
                            texts.append(c)
                    text = '\n'.join(texts)
                elif isinstance(content, str):
                    text = content
                else:
                    continue

                if text.strip():
                    ts = data.get('timestamp', '')
                    messages.append({
                        'role': msg_role,
                        'text': text.strip(),
                        'timestamp': ts,
                    })
            except (json.JSONDecodeError, KeyError):
                continue
    return messages

def summarize_session(jsonl_path, max_chars=5000):
    """세션 요약 — 사용자 메시지 + 주요 결정사항"""
    messages = extract_messages(jsonl_path)
    user_msgs = [m for m in messages if m['role'] in ('user', 'human')]
    assistant_msgs = [m for m in messages if m['role'] == 'assistant']

    summary = []
    summary.append(f"세션: {os.path.basename(jsonl_path)}")
    summary.append(f"수정일: {datetime.fromtimestamp(os.path.getmtime(jsonl_path))}")
    summary.append(f"메시지: 사용자 {len(user_msgs)}개, AI {len(assistant_msgs)}개")
    summary.append(f"크기: {os.path.getsize(jsonl_path) / 1024 / 1024:.1f}MB")
    summary.append("")
    summary.append("=== 사용자 메시지 (최근 20개) ===")
    for m in user_msgs[-20:]:
        text = m['text'][:200]
        summary.append(f"  [{m['timestamp'][:19]}] {text}")

    return '\n'.join(summary)[:max_chars]

def search_sessions(keyword, n=3):
    """최근 n개 세션에서 키워드 검색"""
    results = []
    for f in get_latest_session(n):
        messages = extract_messages(f)
        for m in messages:
            if keyword.lower() in m['text'].lower():
                results.append({
                    'session': os.path.basename(f),
                    'role': m['role'],
                    'text': m['text'][:300],
                    'timestamp': m['timestamp'],
                })
    return results

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='세션 대화 백업/검색')
    parser.add_argument('--full', action='store_true', help='전체 내용')
    parser.add_argument('--search', '-s', help='키워드 검색')
    parser.add_argument('--count', '-n', type=int, default=1, help='세션 수')
    args = parser.parse_args()

    if args.search:
        results = search_sessions(args.search, args.count)
        print(f'"{args.search}" 검색 결과: {len(results)}개')
        for r in results[:20]:
            print(f'  [{r["role"]}] {r["text"][:150]}')
    else:
        for f in get_latest_session(args.count):
            print(summarize_session(f))
            print()

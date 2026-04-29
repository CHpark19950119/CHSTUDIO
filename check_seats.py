"""스터디카페 실시간 좌석 현황 — 멀티 매장 매핑."""
import urllib.request, json, sys

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhbWJObyI6Ijk3QUY5MjRDLUFBMzItNEQ0MS1CRDhELUFEQTQ0MkUzMEU0QyIsImFtYlBob25lIjoiMDEwMjQzNTgwNjciLCJhbWJOYW1lIjoi67CV7LKc7ZmNIiwiYW1iQmlydGgiOiIxOTk1LTAxLTE5IiwiYW1iR2VuZGVyIjoibWFsZSIsImlhdCI6MTc3NzI4NDM3MiwiZXhwIjoxNzc5ODc2MzcyfQ.p-Ne32MSPuAE9tKFjZgorHQAA3lW8VHwcHYgNoPRVxk"
API = "https://data.space-force.kr"

# spNo 매핑 — 루카만 확정. 작심 군포부곡 spNo 미상 (master 에 spTitle row 없음, 사용자 v2 도면 검증으로 785 가설 기각).
SHOPS = {
    "luca": {"spNo": 1109, "title": "루카 군포점"},
}


def api_post(path, body=None):
    data = json.dumps(body or {}).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, headers={
        "nuj-authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
    })
    return json.loads(urllib.request.urlopen(req, timeout=10).read())


def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers={
        "nuj-authorization": f"Bearer {TOKEN}",
    })
    return json.loads(urllib.request.urlopen(req, timeout=10).read())


def get_seats(sp_no):
    """좌석 타입별 잔여."""
    tickets = api_get(f"/app/shop/ticket/{sp_no}")
    seat_types = []
    seen = set()
    for category in tickets.get("data", {}).get("svcMenu", {}).values():
        for item in category.get("list", []):
            stc = item.get("SeatConfig", {})
            stc_no = stc.get("stcNo")
            if stc_no and stc_no not in seen:
                seen.add(stc_no)
                seat_types.append({"stcNo": stc_no, "title": stc.get("stcTitle", "?")})

    results = []
    for st in seat_types:
        try:
            resp = api_post("/app/seat/remain", {"spNo": sp_no, "stcNo": st["stcNo"]})
            count = resp.get("data", {}).get("seat", {}).get("count", "?")
            results.append({"type": st["title"], "stcNo": st["stcNo"], "remain": count})
        except Exception as e:
            results.append({"type": st["title"], "stcNo": st["stcNo"], "remain": f"err({e})"})
    return results


def get_position(sp_no):
    """구역별 사용/잔여 — usePosition 기준 (mbNo 만 보면 누락 있음)."""
    resp = api_get(f"/app/shop/position/{sp_no}")
    data = resp.get("data", {})
    floors = data.get("position", [])
    use_pos = data.get("usePosition") or {}
    summary = []
    for floor in floors:
        seats = floor.get("seats", [])
        if not seats:
            continue
        total = len(seats)
        occupied = sum(1 for s in seats if s.get("stNo") in use_pos or s.get("mbNo"))
        summary.append({
            "floor": floor.get("strName") or f"구역{floor.get('strNo','')}",
            "total": total,
            "occupied": occupied,
            "available": total - occupied,
        })
    return summary


def report(key):
    info = SHOPS[key]
    sp_no = info["spNo"]
    print(f"\n{info['title']} (spNo {sp_no})")
    print("=" * 50)

    print("\n[좌석 타입별 잔여]")
    for s in get_seats(sp_no):
        print(f"  {s['type']:12s} (stcNo {s['stcNo']:5}): {s['remain']}석 남음")

    print("\n[구역별 현황]")
    for f in get_position(sp_no):
        print(f"  {f['floor']}: {f['available']}/{f['total']}석 빈자리")


if __name__ == "__main__":
    if sys.platform == "win32":
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    targets = sys.argv[1:] if len(sys.argv) > 1 else list(SHOPS.keys())
    for key in targets:
        if key not in SHOPS:
            print(f"unknown shop: {key} (available: {', '.join(SHOPS)})")
            continue
        try:
            report(key)
        except Exception as e:
            print(f"\n[{key}] error: {e}")
    print()

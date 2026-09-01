#!/usr/bin/env python3
"""char_* 최종 스프라이트(face-blank)에서 얼굴 앵커(정규화 cx/cy/r)를 자동 산출한다.

살구색 피부 픽셀 마스크(상단 65% 영역, 최대 연결 성분)를 얼굴로 보고
assets/art/face-anchors.json 을 갱신한다. ChildAvatar 가 표정을 이 좌표에 그린다.
사용: python3 tools/compute_face_anchors.py
"""
import json
import os
import sys
from collections import deque

from PIL import Image

ART = "assets/art"


def face_blob(im):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    top_limit = int(h * 0.65)
    mask = [[False] * w for _ in range(top_limit)]
    for y in range(top_limit):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 200:
                continue
            # 살구색 피부: 밝고 붉은 기 — 크림 의상(R-G 작음)과 R-G 차로 구분
            if r > 225 and 185 < g < 246 and 170 < b < 238 and (r - b) > 14 and (r - g) >= 12:
                mask[y][x] = True
    seen = [[False] * w for _ in range(top_limit)]
    best = None
    for y in range(top_limit):
        for x in range(w):
            if not mask[y][x] or seen[y][x]:
                continue
            q = deque([(x, y)])
            seen[y][x] = True
            pts_n = 0
            sx = sy = 0
            minx, maxx, miny, maxy = x, x, y, y
            while q:
                cx, cy = q.popleft()
                pts_n += 1
                sx += cx
                sy += cy
                minx = min(minx, cx); maxx = max(maxx, cx)
                miny = min(miny, cy); maxy = max(maxy, cy)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < top_limit and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if best is None or pts_n > best[0]:
                best = (pts_n, sx / pts_n, sy / pts_n, maxx - minx + 1, maxy - miny + 1)
    if best is None or best[0] < (w * h) * 0.005:
        return None
    _, cx, cy, bw, bh = best
    return {
        "cx": round(cx / w, 4),
        "cy": round(cy / h, 4),
        "r": round(bw * 0.5 * 0.85 / w, 4),
    }


def main():
    out_path = os.path.join(ART, "face-anchors.json")
    anchors = {}
    if os.path.exists(out_path):
        with open(out_path) as f:
            anchors = json.load(f)
    names = sorted(
        n[:-4] for n in os.listdir(ART)
        if n.startswith("char_") and n.endswith(".png"))
    fails = []
    for name in names:
        a = face_blob(Image.open(os.path.join(ART, name + ".png")))
        if a is None:
            fails.append(name)
            continue
        anchors[name] = a
        print(f"{name}: cx={a['cx']} cy={a['cy']} r={a['r']}")
    with open(out_path, "w") as f:
        json.dump(anchors, f, indent=1, sort_keys=True)
    print(f"saved {out_path} ({len(anchors)} anchors)")
    if fails:
        print("FAILED:", ", ".join(fails), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

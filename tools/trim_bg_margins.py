#!/usr/bin/env python3
"""불투명 배경 에셋(bg_*, cg_*)의 흰 여백을 잘라낸다.

생성 모델이 4:3/16:9 캔버스 안에 그림을 중앙 배치하고 주변을 흰색으로 남기는 경우가 있어,
엔진에서 cover-fit 해도 흰 띠가 보인다. 가장자리부터 연속된 '거의 흰색' 행/열만 제거한다.
최종본만 처리하고 raw/ 는 건드리지 않는다(재생성 후 다시 실행).

사용: python3 tools/trim_bg_margins.py
"""
import glob
import os

from PIL import Image

ART = "assets/art"
NEAR_WHITE = 248
# 한 행/열이 여백으로 간주되는 비율(작은 장식이 있어도 잘리도록 약간 여유)
RATIO = 0.995


def is_blank(pixels, fixed, length, horizontal):
    hits = 0
    for i in range(length):
        p = pixels[i, fixed] if horizontal else pixels[fixed, i]
        if p[0] >= NEAR_WHITE and p[1] >= NEAR_WHITE and p[2] >= NEAR_WHITE:
            hits += 1
    return hits >= length * RATIO


def trim(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    top, bottom, left, right = 0, h - 1, 0, w - 1
    while top < bottom and is_blank(px, top, w, True):
        top += 1
    while bottom > top and is_blank(px, bottom, w, True):
        bottom -= 1
    while left < right and is_blank(px, left, h, False):
        left += 1
    while right > left and is_blank(px, right, h, False):
        right -= 1
    if (top, left, right, bottom) == (0, 0, w - 1, h - 1):
        return False
    im.crop((left, top, right + 1, bottom + 1)).save(path)
    print("trimmed %-26s %dx%d -> %dx%d" % (
        os.path.basename(path), w, h, right - left + 1, bottom - top + 1))
    return True


def main():
    targets = []
    for pattern in ("bg_*.png", "cg_*.png"):
        targets.extend(sorted(glob.glob(os.path.join(ART, pattern))))
    changed = sum(1 for t in targets if trim(t))
    print("checked %d, trimmed %d" % (len(targets), changed))


if __name__ == "__main__":
    main()

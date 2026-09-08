#!/usr/bin/env python3
"""활동 데이터와 카드 아트/생성 manifest의 대응 관계를 검증한다."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
ACTIVITIES_PATH = REPO_ROOT / "data" / "activities.json"
ART_DIR = REPO_ROOT / "assets" / "art"
MANIFEST_PATH = ART_DIR / "asset-manifest.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
EXPECTED_SIZE = (256, 256)
RGBA_COLOR_TYPE = 6


def load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def png_header(path: Path) -> tuple[int, int, int]:
    with path.open("rb") as file:
        if file.read(8) != PNG_SIGNATURE:
            raise ValueError("PNG signature가 아닙니다")
        chunk_length = struct.unpack(">I", file.read(4))[0]
        chunk_type = file.read(4)
        if chunk_type != b"IHDR" or chunk_length != 13:
            raise ValueError("유효한 IHDR chunk가 없습니다")
        width, height, _bit_depth, color_type = struct.unpack(">IIBB", file.read(10))
    return width, height, color_type


def fail(message: str) -> None:
    print(f"[activity-art] {message}", file=sys.stderr)


def main() -> int:
    activities_doc = load_json(ACTIVITIES_PATH)
    manifest_doc = load_json(MANIFEST_PATH)
    activities = activities_doc.get("activities", []) if isinstance(activities_doc, dict) else []
    manifest_assets = manifest_doc.get("assets", []) if isinstance(manifest_doc, dict) else []

    activity_ids = [
        item.get("id") for item in activities
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    ]
    manifest_names = [
        item.get("name") for item in manifest_assets
        if isinstance(item, dict) and isinstance(item.get("name"), str)
    ]

    errors: list[str] = []
    if len(activity_ids) != len(activities):
        errors.append("모든 활동에 문자열 id가 있어야 합니다")
    if len(activity_ids) != len(set(activity_ids)):
        errors.append("활동 id가 중복되었습니다")

    for activity_id in activity_ids:
        asset_name = f"act_{activity_id}"
        asset_path = ART_DIR / f"{asset_name}.png"
        if not asset_path.is_file():
            errors.append(f"활동 아트 누락: {asset_path.relative_to(REPO_ROOT)}")
            continue
        if manifest_names.count(asset_name) != 1:
            errors.append(f"manifest 항목은 정확히 하나여야 합니다: {asset_name}")
        try:
            width, height, color_type = png_header(asset_path)
        except (OSError, ValueError, struct.error) as error:
            errors.append(f"활동 아트 PNG 오류: {asset_path.relative_to(REPO_ROOT)} ({error})")
            continue
        if (width, height) != EXPECTED_SIZE:
            errors.append(
                f"활동 아트 크기 오류: {asset_path.relative_to(REPO_ROOT)} "
                f"({width}x{height}, 기대값 256x256)"
            )
        if color_type != RGBA_COLOR_TYPE:
            errors.append(
                f"활동 아트 알파 채널 누락: {asset_path.relative_to(REPO_ROOT)} "
                f"(PNG color type {color_type})"
            )

    if errors:
        for error in errors:
            fail(error)
        return 1

    print(f"[activity-art] {len(activity_ids)}개 활동 아트 검증 통과")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

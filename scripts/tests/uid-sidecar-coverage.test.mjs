import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const VENDOR_PREFIX = "addons/seorilabs_platform/";

function git(...args) {
  return execFileSync("git", ["-C", repoRoot, ...args], { maxBuffer: 1 << 28 })
    .toString("utf8")
    .split("\0")
    .filter(Boolean);
}

function trackedOutsideVendor(pattern) {
  return git("ls-files", "-z", pattern).filter((path) => !path.startsWith(VENDOR_PREFIX));
}

/**
 * Godot이 짝이 되는 .uid를 못 찾으면 실행 환경마다 새 UID를 만들어 쓴다
 * (#42) — 저장소에 고정되지 않은 리소스 참조가 생기는 원인이다. 벤더링
 * 디렉터리(addons/seorilabs_platform)는 자체 .uid 정책이 따로 있어 제외한다.
 */
test("벤더링 밖 모든 .gd는 커밋된 .uid 사이드카를 가진다", () => {
  const scripts = trackedOutsideVendor("*.gd");
  const uidSidecars = new Set(trackedOutsideVendor("*.gd.uid"));
  const missing = scripts.filter((path) => !uidSidecars.has(`${path}.uid`));

  assert.deepEqual(missing, [], `.uid가 없는 .gd: ${missing.join(", ")}`);
});

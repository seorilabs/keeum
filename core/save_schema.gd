class_name SaveSchema
extends RefCounted
## 세이브 blob 최상위 스키마 버전 판정(#45). GameRun.SCHEMA_VERSION 은 run 하위 구조만
## 다루고 기록만 될 뿐 읽는 코드가 없었고, Profile 에는 버전 자체가 없었다. 이 버전은
## blob 전체({"schema_version", "profile", "run"})를 다뤄 로드 경로가 "그대로 사용 /
## 마이그레이션 / 거부"를 명시적으로 나누게 한다.

const CURRENT_VERSION := 1

## classify() 반환값.
const RESULT_CURRENT := "current"    # 아는 버전 그대로 사용
const RESULT_MIGRATE := "migrate"    # 버전 없음/더 낮음 → 최신 구조로 승격 가능
const RESULT_REJECT := "reject"      # 이 코드가 아는 것보다 높은 버전 → 기존 세이브 보존, 로드 거부

## 버전 키가 없으면 0(마이그레이션 대상)으로 본다.
static func classify(blob: Dictionary) -> String:
	var version := int(blob.get("schema_version", 0))
	if version > CURRENT_VERSION:
		return RESULT_REJECT
	if version < CURRENT_VERSION:
		return RESULT_MIGRATE
	return RESULT_CURRENT

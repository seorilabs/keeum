class_name AdGateway
extends RefCounted
## 보상형 광고 경계(#34). 실제 SDK(AdMob·Platform)가 붙기 전까지는 항상 "이용 불가"를
## 돌려줘, 광고 버튼과 "광고 시청 완료" 문구가 붙지도 않은 화면에 뜨지 않게 한다 —
## `ShopCatalog`(#31)의 결제 미연동 처리와 같은 규칙이다.
##
## 세션 8회 / 일일 18회 이중 캡(05-economy-content-liveops.md:76)은 어댑터가 있다고
## 가정한 테스트 경로에서도 검증할 수 있도록 이 경계가 소유한다. 일일 카운트는
## `GameController` 가 이미 쓰는 `Profile` 저장 규약(to_dict/from_dict)에 실어 영속시키고,
## "오늘"의 판정은 Godot 시스템 시계(`Time.get_date_string_from_system()`)를 그대로 쓴다 —
## 새 스케줄러·새 저장 파일을 만들지 않는다.
##
## 최소 간격·최소 진행 조건은 이 이슈의 범위 밖이다(#34 제외 항목).

const SESSION_CAP := 8
const DAILY_CAP := 18

## 헤드리스 검증이 어댑터 연결 상태를 흉내 낼 때만 쓰는 스텁 오버라이드.
static var _stub_available := false
## 테스트 전용: "오늘"을 고정한다. 비어 있으면 시스템 날짜를 쓴다.
static var _stub_today := ""
## 세션(프로세스 수명) 카운트 — 앱을 껐다 켜면 0으로 돌아간다. Profile 에 싣지 않는다.
static var _session_count := 0

static func is_available() -> bool:
	return _stub_available

## 광고 지점(버튼·문구)을 화면에 만들어도 되는지. 어댑터 미연동이거나 두 캡 중
## 하나라도 다 찼으면 false — 호출부는 이 값이 false 인 동안 버튼 자체를 만들지 않는다.
static func can_open(profile: Profile) -> bool:
	if not is_available():
		return false
	if _session_count >= SESSION_CAP:
		return false
	return _daily_count(profile) < DAILY_CAP

## 실제로 광고 시청이 끝나 보상을 지급하기 직전에 호출한다. 세션 카운트를 올리고
## profile 의 일일 카운트를 올린다 — profile 저장은 기존 관례대로 호출부가
## `GameController.save_game()` 로 맡는다.
static func record_shown(profile: Profile) -> void:
	_session_count += 1
	var today := _today()
	if profile.ad_daily_key != today:
		profile.ad_daily_key = today
		profile.ad_daily_count = 0
	profile.ad_daily_count += 1

static func _daily_count(profile: Profile) -> int:
	if profile.ad_daily_key != _today():
		return 0
	return profile.ad_daily_count

static func _today() -> String:
	if _stub_today != "":
		return _stub_today
	return Time.get_date_string_from_system()

## 테스트 전용: 어댑터가 연결된 것처럼 흉내 낸다.
static func set_test_available(value: bool) -> void:
	_stub_available = value

## 테스트 전용: "오늘"을 고정한다.
static func set_test_today(date_string: String) -> void:
	_stub_today = date_string

## 테스트 전용: 세션 카운트를 직접 지정한다(캡 도달 상태를 즉시 만들 때 쓴다).
static func set_test_session_count(value: int) -> void:
	_session_count = value

## 테스트 전용: 어댑터 연결·오늘·세션 카운트를 전부 미연동 기본값으로 되돌린다.
## profile 의 일일 카운트는 profile 소유이므로 여기서 건드리지 않는다.
static func reset_test_state() -> void:
	_stub_available = false
	_stub_today = ""
	_session_count = 0

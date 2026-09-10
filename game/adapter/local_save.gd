class_name LocalSave
extends RefCounted
## 로컬 저장 어댑터. core 직렬화 결과(Dictionary)를 user:// 경로 JSON 으로 왕복한다.
## Firestore 클라우드 동기화는 phase 2 어댑터로 확장(현재는 로컬 우선).
##
## 저장은 임시 파일 → 쓰기 완주 검증 → 직전 세대 백업 → 교체 순서다(#12).
## 실패는 false 반환이 계약이고 로그는 warning 으로 남긴다 — 헤드리스 게이트가
## ERROR 로그를 실패로 세므로, 의도된 실패 경로(쓰기 실패 시 false)를 검증할 수 있어야 한다.
## 본 파일은 교체 직전까지 손대지 않으므로 쓰는 도중 프로세스가 죽어도
## 직전 세이브(또는 .bak 세대)가 남는다.

const SAVE_PATH := "user://keeum_save.json"
const TMP_PATH := SAVE_PATH + ".tmp"
const BACKUP_PATH := SAVE_PATH + ".bak"
const CORRUPT_PATH := SAVE_PATH + ".corrupt"

## load_result() 의 status 값.
const STATUS_OK := "ok"                # 본 파일 정상
const STATUS_RECOVERED := "recovered"  # 본 파일 없음/손상 → 백업 세대에서 복구
const STATUS_EMPTY := "empty"          # 세이브가 아예 없는 첫 실행
const STATUS_CORRUPT := "corrupt"      # 본 파일·백업 모두 손상
const STATUS_FUTURE_VERSION := "future_version"  # 이 코드가 아는 것보다 높은 스키마 버전(#45) — 파일 보존, 로드 거부

## 헤드리스 검증 도구가 실제 사용자 저장과 분리된 디렉터리를 이 값으로 알려줄 때만
## user:// 접근을 허용한다(#17). 값 자체가 아니라 실제 user:// 가 그 경로 아래에
## 들어와 있는지까지 확인해, 변수만 세팅되고 격리(XDG_DATA_HOME 등)는 안 된 상태를 구분한다.
const TEST_ISOLATION_ENV := "KEEUM_TEST_USER_DIR"

## 격리 루트가 설정돼 있고 실제 user:// 가 그 안에 들어와 있는지 확인한다.
static func is_user_dir_isolated() -> bool:
	var expected := OS.get_environment(TEST_ISOLATION_ENV)
	return not expected.is_empty() and OS.get_user_data_dir().begins_with(expected)

## --ui-smoke/--ui-play 로 실행됐는지만 본다(#17 범위) — 빌드·임포트·export 등
## 다른 헤드리스 실행은 이 판정에 넣지 않는다. 그 경로들은 기존 동작을 그대로 유지한다.
static func is_headless_ui_test_drive() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--ui-smoke" in OS.get_cmdline_args() or "--ui-smoke" in args or "--ui-play" in args

static func save(data: Dictionary) -> bool:
	# GameController._ready() 의 거부는 quit() 요청일 뿐 그 프레임에 이미 큐잉된
	# 후속 호출(--ui-smoke/--ui-play 하네스의 new_game→save_game 등)을 막지 못한다.
	# 실제 쓰기 관문인 여기서 다시 막아야 격리 없는 실행이 끝까지 흘러가도
	# 실제 저장을 덮어쓰지 않는다(#17).
	if is_headless_ui_test_drive() and not is_user_dir_isolated():
		push_error("LocalSave: --ui-smoke/--ui-play 실행에 저장 격리(%s)가 없어 저장을 거부한다" % TEST_ISOLATION_ENV)
		return false
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("LocalSave: 저장 열기 실패")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	var write_error := f.get_error()
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("LocalSave: 저장 디렉터리 열기 실패")
		return false
	if write_error != OK:
		push_warning("LocalSave: 저장 쓰기 실패 (%d)" % write_error)
		dir.remove(TMP_PATH)
		return false
	# 완주 검증: 디스크 부족 등으로 잘린 임시본을 본 파일로 승격하지 않는다.
	if typeof(_parse_quiet(FileAccess.get_file_as_string(TMP_PATH))) != TYPE_DICTIONARY:
		push_warning("LocalSave: 저장 검증 실패")
		dir.remove(TMP_PATH)
		return false
	if dir.file_exists(SAVE_PATH):
		if dir.file_exists(BACKUP_PATH):
			dir.remove(BACKUP_PATH)
		if dir.rename(SAVE_PATH, BACKUP_PATH) != OK:
			push_warning("LocalSave: 백업 세대 교체 실패")
			dir.remove(TMP_PATH)
			return false
	if dir.rename(TMP_PATH, SAVE_PATH) != OK:
		push_warning("LocalSave: 저장 교체 실패")
		return false
	return true

## 반환: {"status": STATUS_*, "data": Dictionary}. 본 파일이 없거나 파싱에
## 실패했을 때만 백업 세대를 읽는다. 호출자는 status 로 "정상 / 백업에서 복구 /
## 세이브 없음 / 손상"을 구분해 빈 프로필로 조용히 덮어쓰지 않아야 한다.
static func load_result() -> Dictionary:
	var primary_exists := FileAccess.file_exists(SAVE_PATH)
	if primary_exists:
		var parsed: Variant = _parse_quiet(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(parsed) == TYPE_DICTIONARY and _looks_like_save(parsed):
			return {"status": STATUS_OK, "data": parsed}
	var backup_exists := FileAccess.file_exists(BACKUP_PATH)
	if backup_exists:
		var backup: Variant = _parse_quiet(FileAccess.get_file_as_string(BACKUP_PATH))
		if typeof(backup) == TYPE_DICTIONARY and _looks_like_save(backup):
			return {"status": STATUS_RECOVERED, "data": backup}
	if primary_exists or backup_exists:
		return {"status": STATUS_CORRUPT, "data": {}}
	return {"status": STATUS_EMPTY, "data": {}}

## keeum 세이브 blob 모양인지 최소 판정한다(#45). 파싱만 되면 무조건 정상으로 보던
## 이전 동작은 keeum 세이브가 아닌 임의 Dictionary JSON 도 STATUS_OK 로 판정했다.
## 실제 필드 유효성은 Profile/GameRun 이 각자 담당하므로 여기서는 최소 문지방만 본다.
static func _looks_like_save(parsed: Dictionary) -> bool:
	return parsed.has("profile") or parsed.has("schema_version")

## 손상 파일 검사가 콘솔에 ERROR 를 남기지 않도록 인스턴스 JSON 파서를 쓴다.
## (JSON.parse_string 은 실패 시 자체 ERROR 로그를 남겨 헤드리스 게이트에 걸린다.)
static func _parse_quiet(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


static func load_data() -> Dictionary:
	return load_result().get("data", {})

## 손상 세이브를 덮어쓰지 않고 증거로 보존한다. 이후 저장 경로는 비워진다.
static func quarantine_corrupt() -> void:
	if is_headless_ui_test_drive() and not is_user_dir_isolated():
		push_error("LocalSave: --ui-smoke/--ui-play 실행에 저장 격리(%s)가 없어 손상 격리를 거부한다" % TEST_ISOLATION_ENV)
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(CORRUPT_PATH):
		dir.remove(CORRUPT_PATH)
	if dir.file_exists(SAVE_PATH):
		dir.rename(SAVE_PATH, CORRUPT_PATH)
	if dir.file_exists(BACKUP_PATH):
		dir.remove(BACKUP_PATH)

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

static func clear() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for path in [SAVE_PATH, TMP_PATH, BACKUP_PATH]:
		if dir.file_exists(path):
			dir.remove(path)

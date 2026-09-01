class_name LocalSave
extends RefCounted
## 로컬 저장 어댑터. core 직렬화 결과(Dictionary)를 user:// 경로 JSON 으로 왕복한다.
## Firestore 클라우드 동기화는 phase 2 어댑터로 확장(현재는 로컬 우선).

const SAVE_PATH := "user://keeum_save.json"

static func save(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("LocalSave: 저장 열기 실패")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func clear() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		# user:// 는 globalize 로 실경로 삭제. 실패 시 무시.

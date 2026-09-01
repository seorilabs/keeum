class_name ContentDB
extends RefCounted
## 데이터 리소스(JSON) 로더. 활동·이벤트·전환기·엔딩·프로필 풀을 읽어 캐싱한다.
## Remote Config 로 교체 가능한 데이터 계층이므로 core 규칙과 분리한다.

const DATA_DIR := "res://data/"

var activities: Array = []
var events: Array = []
var transitions: Array = []
var endings: Array = []
var applications: Dictionary = {}
var profiles: Dictionary = {}

var _activity_by_id: Dictionary = {}
var _loaded := false

func load_all() -> bool:
	if _loaded:
		return true
	var a := _read_json("activities.json")
	activities = a.get("activities", [])
	for act: Dictionary in activities:
		_activity_by_id[str(act.get("id", ""))] = act
	events = _read_json("events.json").get("events", [])
	transitions = _read_json("transitions.json").get("transitions", [])
	var e := _read_json("endings.json")
	endings = e.get("endings", [])
	applications = e.get("applications", {})
	profiles = _read_json("profiles.json")
	_loaded = not activities.is_empty() and not endings.is_empty()
	return _loaded

func _read_json(filename: String) -> Dictionary:
	var path := DATA_DIR + filename
	if not FileAccess.file_exists(path):
		push_error("ContentDB: 데이터 파일 없음 " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ContentDB: JSON 파싱 실패 " + path)
		return {}
	return parsed

func activity(id: String) -> Dictionary:
	return _activity_by_id.get(id, {})

func transition_for_gate(gate: String) -> Dictionary:
	for t: Dictionary in transitions:
		if str(t.get("gate", "")) == gate:
			return t
	return {}

func ending_by_id(id: String) -> Dictionary:
	for e: Dictionary in endings:
		if str(e.get("id", "")) == id:
			return e
	return {}

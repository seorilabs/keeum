extends SceneTree
## 세이브 내구성 헤드리스 검증(#12). 저장 도중 프로세스가 죽어도 직전 세대가
## 남고, 손상·백업·첫 실행이 구분되는지 LocalSave 와 GameController 로 실증한다.
## 실행: godot --headless --path . --script res://tools/save_probe.gd

var _fail := 0


func _initialize() -> void:
	print("=== keeum 세이브 내구성 검증 (#12) ===")
	_cleanup_files()
	var content := ContentDB.new()
	if not content.load_all():
		print("  ✗ 콘텐츠 로드 실패"); _fail += 1
	else:
		_run_scenarios(content)
	_cleanup_files()
	if _fail == 0:
		print("\n✅ 세이브 검증 통과")
	else:
		print("\n❌ 세이브 검증 실패 %d건" % _fail)
	quit(_fail)


func _run_scenarios(content: ContentDB) -> void:
	# 영속 자산이 실린 실제 blob 두 세대를 만든다.
	var profile := Profile.new()
	profile.register_ending("hanul_happy")
	profile.add_premium(120)
	var run := GameRun.new()
	run.setup(content)
	run.start_new({"name": "내구", "gender": "neutral", "generation": 1, "seed": 20260912})
	# 기대값도 JSON 왕복으로 정규화한다 — 저장을 거치면 int 가 float 로 돌아오므로
	# 원본 Variant 그대로는 심층 비교가 성립하지 않는다.
	var v1: Dictionary = _roundtrip({"profile": profile.to_dict(), "run": run.to_dict()})
	profile.register_ending("stable_calm")
	var v2: Dictionary = _roundtrip({"profile": profile.to_dict(), "run": run.to_dict()})

	# 1) 정상 왕복: 두 번 저장하면 본 파일=v2, 백업 세대=v1.
	_expect("save v1", LocalSave.save(v1))
	_expect("save v2", LocalSave.save(v2))
	var ok_result := LocalSave.load_result()
	_expect("정상 status=ok", String(ok_result["status"]) == LocalSave.STATUS_OK)
	_expect("정상 data=v2", (ok_result["data"] as Dictionary) == v2)
	var backup_parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(LocalSave.BACKUP_PATH))
	_expect("백업 세대=v1", typeof(backup_parsed) == TYPE_DICTIONARY and (backup_parsed as Dictionary) == v1)

	# 2) 본 파일이 중간에서 잘려도 직전 세대(백업)로 복구된다 — AC-1.
	var full_text := FileAccess.get_file_as_string(LocalSave.SAVE_PATH)
	_write_raw(LocalSave.SAVE_PATH, full_text.substr(0, full_text.length() / 2))
	var recovered := LocalSave.load_result()
	_expect("잘린 본 파일 status=recovered", String(recovered["status"]) == LocalSave.STATUS_RECOVERED)
	var recovered_data: Dictionary = recovered["data"]
	_expect("복구 데이터=직전 세대(v1)", recovered_data == v1)
	var recovered_profile := Profile.from_dict(recovered_data.get("profile", {}))
	_expect("도감 복원", recovered_profile.collected_endings == ["hanul_happy"])
	_expect("프리미엄 복원", recovered_profile.premium == Balance.START_PREMIUM + 120)
	_expect("회차 복원", not (recovered_data.get("run", {}) as Dictionary).is_empty())

	# 3) 교체 직전 중단 흉내(임시 파일만 부분 기록)에도 본 파일은 손상되지 않는다 — AC-2.
	_expect("save v2 재기록", LocalSave.save(v2))
	_write_raw(LocalSave.TMP_PATH, "{\"partial\": tru")
	var after_crash := LocalSave.load_result()
	_expect("중단 후 status=ok", String(after_crash["status"]) == LocalSave.STATUS_OK)
	_expect("중단 후 data=v2", (after_crash["data"] as Dictionary) == v2)
	DirAccess.open("user://").remove(LocalSave.TMP_PATH)

	# 4) 쓰기가 끝까지 성공하지 못하면 false 를 돌려주고 기존 세이브를 남긴다 — AC-3.
	#    임시 파일 경로를 디렉터리로 막아 열기 실패를 만든다.
	var dir := DirAccess.open("user://")
	dir.make_dir(LocalSave.TMP_PATH)
	_expect("쓰기 실패 시 false", not LocalSave.save(v1))
	_expect("실패 후 기존 세이브 유지", (LocalSave.load_result()["data"] as Dictionary) == v2)
	dir.remove(LocalSave.TMP_PATH)

	# 5) 세이브가 아예 없는 첫 실행은 empty 로 구분된다 — AC-4.
	_cleanup_files()
	_expect("첫 실행 status=empty", String(LocalSave.load_result()["status"]) == LocalSave.STATUS_EMPTY)

	# 6) GameController: 잘린 본 파일 → 백업 세대로 복구하고 본 파일로 승격한다.
	_expect("save v1 재기록", LocalSave.save(v1))
	_expect("save v2 재기록2", LocalSave.save(v2))
	full_text = FileAccess.get_file_as_string(LocalSave.SAVE_PATH)
	_write_raw(LocalSave.SAVE_PATH, full_text.substr(0, full_text.length() / 2))
	var controller := _fresh_controller()
	_expect("컨트롤러 status=recovered", controller.last_load_status == LocalSave.STATUS_RECOVERED)
	_expect("컨트롤러 도감 복원", controller.profile.collected_endings == ["hanul_happy"])
	_expect("컨트롤러 회차 복원", controller.run != null)
	_expect("복구본 본 파일 승격", String(LocalSave.load_result()["status"]) == LocalSave.STATUS_OK)
	controller.free()

	# 7) GameController: 본 파일·백업 모두 손상 → 새 프로필 + 원본 격리(조용한 덮어쓰기 금지).
	_cleanup_files()
	_write_raw(LocalSave.SAVE_PATH, "not json at all")
	_write_raw(LocalSave.BACKUP_PATH, "also broken")
	var corrupt_controller := _fresh_controller()
	_expect("컨트롤러 status=corrupt", corrupt_controller.last_load_status == LocalSave.STATUS_CORRUPT)
	_expect("손상 시 새 프로필", corrupt_controller.profile.collected_endings.is_empty())
	_expect("손상 원본 격리 보존", FileAccess.file_exists(LocalSave.CORRUPT_PATH))
	_expect("격리 후 저장 경로 비움", not FileAccess.file_exists(LocalSave.SAVE_PATH))
	corrupt_controller.free()


func _fresh_controller() -> Node:
	var controller: Node = load("res://game/autoload/game_controller.gd").new()
	controller.content = ContentDB.new()
	controller.content.load_all()
	controller.restore_from_disk()
	return controller


func _roundtrip(blob: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(blob, "\t"))


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _cleanup_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for path in [LocalSave.SAVE_PATH, LocalSave.TMP_PATH, LocalSave.BACKUP_PATH, LocalSave.CORRUPT_PATH]:
		if dir.file_exists(path):
			dir.remove(path)


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ %s" % label)
		_fail += 1

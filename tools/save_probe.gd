extends SceneTree
## 세이브 내구성 헤드리스 검증(#12). 저장 도중 프로세스가 죽어도 직전 세대가
## 남고, 손상·백업·첫 실행이 구분되는지 LocalSave 와 GameController 로 실증한다.
## #22: 저장 실패·복구·손상이 조용히 지나가지 않고 save_result 발화와 화면 안내
## 문구로 신호를 만드는지도 함께 실증한다.
## 실행: godot --headless --path . --script res://tools/save_probe.gd

var _fail := 0


func _initialize() -> void:
	print("=== keeum 세이브 내구성 검증 (#12) ===")
	# GameController 오토로드의 _ready() 는 이 스크립트의 _initialize() 뒤에 실행되므로
	# 여기서 먼저 막지 않으면 아래 _cleanup_files() 가 오토로드보다 먼저 실제 저장을
	# 지운다(#17). 격리 없이는 아무 파일도 건드리지 않고 즉시 거부한다.
	if not LocalSave.is_user_dir_isolated():
		push_error("save_probe: 저장 격리(%s)가 확인되지 않아 실제 저장을 건드리지 않고 거부한다" % LocalSave.TEST_ISOLATION_ENV)
		quit(1)
		return
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

	# 8) GameController: 저장 성공/실패마다 save_result 가 발화하고, 실패해도
	#    메모리 상태(profile/run)는 그대로 남아 재시도가 의미를 갖는다 — #22 AC-1·AC-2.
	_cleanup_files()
	var probe_controller := _fresh_controller()
	probe_controller.new_game({
		"name": "재시도", "gender": "neutral", "generation": 1, "seed": 20260913,
	})
	var save_signals: Array = []
	probe_controller.save_result.connect(func(ok: bool) -> void: save_signals.append(ok))
	var before_profile: Dictionary = probe_controller.profile.to_dict()
	var before_run: Dictionary = probe_controller.run.to_dict()
	dir.make_dir(LocalSave.TMP_PATH)
	_expect("실패 시 save_game() false 반환", not probe_controller.save_game())
	_expect("실패 시 save_result(false) 한 번 발화", save_signals == [false])
	_expect("실패해도 profile 메모리 보존", probe_controller.profile.to_dict() == before_profile)
	_expect("실패해도 run 메모리 보존", probe_controller.run.to_dict() == before_run)
	dir.remove(LocalSave.TMP_PATH)
	save_signals.clear()
	_expect("재시도 성공 시 save_game() true 반환", probe_controller.save_game())
	_expect("재시도 성공 시 save_result(true) 한 번 발화", save_signals == [true])
	probe_controller.free()

	# 9) main.gd: 로드 상태별 안내 문구는 corrupt/recovered 에서만 존재한다 — #22 AC-3.
	#    화면을 실제 트리에 넣지 않고도(스크립트만 인스턴스화) 순수 매핑을 검증한다.
	var main_probe: Control = load("res://game/ui/main.gd").new()
	_expect("정상 상태는 안내 없음", main_probe._load_notice_text(LocalSave.STATUS_OK).is_empty())
	_expect("첫 실행은 안내 없음", main_probe._load_notice_text(LocalSave.STATUS_EMPTY).is_empty())
	_expect(
		"복구 안내 문구 존재", not main_probe._load_notice_text(LocalSave.STATUS_RECOVERED).is_empty()
	)
	_expect(
		"손상 안내 문구 존재", not main_probe._load_notice_text(LocalSave.STATUS_CORRUPT).is_empty()
	)
	_expect(
		"상위 버전 안내 문구 존재",
		not main_probe._load_notice_text(LocalSave.STATUS_FUTURE_VERSION).is_empty()
	)
	main_probe.free()

	# 10) 스키마 버전 판독(#45): 무버전(v0)·현재 버전·상위 버전 세 픽스처 상태를 각각 검증한다.
	# 10-1) 무버전 픽스처: schema_version 키가 아예 없는 실제 구버전 세이브 모양.
	#       도감·프리미엄·마일리지·가챠 천장·회차 기록이 값 손실 없이 최신 구조로 올라와야 한다.
	_cleanup_files()
	var v0_blob := {
		"profile": {
			"premium": 777, "mileage": 12, "gacha_pity": 5,
			"ad_removed": true, "total_runs": 2,
			"ad_daily_key": "2026-09-01", "ad_daily_count": 1,
			"collected_endings": ["hanul_happy", "stable_calm"],
			"run_records": [{"ending_id": "hanul_happy", "turns": 20}],
			"owned_cosmetics": ["cap_basic"],
			"equipped": {"head": "cap_basic"},
		},
		"run": {},
	}
	_write_raw(LocalSave.SAVE_PATH, JSON.stringify(v0_blob, "\t"))
	var v0_controller := _fresh_controller()
	_expect("무버전 픽스처 status=ok", v0_controller.last_load_status == LocalSave.STATUS_OK)
	_expect("무버전 도감 손실 없음", v0_controller.profile.collected_endings == ["hanul_happy", "stable_calm"])
	_expect("무버전 프리미엄 손실 없음", v0_controller.profile.premium == 777)
	_expect("무버전 마일리지 손실 없음", v0_controller.profile.mileage == 12)
	_expect("무버전 가챠 천장 손실 없음", v0_controller.profile.gacha_pity == 5)
	_expect("무버전 회차 기록 손실 없음", v0_controller.profile.run_records.size() == 1)
	_expect("무버전 코스메틱 손실 없음", v0_controller.profile.owned_cosmetics == ["cap_basic"])
	_expect(
		"무버전 로드 후 최신 스키마로 승격 저장",
		int(LocalSave.load_data().get("schema_version", -1)) == SaveSchema.CURRENT_VERSION
	)
	v0_controller.free()

	# 10-2) 현재 버전 픽스처: 그대로 사용한다.
	_cleanup_files()
	var current_blob := {
		"schema_version": SaveSchema.CURRENT_VERSION, "profile": Profile.new().to_dict(), "run": {},
	}
	_write_raw(LocalSave.SAVE_PATH, JSON.stringify(current_blob, "\t"))
	var current_controller := _fresh_controller()
	_expect("현재 버전 픽스처 status=ok", current_controller.last_load_status == LocalSave.STATUS_OK)
	_expect("현재 버전 프로필 정상 로드", current_controller.profile.premium == Balance.START_PREMIUM)
	current_controller.free()

	# 10-3) 상위 버전 픽스처: 이 코드가 아는 것보다 높은 버전 — 기본값으로 덮지 않고
	#       기존 파일을 보존한 채 로드를 거부해야 한다.
	_cleanup_files()
	var future_blob := {
		"schema_version": SaveSchema.CURRENT_VERSION + 999,
		"profile": {"premium": 55555, "collected_endings": ["future_only_ending"]},
		"run": {},
	}
	var future_text := JSON.stringify(future_blob, "\t")
	_write_raw(LocalSave.SAVE_PATH, future_text)
	var future_controller := _fresh_controller()
	_expect("상위 버전 status=future_version", future_controller.last_load_status == LocalSave.STATUS_FUTURE_VERSION)
	_expect(
		"상위 버전은 기본값 프로필로 시작(미래 데이터로 덮지 않음)",
		future_controller.profile.collected_endings.is_empty())
	_expect("상위 버전은 회차 없음", future_controller.run == null)
	_expect(
		"상위 버전 파일 원본 그대로 보존",
		FileAccess.get_file_as_string(LocalSave.SAVE_PATH) == future_text)
	future_controller.free()

	# 10-4) keeum 세이브가 아닌 임의 Dictionary JSON 은 OK 로 판정되지 않는다.
	_cleanup_files()
	_write_raw(LocalSave.SAVE_PATH, JSON.stringify({"foo": "bar", "unrelated": 1}, "\t"))
	_expect(
		"임의 Dictionary 는 OK 가 아님",
		String(LocalSave.load_result()["status"]) != LocalSave.STATUS_OK)
	_cleanup_files()


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

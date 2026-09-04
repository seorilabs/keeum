extends Node
## 세션 매니저 오토로드. ContentDB·Profile(영속)·현재 GameRun 을 보유하고,
## UI 와 core 사이를 잇는다. 저장/복원, 엔딩 보상, 회차 전환을 담당한다.
## 어댑터(저장·분석)만 여기서 접근하고, 규칙은 전부 core 에 위임한다.

signal run_started
signal profile_changed
signal save_result(success: bool)  ## 저장 시도마다 발화(#22). 화면은 이걸로 실패 안내를 켜고 끈다.

var content: ContentDB
var profile: Profile
var run: GameRun
var last_selection: Dictionary = {}  # 지난 달 유지용 {a,b,bonus}
var last_load_status: String = LocalSave.STATUS_EMPTY  # 세이브 로드 결과(#12)

func _ready() -> void:
	content = ContentDB.new()
	if not content.load_all():
		push_error("GameController: 콘텐츠 로드 실패")
	# --ui-smoke/--ui-play 는 이 오토로드의 _ready() 가 main.gd 의 _ready() 보다 먼저
	# 실행되므로, 여기서 막지 않으면 라우터가 격리를 확인하기도 전에 실제 저장을
	# 읽거나 손상 격리로 덮어쓴다(#17). 빌드·임포트 등 다른 헤드리스 실행에는
	# 적용하지 않는다 — 기존 저장 경로·로드 동작을 바꾸지 않는다.
	if LocalSave.is_headless_ui_test_drive() and not LocalSave.is_user_dir_isolated():
		push_error("GameController: --ui-smoke/--ui-play 실행에 저장 격리(%s)가 없어 실제 저장을 보호하기 위해 거부한다" % LocalSave.TEST_ISOLATION_ENV)
		profile = Profile.new()
		get_tree().quit(1)
		return
	restore_from_disk()

## 세이브를 status 와 함께 한 번만 읽어 프로필·회차를 복원한다(#12).
## 손상 세이브는 격리해 증거로 남기고, 백업 복구본은 본 파일로 승격한다.
func restore_from_disk() -> void:
	var result := LocalSave.load_result()
	last_load_status = String(result.get("status", LocalSave.STATUS_EMPTY))
	var data: Dictionary = result.get("data", {})
	_load_profile(data)
	_load_run(data)
	match last_load_status:
		LocalSave.STATUS_CORRUPT:
			push_warning("GameController: 세이브 손상 — 원본을 격리하고 새 프로필로 시작")
			LocalSave.quarantine_corrupt()
		LocalSave.STATUS_RECOVERED:
			push_warning("GameController: 백업 세대에서 세이브 복구")
			_persist()

# ---------------------------------------------------------------- 프로필
func _load_profile(data: Dictionary) -> void:
	if data.has("profile"):
		profile = Profile.from_dict(data["profile"])
	else:
		profile = Profile.new()

func _load_run(data: Dictionary) -> void:
	run = null
	if data.has("run") and not (data["run"] as Dictionary).is_empty():
		run = GameRun.new()
		run.setup(content)
		run.load_from(data["run"])

func has_active_run() -> bool:
	return run != null and not run.is_final_turn()

# ---------------------------------------------------------------- 회차
func new_game(config: Dictionary) -> void:
	var cfg := config.duplicate()
	cfg["generation"] = profile.total_runs + 1
	run = GameRun.new()
	run.setup(content)
	run.start_new(cfg)
	save_game()
	track("raise_run_start", {"seed": run.child.seed, "temperament": run.child.temperament})
	run_started.emit()

func finish_run(ending: Dictionary) -> Dictionary:
	## 엔딩 보상·도감 등록·회차 기록. 반환: {"is_new": bool, "premium_reward": int}
	var summary := run.run_summary(ending)
	var is_new := profile.register_ending(str(ending.get("id", "")))
	var reward := 40 + (20 if is_new else 0)
	profile.add_premium(reward)
	profile.add_run_record(summary)
	run = null  # 회차 종료: 재실행 시 입시·엔딩 중복 처리 방지
	save_game()
	track("raise_ending", {
		"ending_id": summary["ending_id"], "turns": summary["turns"],
		"happiness": summary["emotion"],
	})
	profile_changed.emit()
	return {"is_new": is_new, "premium_reward": reward, "summary": summary}

func start_next_child() -> void:
	run = null
	_persist()

# ---------------------------------------------------------------- 저장
## 저장을 시도하고 성공 여부를 돌려준다(#22). 실패해도 이 메서드는 메모리의
## profile/run 을 전혀 건드리지 않으므로, 같은 호출을 다시 하는 것만으로 재시도가
## 성립한다.
func save_game() -> bool:
	return _persist()

func _persist() -> bool:
	var blob := {"profile": profile.to_dict()}
	if run != null:
		blob["run"] = run.to_dict()
	else:
		blob["run"] = {}
	return _write(blob)

## 실제 쓰기 관문. 성공 여부와 무관하게 매번 save_result 를 발화해 화면이
## 실패 배너를 켜고(false) 재시도 성공 시 끄도록(true) 한다.
func _write(blob: Dictionary) -> bool:
	var ok := LocalSave.save(blob)
	save_result.emit(ok)
	return ok

## 코스메틱 장착/해제(가챠 "바로 입히기"·홈 옷장). item="" 이면 해제.
func equip_cosmetic(slot: String, item: String) -> void:
	if item == "":
		profile.equipped.erase(slot)
	else:
		profile.equipped[slot] = item
	_persist()
	profile_changed.emit()

func reset_all() -> void:
	profile = Profile.new()
	run = null
	_write({"profile": profile.to_dict(), "run": {}})
	profile_changed.emit()

# ---------------------------------------------------------------- 분석(스텁)
func track(event_name: String, params: Dictionary = {}) -> void:
	# 실제 GA4 는 네이티브 플러그인 어댑터로 교체(06 문서). 현재는 로그 스텁.
	if OS.is_debug_build():
		print("[analytics] %s %s" % [event_name, JSON.stringify(params)])

# ---------------------------------------------------------------- 편의
func application_label(app: String) -> String:
	return str(content.applications.get(app, app))

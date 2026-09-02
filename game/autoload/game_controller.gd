extends Node
## 세션 매니저 오토로드. ContentDB·Profile(영속)·현재 GameRun 을 보유하고,
## UI 와 core 사이를 잇는다. 저장/복원, 엔딩 보상, 회차 전환을 담당한다.
## 어댑터(저장·분석)만 여기서 접근하고, 규칙은 전부 core 에 위임한다.

signal run_started
signal profile_changed

var content: ContentDB
var profile: Profile
var run: GameRun
var last_selection: Dictionary = {}  # 지난 달 유지용 {a,b,bonus}
var last_load_status: String = LocalSave.STATUS_EMPTY  # 세이브 로드 결과(#12)

func _ready() -> void:
	content = ContentDB.new()
	if not content.load_all():
		push_error("GameController: 콘텐츠 로드 실패")
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
func save_game() -> void:
	_persist()

func _persist() -> void:
	var blob := {"profile": profile.to_dict()}
	if run != null:
		blob["run"] = run.to_dict()
	else:
		blob["run"] = {}
	LocalSave.save(blob)

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
	LocalSave.save({"profile": profile.to_dict(), "run": {}})
	profile_changed.emit()

# ---------------------------------------------------------------- 분석(스텁)
func track(event_name: String, params: Dictionary = {}) -> void:
	# 실제 GA4 는 네이티브 플러그인 어댑터로 교체(06 문서). 현재는 로그 스텁.
	if OS.is_debug_build():
		print("[analytics] %s %s" % [event_name, JSON.stringify(params)])

# ---------------------------------------------------------------- 편의
func application_label(app: String) -> String:
	return str(content.applications.get(app, app))

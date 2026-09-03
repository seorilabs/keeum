class_name GameRun
extends RefCounted
## 한 회차의 코어 상태 머신 (엔진 독립).
##
## UI(Godot 화면)는 이 클래스의 메서드만 호출해 진행한다. 턴 배분 → 결과 → 학기말/
## 이벤트/전환기 인터루드 → 입시·엔딩까지 한 판 흐름을 관장한다. Godot·Firebase·광고·
## 결제 SDK 를 직접 import 하지 않는다.

const SCHEMA_VERSION := 1
const EVENT_CHANCE := 0.42
const PRESSURE_METHODS: Array[String] = ["spartan", "preemptive", "drill"]

var child: Child
var household: Household
var content: ContentDB
var rng := RandomNumberGenerator.new()

var turn_index := 0          # 전역 턴(0-base)
var stage_turn := 0          # 현재 단계 내 턴
var semester_turn := 0       # 학기(4턴) 카운터
var application := ""         # 원서 선택 (hanul/stable/art/free)
var exposed := false         # 유혹 적발 여부
var used_event_ids: Dictionary = {}   # once 이벤트 추적
var ad_boost_used_gate: Dictionary = {}  # 전환기별 광고 부스트 사용

var last_result: Dictionary = {}
var pending_ending: Dictionary = {}
var _steps: Array = []       # 인터루드 큐
var current_step: Dictionary = {}  # 화면에 떠 있는(아직 선택 미해결) 인터루드. 저장 대상(#16)

func setup(content_db: ContentDB) -> void:
	content = content_db

# ---------------------------------------------------------------- 생성
func start_new(config: Dictionary) -> void:
	var seed_val: int = int(config.get("seed", _make_seed(config)))
	rng.seed = seed_val
	child = Child.new()
	child.seed = seed_val
	child.id = "child_%d" % seed_val
	child.name = str(config.get("name", "아이"))
	child.gender = str(config.get("gender", "neutral"))
	child.appearance = config.get("appearance", {})
	child.stage = "infant"
	child.age = Balance.STAGE_START_AGE["infant"]

	# 선천 프로필 랜덤 생성 (적성은 가려진 상태로 시작).
	child.temperament = str(config.get("temperament", _roll_temperament()))
	for axis: String in Balance.APTITUDES:
		child.aptitude_grades[axis] = _roll_grade()
		child.aptitude_revealed[axis] = false
	child.mental_tolerance = rng.randi_range(35, 70)
	child.resilience = rng.randi_range(35, 70)
	child.constitution = rng.randi_range(35, 70)
	child.stamina = 55 + int(child.constitution / 10)
	child.emotion = 60
	child.stress = 15

	household = Household.new()
	household.generation = int(config.get("generation", 1))

	# 첫인상 보너스 — child·household 가 모두 만들어진 뒤에 적용해야
	# bonding·money 같은 가계 보정이 유실되지 않는다 (#11).
	var impression: Dictionary = config.get("impression", {})
	_apply_stat_bundle(impression)
	turn_index = 0
	stage_turn = 0
	semester_turn = 0
	application = ""
	exposed = false
	used_event_ids.clear()
	ad_boost_used_gate.clear()
	_steps.clear()
	current_step = {}

func _make_seed(config: Dictionary) -> int:
	var base := 0
	var name := str(config.get("name", "아이"))
	for i in name.length():
		base = base * 31 + name.unicode_at(i)
	base += int(config.get("generation", 1)) * 7919
	return abs(base) + 1

func _roll_temperament() -> String:
	return Balance.TEMPERAMENTS[rng.randi() % Balance.TEMPERAMENTS.size()]

func _roll_grade() -> String:
	# 중앙(C)에 몰린 분포. 극단 등급은 드물게.
	var r := rng.randf()
	if r < 0.08: return "A"
	elif r < 0.28: return "B"
	elif r < 0.72: return "C"
	elif r < 0.92: return "D"
	return "E"

# ---------------------------------------------------------------- 조회
func stage_total_turns() -> int:
	return int(Balance.STAGE_TURNS.get(child.stage, 1))

func current_age() -> int:
	var start: int = Balance.STAGE_START_AGE.get(child.stage, 4)
	var idx := Balance.STAGES.find(child.stage)
	var next_start := start + 1
	if idx >= 0 and idx < Balance.STAGES.size() - 1:
		next_start = int(Balance.STAGE_START_AGE.get(Balance.STAGES[idx + 1], start + 1))
	var span := maxi(1, next_start - start)
	var offset := int(float(stage_turn) / float(maxi(1, stage_total_turns())) * float(span))
	return mini(start + offset, next_start - 1) if next_start > start else start

func year_label() -> String:
	## "초등 3학년" 같은 표기 대신 단계 + 나이로 표기.
	return "%s · %d세" % [Balance.STAGE_NAME.get(child.stage, ""), current_age()]

## 슬롯(A=학습/B=여가)별 현재 단계에서 선택 가능한 활동 목록.
func available_activities(slot: String) -> Array:
	var list: Array = []
	var stage_idx := Balance.STAGES.find(child.stage)
	for act: Dictionary in content.activities:
		if str(act.get("slot", "")) != slot:
			continue
		var min_stage := str(act.get("stage_min", "infant"))
		if Balance.STAGES.find(min_stage) > stage_idx:
			continue
		list.append(act)
	return list

func is_final_turn() -> bool:
	return child.stage == "exam" and stage_turn >= stage_total_turns()

# ---------------------------------------------------------------- 턴 해결
## 슬롯 A(학습)·B(여가) + 선택적 보너스 슬롯(보상형 광고 주도)을 정산한다.
## 빈 문자열이면 슬롯 미사용.
func resolve_turn(slot_a_id: String, slot_b_id: String, bonus_id: String = "") -> Dictionary:
	var result := {
		"subjects": {}, "emotion": 0, "stamina": 0, "talent": 0,
		"bonding": 0, "stress": 0, "money": Balance.BASE_INCOME_PER_TURN,
		"revealed": [], "cards": [], "played": [],
	}
	household.add_money(Balance.BASE_INCOME_PER_TURN)
	for id: String in [slot_a_id, slot_b_id, bonus_id]:
		if id == "":
			continue
		_apply_activity(id, result)

	_apply_ambient(result)

	turn_index += 1
	stage_turn += 1
	semester_turn += 1
	last_result = result

	_build_interludes()
	return result

func _apply_activity(id: String, result: Dictionary) -> void:
	var act := content.activity(id)
	if act.is_empty():
		return
	# 비용을 전액 지불할 수 없는 활동은 성장·재화·기록 어느 것도 적용하지 않는다.
	# add_money 가 음수 잔액을 0으로 잘라내므로, 이 가드가 없으면 지불하지 않은
	# 성장 효과만 남는다. UI를 우회한 직접 호출도 여기서 막힌다.
	if int(act.get("cost", 0)) > 0 and not household.can_afford(int(act.get("cost", 0))):
		return
	result["cards"].append(act.get("name", id))
	result["played"].append({
		"id": id, "name": str(act.get("name", id)),
		"tag": str(act.get("tag", "")), "axis": str(act.get("axis", "leisure")),
	})
	var cost := int(act.get("cost", 0))
	if cost > 0:
		household.add_money(-cost)
		result["money"] = int(result["money"]) - cost

	if str(act.get("axis", "leisure")) == "learn":
		var lr := Growth.learn_result(act, child)
		for subject: String in lr["subjects"]:
			var d: int = lr["subjects"][subject]
			child.add_subject(subject, d)
			_accumulate_subject(result, subject, d)
		child.add_stress(int(lr["stress"]))
		result["stress"] = int(result["stress"]) + int(lr["stress"])
		for subject: String in act.get("subjects", []):
			for axis: String in child.reveal_aptitudes_for_subject(subject):
				result["revealed"].append(axis)
		# 학원 압박 → 정서·유대감 소폭 하락.
		if str(act.get("method", "")) in PRESSURE_METHODS:
			household.add_bonding(-2)
			child.add_emotion(-1)
			result["bonding"] = int(result["bonding"]) - 2
			result["emotion"] = int(result["emotion"]) - 1
	else:
		_apply_leisure(act, result)

func _apply_leisure(act: Dictionary, result: Dictionary) -> void:
	var emo := int(act.get("emotion", 0))
	var sta := int(act.get("stamina", 0))
	var tal := int(act.get("talent", 0))
	var bon := int(act.get("bonding", 0))
	var st := int(act.get("stress", 0))
	var mon := int(act.get("money", 0))
	child.add_emotion(emo); child.add_stamina(sta); child.add_talent(tal)
	child.add_stress(st); household.add_bonding(bon)
	if mon != 0:
		household.add_money(mon)
	result["emotion"] = int(result["emotion"]) + emo
	result["stamina"] = int(result["stamina"]) + sta
	result["talent"] = int(result["talent"]) + tal
	result["bonding"] = int(result["bonding"]) + bon
	result["stress"] = int(result["stress"]) + st
	result["money"] = int(result["money"]) + mon
	if bool(act.get("reveal_talent", false)):
		for axis: String in ["creative", "physical"]:
			if not child.is_aptitude_revealed(axis):
				child.aptitude_revealed[axis] = true
				result["revealed"].append(axis)

## 학령 압박·자연 드리프트. 단계가 오를수록 주변 스트레스가 쌓이고, 손 놓으면 정서·체력이
## 천천히 빠진다 → 여가·가족시간을 꾸준히 챙겨야 균형이 유지된다(스탯 무한 최대화 방지).
const AMBIENT_STRESS := {"infant": 0, "elementary": 1, "middle": 3, "high": 4, "exam": 5}

func _apply_ambient(result: Dictionary) -> void:
	var amb: int = AMBIENT_STRESS.get(child.stage, 1)
	if amb != 0:
		child.add_stress(amb)
		result["stress"] = int(result["stress"]) + amb
	child.add_emotion(-2)
	child.add_stamina(-2)
	result["emotion"] = int(result["emotion"]) - 2
	result["stamina"] = int(result["stamina"]) - 2

func _accumulate_subject(result: Dictionary, subject: String, delta: int) -> void:
	var subs: Dictionary = result["subjects"]
	subs[subject] = int(subs.get(subject, 0)) + delta

# ---------------------------------------------------------------- 인터루드 큐
func _build_interludes() -> void:
	_steps.clear()
	# 번아웃 우선. 아니면 확률로 일상/유혹 이벤트.
	if child.stress >= Balance.BURNOUT_THRESHOLD:
		_steps.append({"screen": "event", "event": _burnout_event()})
	else:
		var ev := _roll_event()
		if not ev.is_empty():
			_steps.append({"screen": "event", "event": ev})

	if semester_turn >= Balance.TURNS_PER_SEMESTER:
		semester_turn = 0
		_steps.append({"screen": "term"})

	# 단계 경계 처리.
	if stage_turn >= stage_total_turns():
		_handle_stage_boundary()

func _handle_stage_boundary() -> void:
	var idx := Balance.STAGES.find(child.stage)
	if idx < 0 or idx >= Balance.STAGES.size() - 1:
		# 마지막(입시) 단계 종료 → 원서·엔딩.
		_steps.append({"screen": "application"})
		return
	var next_stage := Balance.STAGES[idx + 1]
	var gate := "%s_%s" % [child.stage, next_stage]
	var transition := content.transition_for_gate(gate)
	if transition.is_empty():
		# 전환기 이벤트 없는 경계(고등→입시)는 즉시 진급.
		_advance_stage()
	else:
		_steps.append({"screen": "transition", "transition": transition})

func _advance_stage() -> void:
	var idx := Balance.STAGES.find(child.stage)
	if idx >= 0 and idx < Balance.STAGES.size() - 1:
		child.stage = Balance.STAGES[idx + 1]
		child.age = Balance.STAGE_START_AGE.get(child.stage, child.age)
		stage_turn = 0
		semester_turn = 0

## UI가 결과 확인 후 다음 인터루드를 요청. 큐가 비면 홈(다음 턴).
## 반환한 항목을 current_step 에 남겨 화면 재진입 전 종료돼도(#16) 복원 시
## 같은 항목으로 돌아갈 수 있게 한다. 선택 해결(resolve_event/resolve_transition)이
## current_step 을 지운다.
func next_step() -> Dictionary:
	if _steps.is_empty():
		current_step = {}
		return {"screen": "home"}
	current_step = _steps.pop_front()
	return current_step

func has_steps() -> bool:
	return not _steps.is_empty()

# ---------------------------------------------------------------- 이벤트
func _roll_event() -> Dictionary:
	if rng.randf() > EVENT_CHANCE:
		return {}
	var pool: Array = []
	var stage_idx := Balance.STAGES.find(child.stage)
	for ev: Dictionary in content.events:
		if str(ev.get("category", "")) == "burnout":
			continue
		var trig: Dictionary = ev.get("trigger", {})
		if bool(trig.get("once", false)) and used_event_ids.has(str(ev.get("id", ""))):
			continue
		var smin := str(trig.get("stage_min", "infant"))
		var smax := str(trig.get("stage_max", "exam"))
		if stage_idx < Balance.STAGES.find(smin) or stage_idx > Balance.STAGES.find(smax):
			continue
		if child.stress < int(trig.get("stress_min", 0)):
			continue
		if child.stress > int(trig.get("stress_max", 100)):
			continue
		var w := int(trig.get("weight", 1))
		for i in w:
			pool.append(ev)
	if pool.is_empty():
		return {}
	var chosen: Dictionary = pool[rng.randi() % pool.size()]
	if bool(chosen.get("trigger", {}).get("once", false)):
		used_event_ids[str(chosen.get("id", ""))] = true
	return chosen

func _burnout_event() -> Dictionary:
	return {
		"id": "burnout_generic", "category": "burnout", "title": "번아웃",
		"body": "아이가 책상 앞에서 멍하니 무너져 있어요. 더는 버틸 수 없다는 신호예요.",
		"choices": [
			{"label": "모든 걸 멈추고 쉬게 하기",
			 "effects": {"stress": -35, "emotion": 10, "bonding": 6, "stamina": 8},
			 "result": "며칠을 푹 쉬게 했어요. 조금씩 아이 얼굴에 화색이 돌아와요."},
			{"label": "그래도 조금만 더 밀어붙이기",
			 "effects": {"stress": 4, "emotion": -8, "bonding": -8, "subject": {"strongest": 4}},
			 "result": "억지로 앉혔지만 눈빛이 텅 비어가요. 마음의 거리가 멀어져요."}
		]
	}

## 이벤트 선택 해결. 반환: {"applied":..., "text":..., "exposure":bool}
func resolve_event(event: Dictionary, choice_index: int) -> Dictionary:
	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"text": "", "exposure": false}
	var choice: Dictionary = choices[choice_index]
	var out := {"text": str(choice.get("result", "")), "exposure": false, "applied": {}}

	if choice.has("temptation"):
		out = _apply_temptation(event, choice, out)
	elif choice.has("reject"):
		_apply_stat_bundle(choice.get("reject", {}))
		out["applied"] = choice.get("reject", {})
	else:
		_apply_stat_bundle(choice.get("effects", {}))
		out["applied"] = choice.get("effects", {})
	current_step = {}  # 선택 적용 완료 — 재시작 시 같은 이벤트를 다시 보여주지 않는다(#16)
	return out

func _apply_temptation(event: Dictionary, choice: Dictionary, out: Dictionary) -> Dictionary:
	var tid := str(event.get("temptation_id", "unknown"))
	var state := household.temptation(tid)
	var uses := int(state["uses"])
	var efficiency: float = maxf(0.4, 1.0 - 0.15 * float(uses))  # 내성: 반복 사용 효율 하락
	var t: Dictionary = choice["temptation"]

	var immediate: Dictionary = t.get("immediate", {})
	_apply_stat_bundle(immediate, efficiency)
	if t.has("money"):
		household.add_money(int(t["money"]))

	state["uses"] = uses + 1
	state["dependency"] = int(state["dependency"]) + int(t.get("dependency", 1))
	var risk_gain := int(t.get("risk", 20)) + int(state["dependency"]) * 5  # 의존↑ → 리스크↑
	state["risk"] = int(state["risk"]) + risk_gain
	household.add_bonding(-2)
	child.add_emotion(-2)

	if int(state["risk"]) >= 100 and not exposed:
		exposed = true
		# 적발 부작용: 성적 급락·건강 악화·평판 붕괴.
		for subject: String in ["korean", "english", "math", "science", "social"]:
			child.add_subject(subject, -25)
		child.add_emotion(-15)
		child.add_stress(20)
		household.add_bonding(-15)
		out["exposure"] = true
		out["text"] = str(out["text"]) + "\n\n결국 덜미가 잡혔어요. 성적도, 신뢰도, 모든 게 무너져 내려요."
	out["applied"] = immediate
	return out

# ---------------------------------------------------------------- 스탯 번들 적용
## effects 딕셔너리를 해석해 스탯에 반영. scale 은 유혹 효율 등.
func _apply_stat_bundle(effects: Dictionary, scale: float = 1.0) -> void:
	if effects.has("emotion"): child.add_emotion(_scaled(effects["emotion"], scale))
	if effects.has("stamina"): child.add_stamina(_scaled(effects["stamina"], scale))
	if effects.has("talent"): child.add_talent(_scaled(effects["talent"], scale))
	if effects.has("stress"): child.add_stress(_scaled(effects["stress"], scale))
	if effects.has("mental"): child.mental_tolerance = clampi(child.mental_tolerance + int(effects["mental"]), 0, 100)
	if effects.has("constitution"): child.constitution = clampi(child.constitution + int(effects["constitution"]), 0, 100)
	if effects.has("bonding"): household.add_bonding(_scaled(effects["bonding"], scale))
	if effects.has("money"): household.add_money(int(effects["money"]))
	if effects.has("reveal"):
		child.aptitude_revealed[str(effects["reveal"])] = true
	if effects.has("subject"):
		_apply_subject_effects(effects["subject"], scale)

func _scaled(v: Variant, scale: float) -> int:
	return int(round(float(v) * scale))

func _apply_subject_effects(spec: Dictionary, scale: float) -> void:
	for key: String in spec:
		var delta := _scaled(spec[key], scale)
		match key:
			"all":
				for s: String in ["korean", "english", "math", "science", "social"]:
					child.add_subject(s, delta)
			"weakest":
				child.add_subject(_extreme_subject(true), delta)
			"strongest":
				child.add_subject(_extreme_subject(false), delta)
			_:
				child.add_subject(key, delta)

func _extreme_subject(weakest: bool) -> String:
	var target := "korean"
	var extreme := child.subject_value("korean")
	for s: String in ["english", "math", "science", "social"]:
		var v := child.subject_value(s)
		if weakest and v < extreme:
			extreme = v; target = s
		elif not weakest and v > extreme:
			extreme = v; target = s
	return target

# ---------------------------------------------------------------- 전환기
## 성공 확률(0~1). AC-007: 유대감 단조 증가, 광고 부스트 +20%p.
func transition_success_chance(transition: Dictionary, with_ad_boost: bool) -> float:
	var difficulty := float(transition.get("difficulty", 0.0))
	var base := 0.08 + float(household.bonding) * 0.0095 + float(child.emotion - 50) * 0.0012 - difficulty
	if with_ad_boost:
		base += 0.20
	return clampf(base, 0.05, 0.95)

func can_use_ad_boost(transition: Dictionary) -> bool:
	return not ad_boost_used_gate.has(str(transition.get("gate", "")))

func resolve_transition(transition: Dictionary, option_index: int, use_ad_boost: bool) -> Dictionary:
	var options: Array = transition.get("options", [])
	var target := ""
	if option_index >= 0 and option_index < options.size():
		target = str(options[option_index].get("target", ""))
	if use_ad_boost:
		ad_boost_used_gate[str(transition.get("gate", ""))] = true
	var chance := transition_success_chance(transition, use_ad_boost)
	var success := rng.randf() < chance
	if success and target != "":
		child.temperament = target
		household.add_bonding(3)
		if bool(transition.get("reveal_latent", false)):
			_bloom_latent_aptitude()
	else:
		# 하드 실패 없음: 소폭 위로 + 성향 유지.
		household.add_bonding(1)
		child.add_emotion(2)
	_advance_stage()
	current_step = {}  # 선택 적용 완료 — 재시작 시 같은 전환기를 다시 보여주지 않는다(#16)
	return {
		"success": success, "chance": chance, "target": target,
		"target_name": Balance.TEMPERAMENT_NAME.get(target, ""),
	}

func _bloom_latent_aptitude() -> void:
	# 가장 낮은 적성 하나를 한 등급 개화.
	var worst := ""
	var worst_idx := -1
	for axis: String in Balance.APTITUDES:
		var g := str(child.aptitude_grades.get(axis, "C"))
		var gi := Balance.GRADES.find(g)
		if gi > worst_idx:
			worst_idx = gi; worst = axis
	if worst != "" and worst_idx > 0:
		child.aptitude_grades[worst] = Balance.GRADES[worst_idx - 1]
		child.aptitude_revealed[worst] = true

# ---------------------------------------------------------------- 입시·엔딩
func set_application(app: String) -> void:
	application = app

func determine_ending() -> Dictionary:
	var academic := child.academic_average()
	for ending: Dictionary in content.endings:
		if _ending_matches(ending, academic):
			pending_ending = ending
			return ending
	pending_ending = content.endings[content.endings.size() - 1]
	return pending_ending

func _ending_matches(ending: Dictionary, academic: int) -> bool:
	var req: Dictionary = ending.get("requires", {})
	if req.has("exposed") and bool(req["exposed"]) != exposed:
		return false
	if req.has("applied") and str(req["applied"]) != application:
		return false
	if req.has("academic_min") and academic < int(req["academic_min"]):
		return false
	if req.has("emotion_min") and child.emotion < int(req["emotion_min"]):
		return false
	if req.has("stress_max") and child.stress > int(req["stress_max"]):
		return false
	if req.has("talent_min") and child.talent < int(req["talent_min"]):
		return false
	if req.has("bonding_min") and household.bonding < int(req["bonding_min"]):
		return false
	if req.has("temptation_max") and household.total_temptation_uses() > int(req["temptation_max"]):
		return false
	return true

## 엔딩 확정 후 요약 딕셔너리. Profile 반영은 GameController가 수행.
func run_summary(ending: Dictionary) -> Dictionary:
	return {
		"ending_id": str(ending.get("id", "")),
		"ending_title": str(ending.get("title", "")),
		"university": str(ending.get("university", "")),
		"generation": household.generation,
		"turns": turn_index,
		"academic": child.academic_average(),
		"emotion": child.emotion,
		"stress": child.stress,
		"bonding": household.bonding,
		"talent": child.talent,
		"exposed": exposed,
		"child_name": child.name,
	}

# ---------------------------------------------------------------- 저장/복원
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"child": child.to_dict(),
		"household": household.to_dict(),
		"turn_index": turn_index,
		"stage_turn": stage_turn,
		"semester_turn": semester_turn,
		"application": application,
		"exposed": exposed,
		"used_event_ids": used_event_ids.duplicate(),
		"ad_boost_used_gate": ad_boost_used_gate.duplicate(),
		"rng_seed": int(rng.seed),
		"rng_state": int(rng.state),
		"steps": _steps.duplicate(true),
		"current_step": current_step.duplicate(true),
	}

func load_from(d: Dictionary) -> void:
	child = Child.from_dict(d.get("child", {}))
	household = Household.from_dict(d.get("household", {}))
	turn_index = int(d.get("turn_index", 0))
	stage_turn = int(d.get("stage_turn", 0))
	semester_turn = int(d.get("semester_turn", 0))
	application = str(d.get("application", ""))
	exposed = bool(d.get("exposed", false))
	used_event_ids = d.get("used_event_ids", {})
	ad_boost_used_gate = d.get("ad_boost_used_gate", {})
	rng.seed = int(d.get("rng_seed", 0))
	rng.state = int(d.get("rng_state", rng.state))
	_steps = d.get("steps", [])
	current_step = d.get("current_step", {})

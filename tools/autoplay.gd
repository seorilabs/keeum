extends SceneTree
## 헤드리스 검증. 한 판 완주 가능성 + 성장 공식(AC-001~003)을 실증한다.
## 실행: godot --headless --script res://tools/autoplay.gd
## UI 없이 core(GameRun)를 균형 전략 AI로 구동해 유아→입시→엔딩까지 완주한다.

var _fail := 0

func _initialize() -> void:
	print("=== keeum autoplay 검증 ===")
	_check_growth_formula()
	_check_cost_invariants()
	_play_full_round()
	if _fail == 0:
		print("\n✅ 모든 검증 통과")
	else:
		print("\n❌ 실패 %d건" % _fail)
	quit(_fail)

# ---------------------------------------------------------------- AC-001~003
func _check_growth_formula() -> void:
	print("\n[성장 공식] AC-001~003")
	# AC-001 성실형(수리B·이해C), stress30, 단과수학×스파르타 → Δ수학 +22, ΔStress +12
	var c1 := _make_child("diligent", {"math": "B", "understanding": "C"}, 50, 30)
	var r1 := Growth.learn_result(_act("specialty", "spartan", ["math"]), c1)
	_expect("AC-001 Δ수학", int(r1["subjects"].get("math", 0)), 22)
	_expect("AC-001 ΔStress", int(r1["stress"]), 12)

	# AC-002 산만형(수리A·이해C), 동일 → Δ수학 +13, ΔStress +18
	var c2 := _make_child("distracted", {"math": "A", "understanding": "C"}, 50, 30)
	var r2 := Growth.learn_result(_act("specialty", "spartan", ["math"]), c2)
	_expect("AC-002 Δ수학", int(r2["subjects"].get("math", 0)), 13)
	_expect("AC-002 ΔStress", int(r2["stress"]), 18)

	# AC-003 산만형이 체험·게임화(K0.45, 궁합1.3) → Δ수학 +9, ΔStress −4
	var c3 := _make_child("distracted", {"math": "A", "understanding": "C"}, 50, 30)
	var r3 := Growth.learn_result(_act("specialty", "experience", ["math"]), c3)
	_expect("AC-003 Δ수학", int(r3["subjects"].get("math", 0)), 9)
	_expect("AC-003 ΔStress", int(r3["stress"]), -4)

func _make_child(temper: String, grades: Dictionary, mental: int, stress: int) -> Child:
	var c := Child.new()
	c.temperament = temper
	for axis: String in Balance.APTITUDES:
		c.aptitude_grades[axis] = grades.get(axis, "C")
	c.mental_tolerance = mental
	c.stress = stress
	c.emotion = 60
	c.stamina = 55
	return c

func _act(institution: String, method: String, subjects: Array) -> Dictionary:
	return {"axis": "learn", "institution": institution, "method": method, "subjects": subjects}

func _expect(label: String, got: int, want: int) -> void:
	if got == want:
		print("  ✓ %s = %d" % [label, got])
	else:
		print("  ✗ %s = %d (기대 %d)" % [label, got, want])
		_fail += 1

# ---------------------------------------------------------------- 비용 불변식 (#8)
## 비용을 전액 지불할 수 없는 활동은 성장·재화·턴 기록에 부분 적용되지 않아야 한다.
## add_money 의 0 하한 때문에 가드가 없으면 "지불 없는 성장"이 남는 회귀를 고정한다.
func _check_cost_invariants() -> void:
	print("\n[비용 불변식] 무료 성장 차단 (#8)")
	var content := ContentDB.new()
	if not content.load_all():
		print("  ✗ 콘텐츠 로드 실패"); _fail += 1; return

	# 1) 재력 0 + 보너스 슬롯 final_intensive(비용 200) → 무료 성장 차단.
	var run := _fresh_run(content)
	run.household.money = 0
	var academic_before := run.child.academic_average()
	var r1 := run.resolve_turn("", "", "final_intensive")
	_expect("재력0 보너스 비용200: played 수", (r1["played"] as Array).size(), 0)
	_expect("재력0 보너스 비용200: 성적 불변", run.child.academic_average(), academic_before)
	_expect("재력0 보너스 비용200: 잔액=기본수입만", run.household.money, Balance.BASE_INCOME_PER_TURN)

	# 2) 개별로는 가능해도 순차 잔액이 모자란 활동은 통째로 미적용.
	#    재력 60: 수입 50 합산 110 < specialty_math_spartan(120) → A 미적용,
	#    남은 110 >= family_outing(60) → B 만 적용.
	run = _fresh_run(content)
	run.child.stage = "elementary"
	run.household.money = 60
	var r2 := run.resolve_turn("specialty_math_spartan", "family_outing", "")
	var played_ids: Array[String] = []
	for p: Dictionary in r2["played"]:
		played_ids.append(str(p.get("id", "")))
	_expect("합산 초과: 미지불 학습 미적용", 1 if not played_ids.has("specialty_math_spartan") else 0, 1)
	_expect("합산 초과: 지불 가능한 여가만 적용", 1 if played_ids.has("family_outing") else 0, 1)
	_expect("합산 초과: 잔액 정합", run.household.money, 60 + Balance.BASE_INCOME_PER_TURN - 60)

	# 3) 정상 조합: 기본 수입 1회 + 비용 1회 차감, 성장 유지.
	run = _fresh_run(content)
	run.household.money = Balance.START_MONEY
	var r3 := run.resolve_turn("home_reading", "nature_play", "")
	_expect("정상 조합: played 수", (r3["played"] as Array).size(), 2)
	_expect("정상 조합: 수입·비용 각 1회",
		run.household.money, Balance.START_MONEY + Balance.BASE_INCOME_PER_TURN - 30)

func _fresh_run(content: ContentDB) -> GameRun:
	var run := GameRun.new()
	run.setup(content)
	run.start_new({"name": "검산", "gender": "neutral", "generation": 1, "seed": 20260901})
	return run

# ---------------------------------------------------------------- 완주
func _play_full_round() -> void:
	print("\n[완주 시뮬] 균형 전략으로 유아→입시→엔딩")
	var content := ContentDB.new()
	if not content.load_all():
		print("  ✗ 콘텐츠 로드 실패"); _fail += 1; return
	var run := GameRun.new()
	run.setup(content)
	run.start_new({"name": "한결", "gender": "neutral", "generation": 1, "seed": 20260725})
	print("  아이: %s / 기질 %s / 멘탈 %d" % [run.child.name, Balance.TEMPERAMENT_NAME[run.child.temperament], run.child.mental_tolerance])

	var ending := {}
	var guard := 0
	while guard < 120:
		guard += 1
		var a := _pick_learn(run)
		var b := _pick_leisure(run)
		run.resolve_turn(a, b)
		while run.has_steps():
			var step := run.next_step()
			match str(step.get("screen", "")):
				"event":
					var ev: Dictionary = step["event"]
					run.resolve_event(ev, _event_choice(ev))
				"transition":
					run.resolve_transition(step["transition"], 0, false)
				"application":
					run.set_application("stable")
					ending = run.determine_ending()
		if not ending.is_empty():
			break

	if ending.is_empty():
		print("  ✗ 엔딩 미도달 (턴 %d)" % run.turn_index); _fail += 1; return
	print("  완주! 턴 %d / 단계 %s" % [run.turn_index, run.child.stage])
	print("  최종 성적평균 %d · 정서 %d · 스트레스 %d · 유대감 %d · 특기 %d" % [
		run.child.academic_average(), run.child.emotion, run.child.stress, run.household.bonding, run.child.talent])
	print("  엔딩: 「%s」 (%s)" % [ending.get("title", ""), ending.get("university", "")])
	if run.turn_index < 40 or run.turn_index > 60:
		print("  ✗ 턴 수 비정상 (%d, 기대 약 48)" % run.turn_index); _fail += 1
	else:
		print("  ✓ 턴 수 정상 범위(%d)" % run.turn_index)

	_check_save_roundtrip(run)

func _check_save_roundtrip(run: GameRun) -> void:
	# AC-006: 직렬화 왕복 후 스탯 동일
	var content := run.content
	var blob := run.to_dict()
	var text := JSON.stringify(blob)
	var restored: Dictionary = JSON.parse_string(text)
	var run2 := GameRun.new()
	run2.setup(content)
	run2.load_from(restored)
	var ok := run2.child.academic_average() == run.child.academic_average() \
		and run2.child.stress == run.child.stress \
		and run2.household.bonding == run.household.bonding \
		and run2.turn_index == run.turn_index
	if ok:
		print("  ✓ 저장 왕복 복원 일치(AC-006)")
	else:
		print("  ✗ 저장 왕복 불일치"); _fail += 1

func _pick_learn(run: GameRun) -> String:
	var opts := run.available_activities("A")
	var best := ""
	var best_score := -9999.0
	for act: Dictionary in opts:
		var cost := int(act.get("cost", 0))
		if not run.household.can_afford(cost):
			continue
		var lr := Growth.learn_result(act, run.child)
		var gain := 0
		for s: String in lr["subjects"]:
			gain += int(lr["subjects"][s])
		var stress := int(lr["stress"])
		# 스트레스가 높으면 저부하 활동 선호(균형 전략).
		var score := float(gain) - float(stress) * (1.4 if run.child.stress > 55 else 0.5)
		if score > best_score:
			best_score = score; best = str(act.get("id", ""))
	# 너무 지쳤으면 학습을 쉰다.
	if run.child.stress > 78:
		return ""
	return best

func _pick_leisure(run: GameRun) -> String:
	var opts := run.available_activities("B")
	var ids: Array[String] = []
	for act: Dictionary in opts:
		if run.household.can_afford(int(act.get("cost", 0))):
			ids.append(str(act.get("id", "")))
	if run.child.stress > 60 and ids.has("rest_home"):
		return "rest_home"
	if run.household.bonding < 55 and ids.has("family_talk"):
		return "family_talk"
	if ids.has("nature_play"):
		return "nature_play"
	if ids.has("family_outing"):
		return "family_outing"
	return ids[0] if not ids.is_empty() else ""

func _event_choice(ev: Dictionary) -> int:
	var choices: Array = ev.get("choices", [])
	# 유혹은 거절(마지막 선택지), 그 외는 첫 번째(대개 다정한 선택).
	if str(ev.get("category", "")) == "temptation":
		return choices.size() - 1
	return 0

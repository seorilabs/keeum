class_name UIHarness
extends RefCounted
## --ui-smoke / --ui-play 테스트 드라이버(main 라우터에서 분리).
## 헤드리스에서는 main 이 FX.force_reduced 를 켜 연출이 즉시 경로를 타므로 타이밍이 결정적이다.
## --shots <dir> 를 주면 각 화면을 PNG 로 캡처(비헤드리스 실 GL 필요).

var main: Control

func _init(p_main: Control) -> void:
	main = p_main

## 실 UI 완주: 각 화면의 실제 행동을 프로그램적으로 눌러 유아→입시→엔딩→도감까지 이어본다.
func run_play() -> void:
	print("=== UI 완주 드라이브 ===")
	GameController.new_game({
		"name": "온유", "gender": "son", "impression": {},
		"appearance": {"hair": "short_black", "outfit": "7FA9D9"},
	})
	main.goto("home")
	var guard := 0
	while guard < 400:
		guard += 1
		await main.get_tree().process_frame
		var s: UIScreen = main.current_screen()
		if s is CodexScreen:
			print("  ✓ 도감 도달 — 완주 성공")
			break
		elif s is HomeScreen:
			main.goto("activity")
		elif s is ActivityScreen:
			var run: GameRun = GameController.run
			s.set("_a", _drive_learn(run))
			s.set("_b", _drive_leisure(run))
			s.call("_confirm")
		elif s is ResultScreen or s is TermScreen:
			main.advance_step()
		elif s is EventScreen:
			var ev: Dictionary = s.get("_event")
			var idx := 0
			if str(ev.get("category", "")) == "temptation":
				idx = int((ev.get("choices", []) as Array).size()) - 1
			s.call("_on_choice", idx)
			main.advance_step()
		elif s is TransitionScreen:
			s.call("_resolve", 0)
			main.advance_step()
		elif s is ApplicationScreen:
			s.call("_choose", "stable")
		elif s is EndingScreen:
			main.goto("codex")
		else:
			await main.get_tree().process_frame
	print("=== UI 완주 완료 (엔딩 등록 %d개) ===" % GameController.profile.collected_endings.size())
	main.get_tree().quit(0)

func _drive_learn(run: GameRun) -> String:
	if run.child.stress > 78:
		return ""
	var best := ""
	var best_score := -9999.0
	for act: Dictionary in run.available_activities("A"):
		if not run.household.can_afford(int(act.get("cost", 0))):
			continue
		var lr := Growth.learn_result(act, run.child)
		var gain := 0
		for k: String in lr["subjects"]:
			gain += int(lr["subjects"][k])
		var score := float(gain) - float(int(lr["stress"])) * (1.4 if run.child.stress > 55 else 0.5)
		if score > best_score:
			best_score = score; best = str(act.get("id", ""))
	return best

func _drive_leisure(run: GameRun) -> String:
	var ids: Array[String] = []
	for act: Dictionary in run.available_activities("B"):
		if run.household.can_afford(int(act.get("cost", 0))):
			ids.append(str(act.get("id", "")))
	if run.child.stress > 60 and ids.has("rest_home"):
		return "rest_home"
	if run.household.bonding < 55 and ids.has("family_talk"):
		return "family_talk"
	if ids.has("nature_play"):
		return "nature_play"
	return ids[0] if not ids.is_empty() else ""

## 헤드리스/비헤드리스 UI 스모크: 모든 화면이 런타임 에러 없이 빌드되는지 검사.
func run_smoke() -> void:
	print("=== UI 스모크 ===")
	GameController.new_game({
		"name": "스모크", "gender": "daughter", "impression": {},
		"appearance": {"hair": "twin_tail", "outfit": "F28C79"},
	})
	var run: GameRun = GameController.run
	var a := str((run.available_activities("A")[0] as Dictionary).get("id", ""))
	var b := str((run.available_activities("B")[0] as Dictionary).get("id", ""))

	var pre := [["onboarding", null], ["home", null], ["activity", null]]
	for c: Array in pre:
		await _visit(str(c[0]), c[1])

	var result := run.resolve_turn(a, b)
	var cases := [
		["result", result], ["term", null], ["event", run.content.events[1]],
		["transition", run.content.transitions[0]], ["application", null],
		["ending", run.content.endings[1]], ["codex", null], ["shop", null],
		["gacha", null], ["settings", null],
	]
	for c: Array in cases:
		await _visit(str(c[0]), c[1])

	# 가챠 리브얼 경로 커버(0 비용 디버그 뽑기 1회)
	main.goto("gacha")
	await _settle(0.5)
	var gs: UIScreen = main.current_screen()
	if gs is GachaScreen:
		gs.call("_pull", 1, 0)
		await _settle(1.6)
		_maybe_shot("gacha_reveal")
		print("  ✓ gacha reveal")

	# 활동 장면 갤러리 — 태그별 연출 캡처
	if _shots_dir() != "":
		GameController.run = run  # 엔딩 케이스에서 회차가 종료됐으므로 복원
		var samples := ["specialty_math_spartan", "nature_play", "family_talk",
			"rest_home", "art_music", "sport_class", "part_time_job", "tutor_deep", "home_reading"]
		for id: String in samples:
			var act := run.content.activity(id)
			if act.is_empty():
				continue
			main.goto("result", _fake_result(act))
			await _settle(0.7)
			_maybe_shot("scene_" + str(act.get("tag", "x")))
			print("  ✓ scene ", act.get("tag", ""))

	print("=== UI 스모크 완료 ===")
	main.get_tree().quit(0)

func _fake_result(act: Dictionary) -> Dictionary:
	return {
		"subjects": {}, "emotion": 4, "stamina": 3, "talent": 2, "bonding": 3,
		"stress": -2, "money": Balance.BASE_INCOME_PER_TURN, "revealed": [],
		"cards": [act.get("name", "")],
		"played": [{"name": act.get("name", ""), "tag": act.get("tag", ""), "axis": act.get("axis", "leisure")}],
	}

func _visit(name: String, data: Variant) -> void:
	main.goto(name, data)
	await _settle(0.55)
	_maybe_shot(name)
	print("  ✓ %s (fps=%d nodes=%d draws=%d)" % [name,
		int(Engine.get_frames_per_second()),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func _wait_frames(n: int) -> void:
	for _i in n:
		await main.get_tree().process_frame

## 캡처 안정화 대기: 연출이 살아 있는 실 GL 런은 실시간, 헤드리스(즉시 경로)는 프레임 수.
func _settle(sec: float) -> void:
	if FX.reduced():
		await _wait_frames(6)
	else:
		await main.get_tree().create_timer(sec).timeout

func _shots_dir() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return ""

func _maybe_shot(name: String) -> void:
	var dir := _shots_dir()
	if dir == "":
		return
	var img := main.get_viewport().get_texture().get_image()
	if img == null:
		return
	img.save_png("%s/%s.png" % [dir, name])

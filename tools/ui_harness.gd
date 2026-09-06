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
	var learn_activities: Array = run.available_activities("A")
	var leisure_activities: Array = run.available_activities("B")
	if learn_activities.is_empty() or leisure_activities.is_empty() \
			or run.content.events.size() < 2 \
			or run.content.transitions.is_empty() \
			or run.content.endings.size() < 2:
		push_error("UIHarness: 필수 스모크 콘텐츠가 없거나 불완전합니다")
		main.get_tree().quit(1)
		return
	var a := str((learn_activities[0] as Dictionary).get("id", ""))
	var b := str((leisure_activities[0] as Dictionary).get("id", ""))

	var pre := [["onboarding", null], ["home", null], ["activity", null]]
	for c: Array in pre:
		await _visit(str(c[0]), c[1])

	if not await _check_combined_cost_gate():
		return

	var result := run.resolve_turn(a, b)
	var cases := [
		["result", result], ["term", null], ["event", run.content.events[1]],
		["transition", run.content.transitions[0]], ["application", null],
		["ending", run.content.endings[1]], ["codex", null], ["shop", null],
		["gacha", null], ["mileage_exchange", null], ["settings", null],
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

	if not await _check_mileage_exchange():
		return

	if not await _check_shop_pricing_gate():
		return

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

## #8 회귀: 카드 각각은 구매 가능해도 A+B(+보너스) 합산 비용이 재력을 넘으면
## 결정 버튼이 비활성화되고, 지불 가능한 조합으로 돌아오면 다시 열려야 한다.
func _check_combined_cost_gate() -> bool:
	main.goto("activity")
	await _settle(0.4)
	var s: UIScreen = main.current_screen()
	if not (s is ActivityScreen):
		push_error("UIHarness: activity 화면 진입 실패")
		main.get_tree().quit(1)
		return false
	var run: GameRun = GameController.run
	var money_before: int = run.household.money
	run.household.money = 130
	s.set("_a", "specialty_math_spartan")  # 비용 120 — 단독으로는 구매 가능
	s.set("_b", "family_outing")           # 비용 60 — 단독 가능, 합산 180 > 130
	s.call("_refresh")
	var confirm: Button = s.get("_confirm_btn")
	if confirm == null or not confirm.disabled:
		push_error("UIHarness: 합산 초과 조합인데 결정 버튼이 막히지 않았습니다 (#8)")
		main.get_tree().quit(1)
		return false
	s.set("_a", "")  # 합산 60 ≤ 130 → 다시 확정 가능해야 한다
	s.call("_refresh")
	if confirm.disabled:
		push_error("UIHarness: 지불 가능한 조합인데 결정 버튼이 막혀 있습니다 (#8)")
		main.get_tree().quit(1)
		return false
	s.set("_b", "")
	s.call("_refresh")
	run.household.money = money_before
	print("  ✓ 합산 비용 확정 차단 (#8)")
	return true

## #23 회귀: 마일리지가 부족하면 교환 버튼이 막히고, 충분하면 실제 교환이
## 마일리지를 정확히 깎고 코스메틱을 보유 목록에 넣고 저장에 남아야 한다.
func _check_mileage_exchange() -> bool:
	var p: Profile = GameController.profile
	p.mileage = 0
	main.goto("mileage_exchange")
	await _settle(0.4)
	var es: UIScreen = main.current_screen()
	if not (es is MileageExchangeScreen):
		push_error("UIHarness: mileage_exchange 화면 진입 실패 (#23)")
		main.get_tree().quit(1)
		return false
	var list: VBoxContainer = es.get("_list")
	if list == null or list.get_child_count() == 0:
		push_error("UIHarness: 마일리지 교환 목록이 비어 있습니다 (#23)")
		main.get_tree().quit(1)
		return false
	var row0 := list.get_child(0) as Control
	var h0 := row0.get_child(0) as Control
	var btn0 := h0.get_child(h0.get_child_count() - 1) as Button
	if btn0 == null or not btn0.disabled:
		push_error("UIHarness: 마일리지 0인데 교환 버튼이 막히지 않았습니다 (#23)")
		main.get_tree().quit(1)
		return false

	var target_item := ""
	for item: String in (GachaScreen.POOL["special"] as Array):
		if not p.owned_cosmetics.has(item):
			target_item = item
			break
	if target_item == "":
		print("  · 마일리지 교환: 스페셜 코스메틱을 모두 보유해 교환 실행 케이스를 건너뜁니다 (#23)")
		return true

	var cost := int(MileageExchangeScreen.EXCHANGE_COST["special"])
	p.mileage = cost
	var owned_before := p.owned_cosmetics.size()
	es.call("_exchange", "special", target_item, cost)
	await _settle(0.2)
	if p.mileage != 0:
		push_error("UIHarness: 교환 후 마일리지가 비용만큼 정확히 줄지 않았습니다 (#23)")
		main.get_tree().quit(1)
		return false
	if not p.owned_cosmetics.has(target_item) or p.owned_cosmetics.size() != owned_before + 1:
		push_error("UIHarness: 교환한 코스메틱이 보유 목록에 들어가지 않았습니다 (#23)")
		main.get_tree().quit(1)
		return false
	# 이미 보유한 코스메틱은 목록에서 빠져야 한다: 화면을 새로고침해 방금 교환한
	# 항목이 더 이상 행으로 뜨지 않는지 확인한다.
	es.call("_refresh")
	await _settle(0.2)
	for row: Node in list.get_children():
		var h := row.get_child(0) as Control
		var name_lbl := h.get_child(1) as Label
		if name_lbl != null and name_lbl.text == target_item:
			push_error("UIHarness: 이미 보유한 코스메틱이 교환 목록에 남아 있습니다 (#23)")
			main.get_tree().quit(1)
			return false
	var persisted: Dictionary = LocalSave.load_result().get("data", {})
	var pprofile: Dictionary = persisted.get("profile", {})
	var saved_cosmetics: Array = pprofile.get("owned_cosmetics", [])
	if int(pprofile.get("mileage", -1)) != 0 or not saved_cosmetics.has(target_item):
		push_error("UIHarness: 저장 왕복 후 교환 결과가 세이브에 남지 않았습니다 (#23)")
		main.get_tree().quit(1)
		return false
	print("  ✓ 마일리지 교환 왕복 (#23)")
	return true

## #31 회귀: 결제 어댑터가 상품을 돌려주지 않는 기본(미연동) 상태에서는 확정 가격과
## 구매 버튼이 하나도 없어야 하고 상품 이름·혜택 설명은 그대로 보여야 한다. 어댑터가
## 상품을 돌려주면 그 가격이 구매 버튼에 그대로 표시돼야 한다.
func _check_shop_pricing_gate() -> bool:
	ShopCatalog.reset_test_priced_offers()
	main.goto("shop")
	await _settle(0.4)
	var s: UIScreen = main.current_screen()
	if not (s is ShopScreen):
		push_error("UIHarness: shop 화면 진입 실패 (#31)")
		main.get_tree().quit(1)
		return false
	var names: Dictionary = s.get("_offer_name_labels")
	var buttons: Dictionary = s.get("_priced_buy_buttons")
	if names.size() != ShopScreen.OFFERINGS.size():
		push_error("UIHarness: 미연동 상태에서 상품 이름·혜택 설명이 전부 보이지 않습니다 (#31)")
		main.get_tree().quit(1)
		return false
	if not buttons.is_empty():
		push_error("UIHarness: 결제 어댑터가 상품을 돌려주지 않는데 구매 버튼이 보입니다 (#31)")
		main.get_tree().quit(1)
		return false
	print("  ✓ 결제 미연동 상태: 가격·구매 버튼 없음, 상품 이름·설명 유지 (#31)")

	ShopCatalog.set_test_priced_offers([{"id": "remove_ads", "price": "₩9,900"}])
	main.goto("shop")
	await _settle(0.4)
	s = main.current_screen()
	buttons = s.get("_priced_buy_buttons")
	var buy: Button = buttons.get("remove_ads")
	if buy == null or buy.text != "₩9,900" or (buttons as Dictionary).size() != 1:
		push_error("UIHarness: 어댑터가 돌려준 가격이 구매 버튼에 그대로 표시되지 않습니다 (#31)")
		main.get_tree().quit(1)
		ShopCatalog.reset_test_priced_offers()
		return false
	print("  ✓ 결제 연동 스텁: 어댑터 가격이 그대로 표시됨 (#31)")
	ShopCatalog.reset_test_priced_offers()
	return true

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

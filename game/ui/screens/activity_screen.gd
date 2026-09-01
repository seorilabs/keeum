class_name ActivityScreen
extends UIScreen
## SCR-003 활동 선택. 슬롯 2개(학습축 A·여가축 B) 배분 + 보상형 보너스 슬롯.
## 둘 다 학원=성적↑·스트레스↑, 둘 다 놀이=정서↑·성적 정체 → 매 턴 균형 결정.

var _a := ""
var _b := ""
var _bonus := ""
var _bonus_open := false
var _a_cards: Dictionary = {}
var _b_cards: Dictionary = {}
var _bonus_cards: Dictionary = {}
var _bonus_container: VBoxContainer
var _run: GameRun

func enter(_data: Variant = null) -> void:
	_run = GameController.run
	GameController.track("raise_activity_pick", {"stage": _run.child.stage, "stress": _run.child.stress})
	var root := page_root(50)

	var header := UIKit.hbox(8)
	header.add_child(UIKit.label("이번 달, 무엇을 시킬까요?", 30, UIKit.TEXT))
	header.add_child(UIKit.spacer())
	header.add_child(UIKit.icon_text("coin", "%d" % _run.household.money, 24, UIKit.MONEY))
	root.add_child(header)
	root.add_child(UIKit.label(_run.year_label(), 22, UIKit.TEXT_SOFT))

	var body := scroll_body(root)

	body.add_child(_section_title("슬롯 A · 학습", UIKit.BLUE))
	_build_slot(body, "A", _a_cards, _on_pick_a)

	body.add_child(UIKit.spacer(6))
	body.add_child(_section_title("슬롯 B · 여가", UIKit.SAGE))
	_build_slot(body, "B", _b_cards, _on_pick_b)

	# 보너스 슬롯(보상형 광고 — 유저 주도)
	body.add_child(UIKit.spacer(6))
	var ad_btn := UIKit.icon_button("film", "보너스 슬롯 열기 (광고 시청)")
	ad_btn.pressed.connect(_open_bonus)
	body.add_child(ad_btn)
	_bonus_container = UIKit.vbox(10)
	body.add_child(_bonus_container)

	# 하단 고정 행동
	var repeat := UIKit.button("지난 달 유지")
	repeat.disabled = GameController.last_selection.is_empty()
	repeat.pressed.connect(_repeat_last)
	root.add_child(repeat)

	var confirm := UIKit.button("결정!", true)
	confirm.pressed.connect(_confirm)
	root.add_child(confirm)

	_refresh()
	FX.stagger_children(body, 0.03)

func _section_title(text: String, color: Color) -> Control:
	return UIKit.label(text, 26, color)

func _build_slot(parent: Control, slot: String, store: Dictionary, cb: Callable) -> void:
	var rest := _option_card("— 이번엔 쉬어요 —", "무리하지 않아도 괜찮아요.", 0, true)
	rest.pressed.connect(cb.bind(""))
	parent.add_child(rest)
	store[""] = rest
	for act: Dictionary in _run.available_activities(slot):
		var id := str(act.get("id", ""))
		var cost := int(act.get("cost", 0))
		var affordable := _run.household.can_afford(cost)
		var card := _option_card(str(act.get("name", id)), _hint(act), cost, affordable, id)
		card.disabled = not affordable
		card.pressed.connect(cb.bind(id))
		parent.add_child(card)
		store[id] = card

func _option_card(title: String, hint: String, _cost: int, _affordable: bool, act_id: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 92)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = "%s\n%s" % [title, hint]
	if UIKit.body_font != null:
		b.add_theme_font_override("font", UIKit.body_font)
	b.add_theme_font_size_override("font_size", UIKit.sz(26))
	b.add_theme_color_override("font_color", UIKit.TEXT)
	# 활동 아이콘(생성 에셋 접합부): 있으면 좌측 배치 + 텍스트 들여쓰기
	var iconed := false
	if act_id != "":
		var tex := Art.tex("act_" + act_id)
		if tex != null:
			iconed = true
			var tr := TextureRect.new()
			tr.texture = tex
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(56, 56)
			tr.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
			tr.position = Vector2(16, -28)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
	b.set_meta("iconed", iconed)
	b.add_theme_stylebox_override("normal", _card_style(UIKit.CARD, iconed))
	b.add_theme_stylebox_override("hover", _card_style(UIKit.CARD.lightened(0.04), iconed))
	b.add_theme_stylebox_override("pressed", _card_style(UIKit.CREAM_DEEP, iconed))
	b.add_theme_stylebox_override("disabled", _card_style(Color(0.95, 0.92, 0.87, 0.6), iconed))
	# 선택 체크 표시(우측, 선택 시에만 노출 — 색+아이콘 병행으로 색약 대응)
	var check := GameIcon.make("check", float(UIKit.sz(26)), UIKit.MONEY)
	check.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	check.position.x -= 46
	check.visible = false
	b.add_child(check)
	b.set_meta("check_node", check)
	FX.press(b)
	return b

func _card_style(bg: Color, iconed: bool) -> StyleBoxFlat:
	var s := UIKit._btn_style(bg)
	if iconed:
		s.content_margin_left = 88
	return s

func _hint(act: Dictionary) -> String:
	var cost := int(act.get("cost", 0))
	if str(act.get("axis", "")) == "learn":
		var lr := Growth.learn_result(act, _run.child)
		var parts: Array[String] = []
		for s: String in lr["subjects"]:
			parts.append("%s +%d" % [Balance.SUBJECT_NAME.get(s, s), int(lr["subjects"][s])])
		var subj := ", ".join(parts) if not parts.is_empty() else "성장 미미"
		return "%s · 스트레스 %+d · ₩%d" % [subj, int(lr["stress"]), cost]
	else:
		var parts: Array[String] = []
		for key: String in ["emotion", "stamina", "talent", "bonding", "stress"]:
			var v := int(act.get(key, 0))
			if v != 0:
				parts.append("%s %+d" % [_leisure_name(key), v])
		var money := int(act.get("money", 0))
		if money != 0:
			parts.append("₩%+d" % money)
		return "%s · ₩%d" % [", ".join(parts), cost]

func _leisure_name(key: String) -> String:
	match key:
		"emotion": return "정서"
		"stamina": return "체력"
		"talent": return "특기"
		"bonding": return "유대"
		"stress": return "스트레스"
	return key

# ---------------------------------------------------------------- 선택
func _on_pick_a(id: String) -> void:
	_a = id; AudioBus.tap(); _refresh()

func _on_pick_b(id: String) -> void:
	_b = id; AudioBus.tap(); _refresh()

func _on_pick_bonus(id: String) -> void:
	_bonus = id; AudioBus.tap(); _refresh()

func _open_bonus() -> void:
	if _bonus_open:
		return
	_bonus_open = true
	AudioBus.chime()
	router.toast("광고 시청 완료 — 보너스 슬롯이 열렸어요")
	_bonus_container.add_child(_section_title("보너스 슬롯 · 자유", UIKit.CORAL))
	var rest := _option_card("— 사용 안 함 —", "", 0, true)
	rest.pressed.connect(_on_pick_bonus.bind(""))
	_bonus_container.add_child(rest)
	_bonus_cards[""] = rest
	for slot: String in ["A", "B"]:
		for act: Dictionary in _run.available_activities(slot):
			var id := str(act.get("id", ""))
			if _bonus_cards.has(id):
				continue
			var cost := int(act.get("cost", 0))
			var card := _option_card(str(act.get("name", id)), _hint(act), cost, _run.household.can_afford(cost))
			card.pressed.connect(_on_pick_bonus.bind(id))
			_bonus_container.add_child(card)
			_bonus_cards[id] = card
	_refresh()

func _repeat_last() -> void:
	var sel: Dictionary = GameController.last_selection
	_a = str(sel.get("a", ""))
	_b = str(sel.get("b", ""))
	AudioBus.tap()
	_refresh()

func _refresh() -> void:
	_refresh_store(_a_cards, _a)
	_refresh_store(_b_cards, _b)
	if _bonus_open:
		_refresh_store(_bonus_cards, _bonus)

func _refresh_store(store: Dictionary, selected: String) -> void:
	for id: String in store:
		var b: Button = store[id]
		if b.disabled:
			continue
		var sel := id == selected
		var bg := UIKit.PINK if sel else UIKit.CARD
		var iconed := bool(b.get_meta("iconed")) if b.has_meta("iconed") else false
		b.add_theme_stylebox_override("normal", _card_style(bg, iconed))
		b.add_theme_stylebox_override("hover", _card_style(bg.lightened(0.04), iconed))
		var check: Control = b.get_meta("check_node") if b.has_meta("check_node") else null
		if check != null:
			var newly := sel and not check.visible
			check.visible = sel
			if newly:
				FX.pop_in(check)

func _confirm() -> void:
	var result := _run.resolve_turn(_a, _b, _bonus)
	GameController.last_selection = {"a": _a, "b": _b, "bonus": _bonus}
	GameController.save_game()  # 턴 종료 자동 저장(AC-006)
	if int(result.get("stress", 0)) >= 12:
		AudioBus.stress_nudge()
	else:
		AudioBus.positive()
	router.goto("result", result)

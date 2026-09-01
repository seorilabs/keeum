class_name EventScreen
extends UIScreen
## SCR-006 이벤트 컷. 서사·선택(일상·유대감·번아웃·유혹).
## 유혹은 성인 풍자 도덕 장치 — 수락 즉시 이득 + 숨은 리스크, 거절 정직 보너스.

var _event: Dictionary
var _run: GameRun
var _body_label: Label
var _choice_box: VBoxContainer
var _next_btn: Button
var _avatar: ChildAvatar
var _panel: PanelContainer

func enter(data: Variant = null) -> void:
	_event = data if data is Dictionary else {}
	_run = GameController.run
	GameController.save_game()

	var root := page_root(60)
	var category := str(_event.get("category", "daily"))
	var accent := _accent(category)

	root.add_child(UIKit.label(_tag(category), 22, accent, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UIKit.title(str(_event.get("title", "")), 36))

	# 감정 컷 무대: 카테고리 배경 아트 위에 아이를 세운다(없으면 아바타 단독).
	_avatar = ChildAvatar.new()
	UIUtil.configure_avatar(_avatar, _run, reduce_motion())
	_avatar.set_look(_run.child.stage, _event_expression(category))
	var stage_tex := Art.tex(_bg_name(category))
	if stage_tex != null:
		var stage := UIKit.panel(UIKit.CREAM, 22)
		stage.custom_minimum_size = Vector2(0, 300)
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.size_flags_stretch_ratio = 0.55
		var tex_rect := TextureRect.new()
		tex_rect.texture = stage_tex
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.clip_contents = true
		stage.add_child(tex_rect)
		_avatar.align_bottom = true
		_avatar.draw_scale = 0.72
		stage.add_child(_avatar)
		root.add_child(stage)
	else:
		_avatar.custom_minimum_size = Vector2(0, 170)
		root.add_child(_avatar)

	var body := scroll_body(root)
	if stage_tex != null:
		(body.get_parent() as Control).size_flags_stretch_ratio = 0.45
	_panel = UIKit.panel(UIKit.CARD, 22)
	var v := UIKit.vbox(14)
	_panel.add_child(v)
	_body_label = UIKit.label(str(_event.get("body", "")), 28, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	v.add_child(_body_label)
	_choice_box = UIKit.vbox(10)
	v.add_child(_choice_box)
	body.add_child(_panel)

	_build_choices()

	_next_btn = UIKit.button("다음", true)
	_next_btn.visible = false
	_next_btn.pressed.connect(func() -> void:
		AudioBus.page()
		router.advance_step())
	root.add_child(_next_btn)

	FX.pop_in(_body_label, 0.1)
	FX.stagger_children(_choice_box, 0.07)

func _build_choices() -> void:
	var choices: Array = _event.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var b := UIKit.button(str(choice.get("label", "")))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(_on_choice.bind(i))
		_choice_box.add_child(b)

func _on_choice(index: int) -> void:
	# 상태 변경·저장은 연출 전에 동기 완료.
	var out := _run.resolve_event(_event, index)
	GameController.track("raise_event_choice", {"event_id": _event.get("id", ""), "choice": index})
	GameController.save_game()
	var exposure := bool(out.get("exposure", false))
	var category := str(_event.get("category", ""))
	var reduced := reduce_motion()

	for c: Node in _choice_box.get_children():
		(c as Button).disabled = true
		if reduced:
			c.visible = false
		else:
			var ct := (c as Control).create_tween()
			ct.tween_property(c, "modulate:a", 0.0, 0.15)
			ct.tween_callback(func() -> void: (c as Control).visible = false)

	# 즉시 반응: 표정 전환 + 바운스
	if exposure:
		AudioBus.stress_nudge()
		_body_label.add_theme_color_override("font_color", UIKit.CORAL)
		_avatar.set_look(_run.child.stage, "sad")
		FX.pulse_amber(_panel)
	elif category == "bonding":
		AudioBus.bonding()
		_avatar.set_look(_run.child.stage, "happy")
		FX.haptic(2)
		if not reduced:
			FxBurst.burst(_avatar, Vector2(_avatar.size.x * 0.5, _avatar.size.y * 0.3), "heart", 8)
	else:
		AudioBus.positive()
		_avatar.set_look(_run.child.stage, "happy")
	_bounce_avatar()

	# 인과: 결과 텍스트 크로스페이드
	if reduced:
		_body_label.text = str(out.get("text", ""))
	else:
		var bt := _body_label.create_tween()
		bt.tween_property(_body_label, "modulate:a", 0.0, 0.14)
		bt.tween_callback(func() -> void: _body_label.text = str(out.get("text", "")))
		bt.tween_property(_body_label, "modulate:a", 1.0, 0.2)

	_next_btn.visible = true
	FX.pop_in(_next_btn, 0.25)

func _bounce_avatar() -> void:
	if reduce_motion() or _avatar == null or not _avatar.is_inside_tree():
		return
	_avatar.pivot_offset = _avatar.size * 0.5
	var tw := _avatar.create_tween()
	tw.tween_property(_avatar, "scale", Vector2(1.06, 1.06), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_avatar, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tag(category: String) -> String:
	match category:
		"bonding": return "· 가족 ·"
		"burnout": return "· 번아웃 ·"
		"temptation": return "· 갈림길 ·"
		"rebellion": return "· 사춘기 ·"
	return "· 일상 ·"

func _accent(category: String) -> Color:
	match category:
		"bonding": return UIKit.PINK
		"burnout": return UIKit.AMBER
		"temptation": return UIKit.CORAL
		"rebellion": return UIKit.AMBER
	return UIKit.SAGE

## 카테고리별 무대 배경. 가족 컷은 활동 배경(가족 나들이)을 재사용한다.
func _bg_name(category: String) -> String:
	if category == "bonding":
		return "bg_act_family"
	return "bg_event_" + category

func _event_expression(category: String) -> String:
	match category:
		"bonding": return "happy"
		"burnout": return "tired"
		"rebellion": return "angry"
		"temptation": return "focused"
	return UIUtil.mood_expression(_run.child)

class_name HomeScreen
extends UIScreen
## SCR-002 메인(우리 집). 자녀가 주인공. 단일 CTA + 얇은 상단바(접힘 HUD).
## 대표 플레이 화면(04 문서): 계절 배경 + 아이 idle + 유대 하트, 대시보드 금지.

var _avatar: ChildAvatar
var _stage_panel: PanelContainer
var _wardrobe_layer: Control

func enter(_data: Variant = null) -> void:
	var run: GameRun = GameController.run
	if run == null:
		router.goto("onboarding")
		return
	if run.is_final_turn():
		router.goto("application")
		return
	GameController.track("raise_home_view", {"stage": run.child.stage})

	var root := page_root(54)
	root.add_child(HUD.build(run))

	# 자녀 무대(계절 배경 아트 접합부 — 없으면 크림 패널)
	_stage_panel = UIKit.panel(UIKit.CREAM, 26)
	_stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bg_tex := Art.tex("bg_home_" + Art.season(run.turn_index + 1))
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_stage_panel.add_child(bg)
	var sv := UIKit.vbox(6)
	_stage_panel.add_child(sv)

	# 옷장(보유 코스메틱이 있을 때만)
	if not GameController.profile.owned_cosmetics.is_empty():
		var wrow := UIKit.hbox(0)
		wrow.add_child(UIKit.spacer())
		var wbtn := UIKit.icon_button("ribbon", "", false, 20, UIKit.PINK)
		wbtn.custom_minimum_size = Vector2(UIKit.TOUCH_MIN, UIKit.TOUCH_MIN)
		wbtn.pressed.connect(_open_wardrobe)
		wrow.add_child(wbtn)
		sv.add_child(wrow)

	_avatar = ChildAvatar.new()
	_avatar.custom_minimum_size = Vector2(0, 300)
	_avatar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIUtil.configure_avatar(_avatar, run, reduce_motion())
	if bg_tex != null:
		# 배경 무대 위에서는 바닥선에 세우고 크기를 무대에 맞춘다(공중 부양 방지).
		_avatar.align_bottom = true
		_avatar.draw_scale = 0.62
	sv.add_child(_avatar)

	# 이름·무드 텍스트는 배경 위 가독성을 위해 은은한 크림 스크림 위에 올린다.
	var caption := UIKit.vbox(2)
	caption.add_child(UIKit.label("%s · %s" % [run.child.name, Balance.TEMPERAMENT_NAME.get(run.child.temperament, "")],
		30, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	caption.add_child(UIKit.label(UIUtil.mood_line(run), 24, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER, true))
	if bg_tex != null:
		var scrim := UIKit.panel(Color(0.99, 0.96, 0.91, 0.82), 18)
		scrim.add_child(caption)
		sv.add_child(scrim)
	else:
		sv.add_child(caption)
	root.add_child(_stage_panel)

	# 주 CTA(저속 펄스로 시선 유도)
	var cta := UIKit.button("이번 달 활동 정하기", true)
	cta.pressed.connect(func() -> void:
		AudioBus.tap()
		router.goto("activity"))
	root.add_child(cta)
	_pulse_cta(cta)

	# 보조 행동
	var nav := UIKit.hbox(10)
	for item: Array in [["book", "도감", "codex"], ["bag", "상점", "shop"], ["gear", "설정", "settings"]]:
		var b := UIKit.icon_button(str(item[0]), str(item[1]), false, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			AudioBus.tap()
			router.goto(str(item[2])))
		nav.add_child(b)
	root.add_child(nav)

	FX.stagger_children(root, 0.06)
	_start_idle_hearts(run)
	GameController.profile_changed.connect(_refresh_cosmetics)

## 유대·정서가 높으면 8~15초 주기로 하트 1개(과용 금지 — 04 문서).
func _start_idle_hearts(run: GameRun) -> void:
	if reduce_motion():
		return
	if run.household.bonding < 70 or run.child.emotion < 70:
		return
	var timer := Timer.new()
	timer.one_shot = false
	timer.wait_time = randf_range(8.0, 15.0)
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func() -> void:
		if _avatar != null and is_instance_valid(_avatar) and _avatar.is_inside_tree():
			FxBurst.burst(_avatar, Vector2(_avatar.size.x * 0.62, _avatar.size.y * 0.28), "heart", 1)
		timer.wait_time = randf_range(8.0, 15.0))

func _pulse_cta(cta: Button) -> void:
	if reduce_motion():
		return
	cta.pivot_offset = cta.size * 0.5
	cta.resized.connect(func() -> void: cta.pivot_offset = cta.size * 0.5)
	var tw := cta.create_tween()
	tw.set_loops()
	tw.tween_property(cta, "scale", Vector2(1.015, 1.015), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cta, "scale", Vector2.ONE, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _refresh_cosmetics() -> void:
	if _avatar == null or not is_instance_valid(_avatar):
		return
	_avatar.cosmetics = GameController.profile.equipped
	_avatar.queue_redraw()

# ---------------------------------------------------------------- 옷장
func _open_wardrobe() -> void:
	AudioBus.tap()
	if _wardrobe_layer != null and is_instance_valid(_wardrobe_layer):
		_wardrobe_layer.visible = true
		return
	_wardrobe_layer = Control.new()
	_wardrobe_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wardrobe_layer.z_index = 80
	var dim := ColorRect.new()
	dim.color = Color(0.23, 0.19, 0.16, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_wardrobe_layer.visible = false)
	_wardrobe_layer.add_child(dim)

	var sheet := UIKit.panel(UIKit.CARD, 24)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_top = -640
	sheet.offset_left = 16
	sheet.offset_right = -16
	sheet.offset_bottom = -16
	var v := UIKit.vbox(10)
	sheet.add_child(v)
	v.add_child(UIKit.title("옷장", 32))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := UIKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	_fill_wardrobe(list)
	var close := UIKit.button("닫기")
	close.pressed.connect(func() -> void:
		AudioBus.tap()
		_wardrobe_layer.visible = false)
	v.add_child(close)
	_wardrobe_layer.add_child(sheet)
	add_child(_wardrobe_layer)
	FX.pop_in(sheet)

func _fill_wardrobe(list: VBoxContainer) -> void:
	for c: Node in list.get_children():
		c.queue_free()
	var p: Profile = GameController.profile
	for item_name: String in p.owned_cosmetics:
		var info := Art.cosmetic(item_name)
		if info.is_empty():
			continue
		var slot := str(info.get("slot", ""))
		var worn := str(p.equipped.get(slot, "")) == item_name
		var row := UIKit.panel(UIKit.CARD, 14)
		var h := UIKit.hbox(8)
		row.add_child(h)
		h.add_child(UIKit.icon("sparkle" if slot == "theme" or slot == "pet" else "ribbon",
			UIKit.sz(22) + 2, UIKit.TALENT if slot == "theme" or slot == "pet" else UIKit.BLUE))
		h.add_child(UIKit.label(item_name, 24, UIKit.TEXT))
		h.add_child(UIKit.spacer())
		var btn := UIKit.button("해제" if worn else "장착", not worn)
		btn.custom_minimum_size = Vector2(140, UIKit.TOUCH_MIN)
		btn.pressed.connect(func() -> void:
			AudioBus.tap()
			GameController.equip_cosmetic(slot, "" if worn else item_name)
			_fill_wardrobe(list))
		h.add_child(btn)
		list.add_child(row)
	if list.get_child_count() == 0:
		list.add_child(UIKit.label("아직 코스메틱이 없어요. 뽑기에서 만나요!", 24, UIKit.TEXT_SOFT))

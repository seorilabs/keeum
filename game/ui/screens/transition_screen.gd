class_name TransitionScreen
extends UIScreen
## SCR-006 계열 전환기 대화. 기질 재형성 — 성공 확률 = f(유대감). 감정 클라이맥스.
## 유료 가챠로 성향을 바꾸지 않는다. 보상형 부스트(+20%p)만 1회 허용.
## 연출은 라이팅 변화 중심(04 문서: 파티클 과용 금지) — 웜 비네트 심화 → 결과 워프.

var _transition: Dictionary
var _run: GameRun
var _use_ad := false
var _chance_label: Label
var _option_box: VBoxContainer
var _ad_btn: Button
var _result_label: Label
var _next_btn: Button
var _vignette: TextureRect
var _avatar: ChildAvatar
var _last_pct := -1

func enter(data: Variant = null) -> void:
	_transition = data if data is Dictionary else {}
	_run = GameController.run
	GameController.save_game()

	_build_vignette()

	var root := page_root(60)
	root.add_child(UIKit.label("· 진지한 가족 논의 ·", 22, UIKit.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UIKit.title(str(_transition.get("title", "")), 36))

	# 대화 무대: 생성 배경(부모 뒷모습 실루엣 저녁 거실) 위에 아이를 세운다.
	var stage_tex := Art.tex("bg_transition_talk")
	_avatar = ChildAvatar.new()
	UIUtil.configure_avatar(_avatar, _run, reduce_motion())
	_avatar.set_look(_run.child.stage, "focused")
	if stage_tex != null:
		var stage_panel := UIKit.panel(UIKit.CREAM, 22)
		stage_panel.custom_minimum_size = Vector2(0, 260)
		stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage_panel.size_flags_stretch_ratio = 0.5
		var tex_rect := TextureRect.new()
		tex_rect.texture = stage_tex
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.clip_contents = true
		stage_panel.add_child(tex_rect)
		_avatar.custom_minimum_size = Vector2(0, 150)
		_avatar.align_bottom = true
		_avatar.draw_scale = 0.82
		stage_panel.add_child(_avatar)
		root.add_child(stage_panel)
	else:
		_avatar.custom_minimum_size = Vector2(0, 160)
		root.add_child(_avatar)

	var body := scroll_body(root)
	var panel := UIKit.panel(UIKit.CARD, 22)
	var v := UIKit.vbox(14)
	panel.add_child(v)
	v.add_child(UIKit.label(str(_transition.get("body", "")), 27, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(_info_row())
	_chance_label = UIKit.label("", 26, UIKit.SAGE)
	v.add_child(_chance_label)
	_option_box = UIKit.vbox(10)
	v.add_child(_option_box)
	_result_label = UIKit.label("", 27, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	_result_label.visible = false
	v.add_child(_result_label)
	body.add_child(panel)

	# 어댑터 미연동이거나 세션 8회/일일 18회 캡에 닿았으면 부스트 버튼 자체를
	# 만들지 않는다(#34) — ShopCatalog(#31)와 같은 규칙.
	if AdGateway.can_open(GameController.profile):
		_ad_btn = UIKit.icon_button("film", "진심이 닿는 시간 (+20%p)")
		_ad_btn.disabled = not _run.can_use_ad_boost(_transition)
		_ad_btn.pressed.connect(_toggle_ad)
		root.add_child(_ad_btn)

	_next_btn = UIKit.button("다음", true)
	_next_btn.visible = false
	_next_btn.pressed.connect(func() -> void:
		AudioBus.page()
		router.advance_step())
	root.add_child(_next_btn)

	_build_options()
	_update_chance()
	FX.stagger_children(_option_box, 0.06)

## 따뜻한 라이팅의 대화 컷 — 라디얼 웜 비네트 오버레이(입력 통과).
func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.6, 0.0))
	grad.set_color(1, Color(0.72, 0.47, 0.25, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.45)
	tex.fill_to = Vector2(0.5, 1.05)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = 10
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	if not reduce_motion():
		var tw := _vignette.create_tween()
		tw.tween_property(_vignette, "modulate:a", 0.25, 0.9)

func _info_row() -> Control:
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label("현재 유대감", 24, UIKit.TEXT_SOFT))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.icon_text("heart", "%d" % _run.household.bonding, 26, UIKit.PINK))
	return row

func _build_options() -> void:
	var options: Array = _transition.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var b := UIKit.button("%s — %s" % [opt.get("label", ""), opt.get("desc", "")])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 72)
		b.pressed.connect(_resolve.bind(i))
		_option_box.add_child(b)

func _toggle_ad() -> void:
	_use_ad = not _use_ad
	AudioBus.chime()
	(_ad_btn.get_meta("icon_node") as GameIcon).set_kind("check" if _use_ad else "film")
	if _use_ad and not reduce_motion():
		DeltaPopup.spawn(self, Vector2(size.x * 0.5 + 60, size.y * 0.45), "+20%p", UIKit.SAGE, false, "heart")
	_update_chance()

func _update_chance() -> void:
	var pct := int(round(_run.transition_success_chance(_transition, _use_ad) * 100.0))
	if reduce_motion():
		_chance_label.text = "성공 확률 %d%%" % pct
	else:
		FX.count_up(_chance_label, pct, maxi(0, _last_pct), 0.5, "성공 확률 %d%%")
	_last_pct = pct

func _resolve(index: int) -> void:
	# 상태 변경·저장은 연출 전에 동기 완료(중단 안전). 부스트를 실제로 쓴 순간에만
	# 캡을 charge한다 — 토글만 하고 선택지를 누르지 않은 시청은 캡에 들지 않는다.
	if _use_ad:
		AdGateway.record_shown(GameController.profile)
	var out := _run.resolve_transition(_transition, index, _use_ad)
	GameController.track("raise_event_choice", {"event_id": _transition.get("gate", ""), "choice": index})
	for c: Node in _option_box.get_children():
		c.visible = false
	if _ad_btn != null:
		_ad_btn.visible = false
	_chance_label.visible = false
	GameController.save_game()
	if reduce_motion():
		_show_result(out)
		return
	_play_suspense(out)

## 서스펜스: 비네트 심화(0.7s 무음) → 성공=골든 워프 / 실패=쿨다운 페이드.
func _play_suspense(out: Dictionary) -> void:
	var tw := _vignette.create_tween()
	tw.tween_property(_vignette, "modulate:a", 0.55, 0.7)
	await tw.finished
	if not is_inside_tree():
		return
	var success := bool(out.get("success", false))
	var tw2 := _vignette.create_tween()
	if success:
		# 골든 라이팅 워프
		tw2.tween_property(_vignette, "modulate", Color(1.0, 0.9, 0.55, 0.35), 0.6)
		FX.haptic(2)
		if _avatar != null and _avatar.is_inside_tree():
			_avatar.set_look(_run.child.stage, "proud")
			FxBurst.burst(_avatar, _avatar.size * 0.5, "sparkle", 6)
	else:
		# 차분한 쿨다운(회복 서사 — 냉소 금지)
		tw2.tween_property(_vignette, "modulate", Color(0.75, 0.8, 0.95, 0.22), 0.7)
		if _avatar != null and _avatar.is_inside_tree():
			_avatar.set_look(_run.child.stage, "neutral")
	_show_result(out)

func _show_result(out: Dictionary) -> void:
	if not is_inside_tree():
		return
	if bool(out.get("success", false)):
		AudioBus.bonding()
		_result_label.add_theme_color_override("font_color", UIKit.SAGE)
		_result_label.text = "마음이 통했어요. 아이가 '%s'(으)로 자라기로 했어요." % out.get("target_name", "")
	else:
		AudioBus.page()
		_result_label.text = "이번엔 마음이 조금 엇갈렸어요. 하지만 괜찮아요, 다음 기회가 있어요."
	_result_label.visible = true
	FX.pop_in(_result_label)
	_next_btn.visible = true
	FX.pop_in(_next_btn, 0.15)

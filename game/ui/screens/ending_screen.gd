class_name EndingScreen
extends UIScreen
## SCR-007 입시·엔딩. 결말 연출·회고. 감정 순간이므로 광고·상점 미노출.
## 모든 엔딩은 긍정 보상(힐링 원칙). 연출은 라이팅 워밍업 중심(04 문서).

var _ending: Dictionary
var _run: GameRun
var _cg_panel: Control

func enter(data: Variant = null) -> void:
	_ending = data if data is Dictionary else {}
	_run = GameController.run
	var outcome := GameController.finish_run(_ending)  # 도감 등록·보상·기록

	var axis := str(_ending.get("axis", ""))
	var expr := "sad" if axis == "downfall" else "proud"
	var ending_id := str(_ending.get("id", ""))

	var root := page_root(58)

	# 엔딩 CG(생성 아트 접합부 — 없으면 따뜻한 라이팅 배경 + 대형 아바타)
	var cg_tex := Art.tex("cg_" + ending_id) if bool(_ending.get("cg", false)) else null
	if cg_tex == null:
		cg_tex = Art.tex("bg_ending_common")
	_cg_panel = UIKit.panel(_cg_bg(axis), 26)
	_cg_panel.custom_minimum_size = Vector2(0, 300)
	if cg_tex != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = cg_tex
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.clip_contents = true
		_cg_panel.add_child(tex_rect)
	# 전용 CG 가 아니면 아바타를 무대에 세운다(공용 배경 위 포함).
	if not (bool(_ending.get("cg", false)) and Art.has_art("cg_" + ending_id)):
		var cgv := UIKit.vbox(4)
		_cg_panel.add_child(cgv)
		var avatar := ChildAvatar.new()
		avatar.custom_minimum_size = Vector2(0, 240)
		UIUtil.configure_avatar(avatar, _run, reduce_motion())
		avatar.set_look("high", expr)
		if cg_tex != null:
			avatar.align_bottom = true
			avatar.draw_scale = 0.78
		cgv.add_child(avatar)
	root.add_child(_cg_panel)
	# 라이팅 워밍업: 어둠에서 따뜻하게 밝아진다.
	if not reduce_motion():
		_cg_panel.modulate = Color(0.55, 0.5, 0.5)
		var tw := _cg_panel.create_tween()
		tw.tween_property(_cg_panel, "modulate", Color.WHITE, 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var title := UIKit.title(str(_ending.get("title", "")), 34)
	root.add_child(title)
	var subtitle := UIKit.label("%s · %s" % [_ending.get("university", ""), _ending.get("career", "")],
		24, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(subtitle)
	FX.pop_in(title, 0.4)
	FX.pop_in(subtitle, 0.5)

	var body := scroll_body(root)
	var panel := UIKit.panel(UIKit.CARD, 22)
	var v := UIKit.vbox(12)
	panel.add_child(v)
	v.add_child(UIKit.label(str(_ending.get("epilogue", "")), 27, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(_reward_row(outcome))
	body.add_child(panel)
	FX.pop_in(panel, 0.6)

	var codex := UIKit.button("도감에 등록", true)
	codex.pressed.connect(func() -> void:
		AudioBus.chime()
		GameController.track("raise_ending_view", {})
		router.goto("codex", {"new_ending": ending_id} if bool(outcome.get("is_new", false)) else null))
	root.add_child(codex)

	var share := UIKit.button("결과 카드 공유")
	share.pressed.connect(_share)
	root.add_child(share)

	if bool(outcome.get("is_new", false)):
		AudioBus.sting("sting_new_ending")
		router.toast("새 엔딩을 발견했어요!")
		if not reduce_motion():
			var btw := _cg_panel.create_tween()
			btw.tween_interval(0.9)
			btw.tween_callback(func() -> void:
				FxBurst.burst(_cg_panel, Vector2(_cg_panel.size.x * 0.5, _cg_panel.size.y * 0.35), "sparkle", 12))
	else:
		AudioBus.bonding()

func _share() -> void:
	AudioBus.tap()
	GameController.track("raise_share", {"ending_id": _ending.get("id", "")})
	var hair := str(_run.child.appearance.get("hair", "mushroom")) if _run != null else "mushroom"
	var outfit := Color(str(_run.child.appearance.get("outfit", "F28C79"))) if _run != null else Color("F28C79")
	var child_name := _run.child.name if _run != null else ""
	var path: String = await ShareCard.save(self, _ending, child_name, hair, outfit,
		GameController.profile.total_runs)
	if not is_inside_tree():
		return
	if path == "":
		if DisplayServer.get_name().to_lower() == "headless":
			router.toast("공유 카드는 실제 화면 환경에서 저장할 수 있어요")
		else:
			router.toast("결과 카드를 저장하지 못했어요. 저장 공간을 확인해 주세요")
	else:
		router.toast("결과 카드를 저장했어요: %s" % path.replace("user://", ""))

func _reward_row(outcome: Dictionary) -> Control:
	var row := UIKit.hbox(8)
	var tag := "새 엔딩 보너스 포함" if bool(outcome.get("is_new", false)) else "회차 보상"
	row.add_child(UIKit.label(tag, 24, UIKit.TEXT_SOFT))
	row.add_child(UIKit.spacer())
	var reward := int(outcome.get("premium_reward", 0))
	var gbox := UIKit.hbox(6)
	gbox.add_child(UIKit.icon("gem", UIKit.sz(28) + 2, UIKit.PREMIUM))
	var glabel := UIKit.label("+%d" % reward, 28, UIKit.PREMIUM)
	gbox.add_child(glabel)
	row.add_child(gbox)
	FX.count_up(glabel, reward, 0, 0.7, "+%d")
	return row

func _cg_bg(axis: String) -> Color:
	match axis:
		"prestige": return Color("FDEBD8")
		"talent": return Color("F3E6F5")
		"wellbeing": return Color("E9F1E4")
		"entrepreneur": return Color("E6EFF7")
		"downfall": return Color("EDE4DE")
	return UIKit.CREAM

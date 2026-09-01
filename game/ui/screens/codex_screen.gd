class_name CodexScreen
extends UIScreen
## SCR-008 도감. 수집 동기·회차 훅. 미수집은 실루엣(03 문서).
## 엔딩에서 신규 등록 직후 진입하면 해당 셀을 포커스·해금 연출한다.

var _cells: Dictionary = {}
var _scroll: ScrollContainer

func enter(data: Variant = null) -> void:
	var profile: Profile = GameController.profile
	var endings: Array = GameController.content.endings
	GameController.track("raise_codex_view", {"collected": profile.collected_endings.size()})

	var root := page_root(56)
	root.add_child(UIKit.title("엔딩 도감", 40))
	root.add_child(UIKit.label("%d / %d 수집 · %d번째 아이까지 키웠어요" % [
		profile.collected_endings.size(), endings.size(), profile.total_runs,
	], 24, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER, true))

	var body := scroll_body(root)
	_scroll = body.get_parent() as ScrollContainer
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)

	for ending: Dictionary in endings:
		var id := str(ending.get("id", ""))
		var cell := _ending_cell(ending, profile.has_ending(id))
		grid.add_child(cell)
		_cells[id] = cell

	if not profile.run_records.is_empty():
		body.add_child(UIKit.spacer(6))
		body.add_child(UIKit.label("지난 아이들", 26, UIKit.TEXT))
		var recent: Array = profile.run_records
		var start := maxi(0, recent.size() - 5)
		for i in range(recent.size() - 1, start - 1, -1):
			body.add_child(_record_row(recent[i]))

	if GameController.run != null:
		var home := UIKit.button("홈으로", true)
		home.pressed.connect(func() -> void:
			AudioBus.tap()
			router.goto("home"))
		root.add_child(home)
	else:
		var next := UIKit.button("새 아이 키우기", true)
		next.pressed.connect(func() -> void:
			AudioBus.bonding()
			GameController.start_next_child()
			router.goto("onboarding"))
		root.add_child(next)

	FX.stagger_children(grid, 0.03)

	# 신규 해금 연출: 해당 셀로 스크롤 + 팝 + 반짝이
	var new_id := ""
	if data is Dictionary:
		new_id = str((data as Dictionary).get("new_ending", ""))
	if new_id != "" and _cells.has(new_id):
		_celebrate_new(_cells[new_id] as Control)

func _celebrate_new(cell: Control) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(cell):
		return
	if _scroll != null:
		_scroll.ensure_control_visible(cell)
	if reduce_motion():
		return
	FX.pop_in(cell, 0.15)
	var ctw := cell.create_tween()
	ctw.tween_interval(0.35)
	ctw.tween_callback(func() -> void:
		FxBurst.burst(cell, cell.size * 0.5, "sparkle", 12)
		AudioBus.positive())

func _ending_cell(ending: Dictionary, collected: bool) -> Control:
	var panel := UIKit.panel(UIKit.CARD if collected else Color(0.94, 0.91, 0.86), 18)
	panel.custom_minimum_size = Vector2(0, 150)
	# 그리드 열이 화면 폭을 균등하게 나누도록(미설정 시 셀이 최소 폭으로 좌측에 몰린다).
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(4)
	panel.add_child(v)
	if collected:
		# 수집: CG 썸네일 접합부(전용 CG 엔딩 + 아트 존재 시)
		var thumb := Art.tex("cg_" + str(ending.get("id", ""))) if bool(ending.get("cg", false)) else null
		if thumb != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = thumb
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.custom_minimum_size = Vector2(0, 72)
			tex_rect.clip_contents = true
			v.add_child(tex_rect)
		if bool(ending.get("cg", false)):
			v.add_child(UIKit.icon_text("film", str(ending.get("title", "")), 24, UIKit.TEXT))
		else:
			v.add_child(UIKit.label(str(ending.get("title", "")), 24, UIKit.TEXT))
		v.add_child(UIKit.label(str(ending.get("university", "")), 20, UIKit.TEXT_SOFT))
	else:
		# 미수집 실루엣: 어두운 아바타 + 물음표(03 문서 "미수집은 실루엣")
		var sil := ChildAvatar.new()
		sil.reduce_motion = true
		sil.set_look("high", "neutral")
		sil.modulate = Color(0.42, 0.38, 0.35, 0.85)
		sil.custom_minimum_size = Vector2(0, 80)
		v.add_child(sil)
		v.add_child(UIKit.label("？？？", 24, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label("아직 만나지 못한 결말", 18, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	return panel

func _record_row(rec: Dictionary) -> Control:
	var row := UIKit.panel(UIKit.CREAM, 14)
	var h := UIKit.hbox(8)
	row.add_child(h)
	h.add_child(UIKit.label("%d번째 · %s" % [int(rec.get("generation", 0)), rec.get("child_name", "")], 22, UIKit.TEXT))
	h.add_child(UIKit.spacer())
	h.add_child(UIKit.label(str(rec.get("ending_title", "")), 22, UIKit.CORAL))
	return row

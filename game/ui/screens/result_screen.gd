class_name ResultScreen
extends UIScreen
## SCR-004 결과 반응 컷. 이번 달 활동을 장면 애니메이션으로 재생(활동별 연출) +
## 인과·보상 피드백(표정·대사·델타 팝업·게이지 애니·파티클). 숫자만 바뀌는 피드백은 실패(03 문서).
## 피드백 5단: 입력(카드) → 즉시 반응(표정·대사) → 인과(델타 팝업) → 결과(게이지) → 보상(파티클·스팅어·햅틱).

var _result: Dictionary
var _run: GameRun
var _scene: ActivityScene
var _caption: Label
var _dialogue_label: Label
var _delta_panel: PanelContainer
var _delta_box: VBoxContainer
var _delta_items: Array = []  # {label, gauge, delta, target}
var _played: Array = []
var _idx := 0

func enter(data: Variant = null) -> void:
	_result = data if data is Dictionary else {}
	_run = GameController.run
	GameController.track("raise_activity_result", {})

	var root := page_root(54)

	# 활동 장면 무대. 반응 컷의 주인공이므로 남는 세로 공간의 대부분을 무대가 갖는다
	# (배경 4:3 아트가 덜 잘리고 캐릭터가 크게 보인다).
	var panel := UIKit.panel(UIKit.CARD, 24)
	panel.custom_minimum_size = Vector2(0, 390)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.7
	var pv := UIKit.vbox(4)
	panel.add_child(pv)
	_scene = ActivityScene.new()
	_scene.reduced = reduce_motion()
	_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene.custom_minimum_size = Vector2(0, 330)
	_scene.gui_input.connect(_on_scene_input)
	pv.add_child(_scene)
	_caption = UIKit.label("", 24, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(_caption)
	root.add_child(panel)

	_played = _result.get("played", [])
	if _played.is_empty():
		_played = [{"name": "오늘은 쉬었어요", "tag": "rest", "axis": "leisure"}]
	_idx = 0
	_show_scene(0)
	if not reduce_motion() and _played.size() > 1:
		var timer := Timer.new()
		timer.wait_time = 2.2
		timer.autostart = true
		add_child(timer)
		timer.timeout.connect(_next_scene)

	# 즉시 반응(대사) — 장면 정착 직후 팝인
	_dialogue_label = UIKit.label(_dialogue(UIUtil.reaction_expression(_result, _run.child)),
		30, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.add_child(_dialogue_label)

	# 델타 목록(인과 → 결과). 콘텐츠 높이에 맞추고 남는 공간은 아래 spacer 가 흡수한다.
	_delta_panel = UIKit.panel(UIKit.CARD, 22)
	_delta_box = UIKit.vbox(8)
	_delta_panel.add_child(_delta_box)
	_add_deltas(_delta_box)
	var revealed: Array = _result.get("revealed", [])
	if not revealed.is_empty():
		var rev := UIKit.hbox(6)
		rev.add_child(UIKit.icon("sparkle", UIKit.sz(24) + 2, UIKit.TALENT))
		rev.add_child(UIKit.label(UIUtil.revealed_text(revealed), 24, UIKit.TALENT, HORIZONTAL_ALIGNMENT_LEFT, true))
		_delta_box.add_child(rev)
	if _run.child.stress >= 75:
		var warn := UIKit.hbox(6)
		warn.add_child(UIKit.icon("warning", UIKit.sz(24) + 2, UIKit.AMBER))
		warn.add_child(UIKit.label("아이가 많이 지쳤어요. 곧 쉼이 필요해요.", 24, UIKit.AMBER, HORIZONTAL_ALIGNMENT_LEFT, true))
		_delta_box.add_child(warn)
	root.add_child(_delta_panel)
	var tail := UIKit.spacer()
	tail.size_flags_stretch_ratio = 0.3
	root.add_child(tail)

	var next := UIKit.button("다음", true)
	next.pressed.connect(func() -> void:
		AudioBus.page()
		router.advance_step())
	root.add_child(next)

	FX.pop_in(_dialogue_label, 0.15)
	FX.stagger_children(_delta_box, 0.06)
	_defer_feedback()

# ---------------------------------------------------------------- 장면
func _show_scene(i: int) -> void:
	var a: Dictionary = _played[i]
	var hair := str(_run.child.appearance.get("hair", "mushroom"))
	var outfit := Color(str(_run.child.appearance.get("outfit", "F28C79")))
	_scene.play(a, _run.child.stage, hair, outfit)
	var extra := "   · 탭하면 다음" if _played.size() > 1 else ""
	_caption.text = "%s  ·  %s%s" % [a.get("name", ""), _axis_label(str(a.get("axis", ""))), extra]

func _next_scene() -> void:
	if _played.size() <= 1:
		return
	_idx = (_idx + 1) % _played.size()
	AudioBus.page()
	_show_scene(_idx)

func _on_scene_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_scene()

func _axis_label(axis: String) -> String:
	return "학습" if axis == "learn" else "여가"

# ---------------------------------------------------------------- 델타
func _add_deltas(v: VBoxContainer) -> void:
	var any := false
	var subs: Dictionary = _result.get("subjects", {})
	for s: String in subs:
		v.add_child(_delta_row("%s 성적" % Balance.SUBJECT_NAME.get(s, s), int(subs[s]),
			UIKit.stat_color("academic"), _run.child.subject_value(s)))
		any = true
	for pair: Array in [["emotion", "정서"], ["stamina", "체력"], ["talent", "특기"], ["bonding", "유대감"], ["stress", "스트레스"], ["money", "재력"]]:
		var val := int(_result.get(pair[0], 0))
		if pair[0] == "money":
			val -= Balance.BASE_INCOME_PER_TURN
			if val == 0:
				continue
		if val != 0:
			v.add_child(_delta_row(pair[1], val, UIKit.stat_color(pair[0]), _stat_now(str(pair[0]))))
			any = true
	if not any:
		v.add_child(UIKit.label("잔잔한 한 달이었어요.", 24, UIKit.TEXT_SOFT))

## 결과 화면 진입 시점의 현재 스탯(결과 반영 후 값). -1 = 게이지 없음(재력).
func _stat_now(key: String) -> int:
	match key:
		"emotion": return _run.child.emotion
		"stamina": return _run.child.stamina
		"talent": return _run.child.talent
		"bonding": return _run.household.bonding
		"stress": return _run.child.stress
	return -1

func _delta_row(name: String, delta: int, color: Color, now_val: int = -1) -> Control:
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(name, 26, UIKit.TEXT))
	row.add_child(UIKit.spacer())
	var gauge: StatGauge = null
	if now_val >= 0:
		# 결과 게이지: 이전값(=현재값-델타)에서 새 값으로 차오른다(피드백 4단).
		gauge = StatGauge.new()
		gauge.setup(color, "")
		gauge.custom_minimum_size = Vector2(150, 22)
		var prev := clampi(now_val - delta, 0, 100)
		gauge.set_value(float(prev) / 100.0, false)
		row.add_child(gauge)
	var sign := "+" if delta > 0 else ""
	var vlabel := UIKit.label("%s%d" % [sign, delta], 28, color)
	row.add_child(vlabel)
	_delta_items.append({"label": vlabel, "gauge": gauge, "delta": delta,
		"target": float(now_val) / 100.0})
	return row

func _dialogue(expr: String) -> String:
	match expr:
		"proud": return "\"해냈어요! 뿌듯해요.\""
		"excited": return "\"우와, 이거 진짜 좋아요!\""
		"tired": return "\"...너무 힘들어요. 조금만 쉬면 안 될까요?\""
		"sad": return "\"오늘은 그냥 그랬어요...\""
		"happy": return "\"오늘 하루도 재밌었어요!\""
	return "\"음... 그럭저럭요.\""

# ---------------------------------------------------------------- 피드백 연출
## 지연 실행은 전부 노드 소속 트윈으로 — 화면 해제 시 함께 소멸해 freed 콜백이 없다.
func _defer_feedback() -> void:
	var tw := create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(_play_feedback)

func _play_feedback() -> void:
	if not is_inside_tree():
		return
	var reduced := reduce_motion()

	# 결과: 카운트업 + 게이지 차오름(행별 스태거)
	var gi := 0
	for item: Dictionary in _delta_items:
		var delta := int(item["delta"])
		var vlabel: Label = item["label"]
		var fmt := "+%d" if delta > 0 else "%d"
		FX.count_up(vlabel, delta, 0, 0.5, fmt)
		var gauge: StatGauge = item["gauge"]
		if gauge != null:
			if reduced:
				gauge.set_value(float(item["target"]), false)
			else:
				var target := float(item["target"])
				var gtw := gauge.create_tween()
				gtw.tween_interval(0.12 + 0.06 * float(gi))
				gtw.tween_callback(func() -> void: gauge.set_value(target, true))
		gi += 1

	# 인과: 델타 팝업 스태거
	var i := 0
	var subs: Dictionary = _result.get("subjects", {})
	for s: String in subs:
		var d := int(subs[s])
		DeltaPopup.spawn(self, Vector2(size.x * 0.5 - 40 + i * 22, size.y * 0.30),
			"+%d" % d, UIKit.stat_color("academic"), reduced, "", 0.08 * float(i))
		i += 1
	var stress := int(_result.get("stress", 0))
	if stress != 0:
		var st := "%s%d" % ["+" if stress > 0 else "", stress]
		DeltaPopup.spawn(self, Vector2(size.x * 0.5 + 46, size.y * 0.26), st, UIKit.AMBER,
			reduced, "", 0.08 * float(i))
		i += 1
	var bond := int(_result.get("bonding", 0))
	if bond > 0:
		DeltaPopup.spawn(self, Vector2(size.x * 0.5 - 74, size.y * 0.24), "+%d" % bond,
			UIKit.PINK, reduced, "heart", 0.08 * float(i))

	# 보상: 긍정 결과 파티클+햅틱 / 스트레스 급증 앰버 펄스 1회(연타 금지)
	if reduced:
		return
	var expr := UIUtil.reaction_expression(_result, _run.child)
	if expr == "proud" or expr == "excited" or expr == "happy":
		FxBurst.burst(_scene, _scene.size * 0.5, "sparkle", 14)
		FX.haptic(1)
	if bond >= 6:
		FxBurst.burst(_scene, Vector2(_scene.size.x * 0.3, _scene.size.y * 0.35), "heart", 8)
	if stress >= 12:
		FX.pulse_amber(_delta_panel)

class_name TermScreen
extends UIScreen
## SCR-005 성적표·학기말. 학기 정산 + 분기. 감정 순간이므로 광고·상점 미노출.
## 게이지가 0에서 행별 스태거로 차오르고 점수가 카운트업된다(피드백 4단).

var _gauge_rows: Array = []  # {gauge, label, val}
var _avg_row: Control
var _panel: PanelContainer

func enter(_data: Variant = null) -> void:
	var run: GameRun = GameController.run
	GameController.save_game()
	GameController.track("raise_term_end", {
		"stage": run.child.stage, "avg": run.child.academic_average(), "stress": run.child.stress,
	})

	var root := page_root(56)
	root.add_child(UIKit.title("성적표", 40))
	root.add_child(UIKit.label(run.year_label(), 24, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))

	var body := scroll_body(root)
	_panel = UIKit.panel(UIKit.CARD, 22)
	var v := UIKit.vbox(12)
	_panel.add_child(v)
	for s: String in ["korean", "english", "math", "science", "social"]:
		v.add_child(_subject_row(s, run.child.subject_value(s)))
	v.add_child(_divider())
	_avg_row = _summary_row("평균", "%d점" % run.child.academic_average(), UIKit.BLUE, 34)
	v.add_child(_avg_row)
	v.add_child(_summary_row("특기", "%d" % run.child.talent, UIKit.TALENT))
	v.add_child(_summary_row("정서", "%d" % run.child.emotion, UIKit.CORAL))
	v.add_child(_summary_row("유대감", "%d" % run.household.bonding, UIKit.PINK))
	v.add_child(_summary_row("스트레스", "%d" % run.child.stress, UIKit.AMBER))
	body.add_child(_panel)

	var comment := UIKit.label(_comment(run), 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	body.add_child(comment)

	var next := UIKit.button("다음 학기", true)
	next.pressed.connect(func() -> void:
		AudioBus.chime()
		router.advance_step())
	root.add_child(next)

	AudioBus.page()
	FX.haptic(1)
	_play_reveal(run)
	FX.pop_in(comment, 0.55)

func _play_reveal(run: GameRun) -> void:
	if reduce_motion():
		return
	var i := 0
	for item: Dictionary in _gauge_rows:
		var gauge: StatGauge = item["gauge"]
		var vlabel: Label = item["label"]
		var val := int(item["val"])
		var gtw := gauge.create_tween()
		gtw.tween_interval(0.12 + 0.08 * float(i))
		gtw.tween_callback(func() -> void:
			gauge.set_value(float(val) / 100.0, true)
			FX.count_up(vlabel, val, 0, 0.45))
		i += 1
	# 평균 행 강조 팝 + 고득점 축하 반짝이
	FX.pop_in(_avg_row, 0.12 + 0.08 * float(i))
	if run.child.academic_average() >= 70:
		var ptw := _panel.create_tween()
		ptw.tween_interval(0.3 + 0.08 * float(i))
		ptw.tween_callback(func() -> void:
			FxBurst.burst(_panel, Vector2(_panel.size.x * 0.5, 20.0), "sparkle", 10)
			AudioBus.positive())

func _subject_row(subject: String, val: int) -> Control:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label(Balance.SUBJECT_NAME.get(subject, subject), 26, UIKit.TEXT))
	var g := StatGauge.new()
	g.setup(UIKit.BLUE, "")
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vlabel := UIKit.label("%d" % val, 24, UIKit.TEXT_SOFT)
	if reduce_motion():
		g.set_value(float(val) / 100.0, false)
	else:
		g.set_value(0.0, false)
		vlabel.text = "0"
	row.add_child(g)
	row.add_child(vlabel)
	_gauge_rows.append({"gauge": g, "label": vlabel, "val": val})
	return row

func _summary_row(name: String, value: String, color: Color, vsize: int = 28) -> Control:
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(name, 26, UIKit.TEXT))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(value, vsize, color))
	return row

func _divider() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.29, 0.25, 0.22, 0.12)
	c.custom_minimum_size = Vector2(0, 2)
	return c

func _comment(run: GameRun) -> String:
	var c := run.child
	if c.stress >= 75:
		return "성적은 올랐지만 아이 표정이 어두워요. 이번 학기는 조금 쉬어가도 괜찮아요."
	if run.household.bonding >= 65 and c.emotion >= 65 and c.academic_average() >= 55:
		return "성적도, 마음도 균형을 잡았어요. 이대로가 가장 단단한 길이에요."
	if c.academic_average() >= 65:
		return "열심히 따라와 줬어요. 다만 아이의 속도도 살펴봐 주세요."
	if c.emotion >= 70:
		return "숫자는 아직이지만, 아이는 밝고 건강해요. 자기 계절을 기다려요."
	return "천천히, 그러나 꾸준히. 우리만의 속도로 가고 있어요."

class_name HUD
extends RefCounted
## 얇은 상단 정보바. 기본 접힘(1행: 연도·재화 + 5색 미니 게이지), 탭하면 펼침(게이지 5행).
## 대시보드 금지 원칙(03 문서: "스탯은 접히는 얇은 상단 바"). 펼침 상태는 세션 유지.

static var expanded := false
static var _last_money := -1
static var _last_premium := -1

static func build(run: GameRun) -> Control:
	var panel := UIKit.panel(UIKit.CARD, 20)
	var v := UIKit.vbox(8)
	panel.add_child(v)

	var top := UIKit.hbox(8)
	top.add_child(UIKit.label(run.year_label(), 26, UIKit.TEXT))
	top.add_child(UIKit.spacer())
	var money := run.household.money
	var premium := GameController.profile.premium
	var money_label := UIKit.label("%d" % money, 24, UIKit.MONEY)
	var mbox := UIKit.hbox(6)
	mbox.add_child(UIKit.icon("coin", UIKit.sz(24) + 2, UIKit.MONEY))
	mbox.add_child(money_label)
	top.add_child(mbox)
	var prem_label := UIKit.label("%d" % premium, 24, UIKit.PREMIUM)
	var pbox := UIKit.hbox(6)
	pbox.add_child(UIKit.icon("gem", UIKit.sz(24) + 2, UIKit.PREMIUM))
	pbox.add_child(prem_label)
	top.add_child(pbox)
	var arrow := GameIcon.make("play", float(UIKit.sz(18)), UIKit.TEXT_SOFT)
	arrow.pivot_offset = arrow.custom_minimum_size * 0.5
	arrow.rotation_degrees = 90.0 if expanded else 0.0
	top.add_child(arrow)
	v.add_child(top)

	# 재화 증감 카운트업(직전 홈 방문 대비)
	if _last_money >= 0 and _last_money != money:
		FX.count_up(money_label, money, _last_money, 0.6)
	if _last_premium >= 0 and _last_premium != premium:
		FX.count_up(prem_label, premium, _last_premium, 0.6)
	_last_money = money
	_last_premium = premium

	var mini := _mini_row(run)
	var detail := _detail_box(run)
	mini.visible = not expanded
	detail.visible = expanded
	v.add_child(mini)
	v.add_child(detail)

	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			expanded = not expanded
			AudioBus.tap()
			FX.haptic(1)
			mini.visible = not expanded
			detail.visible = expanded
			arrow.rotation_degrees = 90.0 if expanded else 0.0
			if expanded and not FX.reduced():
				for entry: Array in (detail.get_meta("gauges") as Array):
					var g: StatGauge = entry[0]
					g.set_value(0.0, false)
					g.set_value(float(entry[1]) / 100.0, true))
	return panel

## 접힘: 5색 미니 게이지 한 줄(색+위치로 스캔, 자세한 수치는 펼침).
static func _mini_row(run: GameRun) -> Control:
	var row := UIKit.hbox(8)
	var vals := _stat_values(run)
	for entry: Array in vals:
		var g := StatGauge.new()
		g.setup(entry[1] as Color, "")
		g.custom_minimum_size = Vector2(0, 14)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.set_value(float(entry[2]) / 100.0, false)
		if str(entry[0]) == "stress" and int(entry[2]) >= 75:
			g.warn_pulse()
		row.add_child(g)
	return row

## 펼침: 게이지 5행 + 수치.
static func _detail_box(run: GameRun) -> Control:
	var box := UIKit.vbox(8)
	var gauges: Array = []
	var vals := _stat_values(run)
	for entry: Array in vals:
		var row := UIKit.hbox(8)
		var g := StatGauge.new()
		g.setup(entry[1] as Color, str(entry[3]))
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.set_value(float(entry[2]) / 100.0, false)
		if str(entry[0]) == "stress" and int(entry[2]) >= 75:
			g.warn_pulse()
		row.add_child(g)
		row.add_child(UIKit.label("%d" % int(entry[2]), 22, UIKit.TEXT_SOFT))
		box.add_child(row)
		gauges.append([g, int(entry[2])])
	box.set_meta("gauges", gauges)
	return box

## [key, color, value, 아이콘 글자] — 색약 대응으로 색+글자 병행(03 문서).
static func _stat_values(run: GameRun) -> Array:
	return [
		["academic", UIKit.stat_color("academic"), run.child.academic_average(), "성"],
		["emotion", UIKit.stat_color("emotion"), run.child.emotion, "정"],
		["stress", UIKit.stat_color("stress"), run.child.stress, "스"],
		["bonding", UIKit.stat_color("bonding"), run.household.bonding, "유"],
		["stamina", UIKit.stat_color("stamina"), run.child.stamina, "체"],
	]

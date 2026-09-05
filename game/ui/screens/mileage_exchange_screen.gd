class_name MileageExchangeScreen
extends UIScreen
## SCR-012 마일리지 교환소. 가챠 중복으로 쌓인 마일리지를 아직 없는 코스메틱과
## 확정 교환한다(#23). 교환 비용은 GachaScreen.MILEAGE 적립표의 10배로 짝을 맞춰
## 등급이 높을수록 비싸게 뒀다 — 가챠 확률·천장·적립 수치는 건드리지 않는다.

const EXCHANGE_COST := {"special": 1000, "rare": 200, "normal": 50}
const TIERS := ["special", "rare", "normal"]

var _mileage_label: Label
var _list: VBoxContainer

func enter(_data: Variant = null) -> void:
	GameController.track("raise_mileage_exchange_view", {})
	var root := page_root(54)

	var top := UIKit.hbox(8)
	top.add_child(UIKit.title("마일리지 교환소", 34))
	top.add_child(UIKit.spacer())
	_mileage_label = UIKit.label("", 24, UIKit.TEXT)
	top.add_child(_mileage_label)
	root.add_child(top)

	root.add_child(UIKit.label(
		"뽑기에서 중복으로 나온 코스메틱은 마일리지로 바뀌어요. 쌓인 마일리지로 아직 없는 코스메틱을 확정 교환할 수 있어요.",
		22, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))

	var body := scroll_body(root)
	_list = UIKit.vbox(8)
	body.add_child(_list)
	_refresh()

	var back := UIKit.button("뽑기로")
	back.pressed.connect(func() -> void:
		AudioBus.tap()
		router.goto("gacha"))
	root.add_child(back)
	FX.stagger_children(root, 0.05)

func _refresh() -> void:
	var p: Profile = GameController.profile
	_mileage_label.text = "마일리지 %d" % p.mileage
	for c: Node in _list.get_children():
		c.queue_free()
	var any_row := false
	for tier: String in TIERS:
		var pool: Array = GachaScreen.POOL[tier]
		for item: String in pool:
			if p.owned_cosmetics.has(item):
				continue
			any_row = true
			_list.add_child(_exchange_row(tier, item, p))
	if not any_row:
		_list.add_child(UIKit.label("교환할 수 있는 코스메틱을 모두 보유했어요!", 24, UIKit.TEXT_SOFT))

func _exchange_row(tier: String, item: String, p: Profile) -> Control:
	var color := UIKit.SAGE
	var tname := "일반"
	match tier:
		"special": color = UIKit.TALENT; tname = "스페셜"
		"rare": color = UIKit.BLUE; tname = "레어"
	var cost := int(EXCHANGE_COST[tier])
	var can_afford := p.mileage >= cost

	var row := UIKit.panel(UIKit.CARD, 14)
	var h := UIKit.hbox(8)
	row.add_child(h)
	h.add_child(UIKit.label("[%s]" % tname, 20, color))
	var name_label := UIKit.label(item, 24, UIKit.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_label)

	var btn_text := "교환 · %d" % cost
	if not can_afford:
		btn_text = "교환 · %d (부족 %d)" % [cost, cost - p.mileage]
	var btn := UIKit.button(btn_text)
	btn.disabled = not can_afford
	btn.custom_minimum_size = Vector2(180, UIKit.TOUCH_MIN)
	btn.pressed.connect(_exchange.bind(tier, item, cost))
	h.add_child(btn)
	return row

func _exchange(_tier: String, item: String, cost: int) -> void:
	var p: Profile = GameController.profile
	if p.mileage < cost or p.owned_cosmetics.has(item):
		return  # 화면이 새로고침되지 않은 사이 상태가 바뀐 경우의 방어적 재검증.
	p.mileage -= cost
	p.owned_cosmetics.append(item)
	GameController.save_game()
	GameController.track("raise_mileage_exchange", {"item": item, "cost": cost})
	AudioBus.positive()
	router.toast("%s 교환 완료!" % item)
	_refresh()

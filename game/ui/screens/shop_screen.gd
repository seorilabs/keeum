class_name ShopScreen
extends UIScreen
## SCR-009 상점. 수익화 허브. 과금은 편의·코스메틱만(명문대·좋은 엔딩은 살 수 없음).
## 실제 결제는 Play Billing·StoreKit 어댑터 연동(06 문서). 여기서는 스텁.

const PRODUCTS := [
	{"name": "광고 제거 (영구)", "price": "₩9,900", "desc": "전면광고 제거 + 젬 120 보너스"},
	{"name": "스타터팩", "price": "₩2,900", "desc": "젬 300 + 코스튬 1종 + 재력 보너스 (계정 1회)"},
	{"name": "시즌패스", "price": "₩12,000", "desc": "유·무료 트랙 · 시즌 코스튬 라인업"},
	{"name": "젬 600", "price": "₩5,900", "desc": "첫 구매 한정 2배"},
	{"name": "젬 1,300", "price": "₩12,000", "desc": "가장 인기"},
]

func enter(_data: Variant = null) -> void:
	GameController.track("raise_store_view", {})
	var root := page_root(56)

	var top := UIKit.hbox(8)
	top.add_child(UIKit.title("상점", 38))
	top.add_child(UIKit.spacer())
	top.add_child(UIKit.icon_text("gem", "%d" % GameController.profile.premium, 26, UIKit.PREMIUM))
	root.add_child(top)

	var body := scroll_body(root)

	var gacha := UIKit.icon_button("ribbon", "코스메틱 뽑기 (확률·천장 공개)", true)
	gacha.pressed.connect(func() -> void:
		AudioBus.tap()
		router.goto("gacha"))
	body.add_child(gacha)

	body.add_child(UIKit.spacer(6))
	body.add_child(UIKit.label("공정성 원칙: 과금은 편의·코스메틱만. 명문대와 좋은 엔딩은 돈으로 살 수 없어요.",
		22, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))

	for p: Dictionary in PRODUCTS:
		body.add_child(_product(p))

	var back := UIKit.button("홈으로")
	back.pressed.connect(func() -> void:
		AudioBus.tap()
		router.goto("home"))
	root.add_child(back)
	FX.stagger_children(body, 0.05)

func _product(p: Dictionary) -> Control:
	var panel := UIKit.panel(UIKit.CARD, 18)
	var h := UIKit.hbox(10)
	panel.add_child(h)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(str(p.get("name", "")), 26, UIKit.TEXT))
	v.add_child(UIKit.label(str(p.get("desc", "")), 20, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
	h.add_child(v)
	var buy := UIKit.button(str(p.get("price", "")))
	buy.custom_minimum_size = Vector2(140, UIKit.TOUCH_MIN)
	buy.pressed.connect(func() -> void:
		AudioBus.tap()
		GameController.track("raise_paywall_view", {"trigger": "shop"})
		router.toast("결제는 스토어 연동 빌드에서 진행돼요"))
	h.add_child(buy)
	return panel

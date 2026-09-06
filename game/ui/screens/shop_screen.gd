class_name ShopScreen
extends UIScreen
## SCR-009 상점. 수익화 허브. 과금은 편의·코스메틱만(명문대·좋은 엔딩은 살 수 없음).
## 실제 결제는 Play Billing·StoreKit 어댑터 연동(06 문서, #31).
##
## 상품 이름·혜택 설명은 화면이 소유하는 고정 카피지만, 가격·구매 가능 여부는
## `ShopCatalog`(결제 어댑터 경계)가 돌려준다. 어댑터가 상품을 돌려주지 않는 한
## 확정 가격표와 구매 버튼은 뜨지 않고 "준비 중" 상태만 보인다(#31).
const OFFERINGS := [
	{"id": "remove_ads", "name": "광고 제거 (영구)", "desc": "전면광고 제거 + 젬 120 보너스"},
	{"id": "starter_pack", "name": "스타터팩", "desc": "젬 300 + 코스튬 1종 + 재력 보너스 (계정 1회)"},
	{"id": "season_pass", "name": "시즌패스", "desc": "유·무료 트랙 · 시즌 코스튬 라인업"},
	{"id": "gem_600", "name": "젬 600", "desc": "첫 구매 한정 2배"},
	{"id": "gem_1300", "name": "젬 1,300", "desc": "가장 인기"},
]

## 테스트 전용 관측 지점(#31). offer id -> 이름 Label(항상), offer id -> 구매 Button(가격이
## 있을 때만). 헤드리스 검증이 렌더 결과를 직접 확인하는 데 쓴다.
var _offer_name_labels: Dictionary = {}
var _priced_buy_buttons: Dictionary = {}

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

	var priced_by_id := {}
	for offer: Dictionary in ShopCatalog.priced_offers():
		priced_by_id[str(offer.get("id", ""))] = str(offer.get("price", ""))

	for o: Dictionary in OFFERINGS:
		body.add_child(_product(o, str(priced_by_id.get(str(o.get("id", "")), ""))))

	var back := UIKit.button("홈으로")
	back.pressed.connect(func() -> void:
		AudioBus.tap()
		router.goto("home"))
	root.add_child(back)
	FX.stagger_children(body, 0.05)

## 가격이 없으면(어댑터 미연동) 구매 버튼 자체를 만들지 않는다 — 계측 발화 지점을
## 버튼 존재와 묶어, 없는 버튼이 눌린 것처럼 잘못 계측될 여지를 없앤다(#31).
func _product(o: Dictionary, price: String) -> Control:
	var panel := UIKit.panel(UIKit.CARD, 18)
	var h := UIKit.hbox(10)
	panel.add_child(h)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIKit.label(str(o.get("name", "")), 26, UIKit.TEXT)
	v.add_child(name_label)
	v.add_child(UIKit.label(str(o.get("desc", "")), 20, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
	h.add_child(v)
	_offer_name_labels[str(o.get("id", ""))] = name_label
	if price == "":
		h.add_child(UIKit.label("준비 중", 22, UIKit.TEXT_SOFT))
	else:
		var buy := UIKit.button(price)
		buy.custom_minimum_size = Vector2(140, UIKit.TOUCH_MIN)
		buy.pressed.connect(func() -> void:
			AudioBus.tap()
			GameController.track("raise_paywall_view", {"trigger": "shop"})
			router.toast("결제는 스토어 연동 빌드에서 진행돼요"))
		h.add_child(buy)
		_priced_buy_buttons[str(o.get("id", ""))] = buy
	return panel

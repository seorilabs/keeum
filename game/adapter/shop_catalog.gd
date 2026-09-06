class_name ShopCatalog
extends RefCounted
## 상점 결제 어댑터 경계(#31). Play Billing·StoreKit 연동 전까지는 항상 "상품 없음"을
## 돌려줘, 확정 가격표가 결제도 안 되는 화면에 뜨지 않게 한다.
##
## 상품 이름·혜택 설명(마케팅 카피)은 화면이 소유하는 고정 콘텐츠다. 이 어댑터가 돌려주는
## 것은 스토어만 알 수 있는 값 — 지역·통화·프로모션에 따라 달라지는 가격과 구매 가능
## 여부 — 뿐이다. 실제 SDK 를 붙일 때는 이 파일의 조회부만 바꾸면 화면 코드는 그대로다.

## 헤드리스 검증이 값이 있는 응답을 주입할 때만 쓰는 스텁 오버라이드.
static var _stub_priced_offers: Array = []

## product id -> "₩9,900" 같은 표시용 가격 문자열이 있는 항목만 돌려준다.
## 결제 어댑터가 아직 없으므로 오버라이드가 없으면 항상 빈 배열이다.
static func priced_offers() -> Array:
	return _stub_priced_offers.duplicate(true)

## 테스트 전용: 어댑터가 상품을 돌려주는 상태를 흉내 낸다.
static func set_test_priced_offers(offers: Array) -> void:
	_stub_priced_offers = offers

## 테스트 전용: 미연동 스텁 상태(상품 없음)로 되돌린다.
static func reset_test_priced_offers() -> void:
	_stub_priced_offers = []

class_name UIScreen
extends Control
## 화면 기반 클래스. 라우터가 setup 후 enter(data) 를 호출한다.
## 각 화면은 컨테이너 기반으로 반응형 레이아웃을 구성한다(세로 고정, safe area 여백).

var router: Node

func setup(p_router: Node) -> void:
	router = p_router
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

## 오버라이드: 화면 콘텐츠 구성.
func enter(_data: Variant = null) -> void:
	pass

# ---------------------------------------------------------------- 공통 스캐폴드
## safe area 여백을 준 전체 세로 레이아웃 루트(VBox) 반환. 노치·제스처바 인셋을 실측 반영.
func page_root(top_margin: int = 54, side: int = 22, bottom: int = 34) -> VBoxContainer:
	var ins := UIKit.safe_insets()
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", maxi(top_margin, int(ins["top"]) + 8))
	# 하단 CTA 가 제스처 내비게이션 힌트와 겹치지 않도록 인셋 위에 여유를 더 준다.
	m.add_theme_constant_override("margin_bottom", maxi(bottom, int(ins["bottom"]) + 16))
	add_child(m)
	var v := UIKit.vbox(16)
	m.add_child(v)
	return v

## 스크롤 가능한 본문 VBox 반환(긴 콘텐츠용).
func scroll_body(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := UIKit.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v

func reduce_motion() -> bool:
	return FX.reduced()

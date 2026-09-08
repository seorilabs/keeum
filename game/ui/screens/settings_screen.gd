class_name SettingsScreen
extends UIScreen
## SCR-011 설정. 접근성(모션 감소·음소거)·데이터·면책 고지.

var _reset_armed := false
var _reset_btn: Button

func enter(_data: Variant = null) -> void:
	var root := page_root(56)
	root.add_child(UIKit.title("설정", 38))

	var body := scroll_body(root)

	body.add_child(_toggle("소리", not Settings.muted, func(on: bool) -> void:
		Settings.set_value("muted", not on)))

	body.add_child(_slider("배경음악 볼륨", Settings.bgm_volume, func(v: float) -> void:
		Settings.set_value("bgm_volume", v)))
	body.add_child(_slider("효과음 볼륨", Settings.sfx_volume, func(v: float) -> void:
		Settings.set_value("sfx_volume", v)
		AudioBus.tap()))

	body.add_child(_toggle("모션 감소 (파티클·바운스 축소)", Settings.reduce_motion, func(on: bool) -> void:
		Settings.set_value("reduce_motion", on)))

	body.add_child(_haptic_row())

	body.add_child(_font_scale_row())

	body.add_child(_toggle("이벤트 텍스트 낭독 (TTS)", false, func(on: bool) -> void:
		router.toast("TTS는 실기기 빌드에서 지원돼요" if on else "")))

	body.add_child(UIKit.spacer(8))
	var notice := UIKit.panel(UIKit.CARD, 18)
	var nv := UIKit.vbox(6)
	notice.add_child(nv)
	nv.add_child(UIKit.label("허구 면책 고지", 24, UIKit.TEXT))
	nv.add_child(UIKit.label("이 게임의 대학·학원·강사·상품명은 모두 가상입니다. 실존 기관·인물·상표와 무관하며, 특정 방식을 권장하지 않습니다.",
		21, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
	body.add_child(notice)

	body.add_child(UIKit.spacer(8))
	_reset_btn = UIKit.button("데이터 초기화")
	_reset_btn.pressed.connect(_on_reset)
	body.add_child(_reset_btn)

	var back := UIKit.button("홈으로", true)
	back.pressed.connect(func() -> void:
		AudioBus.tap()
		router.goto("home" if GameController.run != null else "onboarding"))
	root.add_child(back)

func _slider(label: String, initial: float, cb: Callable) -> Control:
	var panel := UIKit.panel(UIKit.CARD, 16)
	var v := UIKit.vbox(6)
	panel.add_child(v)
	v.add_child(UIKit.label(label, 26, UIKit.TEXT))
	var s := UIKit.slider(initial)
	s.value_changed.connect(func(val: float) -> void: cb.call(val))
	v.add_child(s)
	return panel

## 햅틱 강도 3택(끔·보통·강) — 03 문서 접근성 계약.
func _haptic_row() -> Control:
	var panel := UIKit.panel(UIKit.CARD, 16)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	v.add_child(UIKit.label("햅틱 (진동 세기)", 26, UIKit.TEXT))
	var row := UIKit.hbox(8)
	var btns: Dictionary = {}
	for pair: Array in [[0, "끔"], [1, "보통"], [2, "강"]]:
		var level := int(pair[0])
		var b := UIKit.button(str(pair[1]), Settings.haptic_level == level)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns[level] = b
		row.add_child(b)
	for level: int in btns:
		(btns[level] as Button).pressed.connect(func() -> void:
			Settings.set_value("haptic_level", level)
			FX.haptic(2)
			for l2: int in btns:
				_restyle_choice(btns[l2] as Button, l2 == level))
	v.add_child(row)
	return panel

## 글자 크기 3택(보통·크게·아주 크게) — 03 문서 접근성 계약(#35). 폰트 크기는 생성 시점에
## 굳으므로 다른 버튼처럼 제자리 restyle만으로는 부족하다 — 고른 즉시 이 화면을 다시 세운다
## (jomul 접근성 설정 교훈: 토글을 누른 자리에서 화면을 다시 세워야 한다).
func _font_scale_row() -> Control:
	var panel := UIKit.panel(UIKit.CARD, 16)
	var v := UIKit.vbox(8)
	panel.add_child(v)
	v.add_child(UIKit.label("글자 크기", 26, UIKit.TEXT))
	var row := UIKit.hbox(8)
	for pair: Array in [[0, "보통"], [1, "크게"], [2, "아주 크게"]]:
		var tier := int(pair[0])
		var b := UIKit.button(str(pair[1]), Settings.font_scale_tier == tier)
		b.name = "FontScaleTier%d" % tier
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		b.pressed.connect(func() -> void:
			Settings.set_value("font_scale_tier", tier)
			FX.haptic(2)
			router.goto("settings"))
	v.add_child(row)
	return panel


func _restyle_choice(b: Button, selected: bool) -> void:
	var bg := UIKit.CORAL if selected else UIKit.CARD
	b.add_theme_color_override("font_color", Color.WHITE if selected else UIKit.TEXT)
	b.add_theme_stylebox_override("normal", UIKit._btn_style(bg))
	b.add_theme_stylebox_override("hover", UIKit._btn_style(bg.lightened(0.05)))

func _toggle(label: String, initial: bool, cb: Callable) -> Control:
	var panel := UIKit.panel(UIKit.CARD, 16)
	var h := UIKit.hbox(8)
	panel.add_child(h)
	var l := UIKit.label(label, 26, UIKit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var sw := ToggleSwitch.new()
	sw.setup(initial)
	sw.toggled_on.connect(func(on: bool) -> void: cb.call(on))
	h.add_child(sw)
	return panel

func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "정말 초기화할까요? (한 번 더 누르기)"
		AudioBus.stress_nudge()
		return
	GameController.reset_all()
	AudioBus.chime()
	router.goto("onboarding")

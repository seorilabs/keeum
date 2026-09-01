class_name ToggleSwitch
extends Control
## 게임 톤(코랄·크림)에 맞춘 커스텀 스위치. Godot 기본 CheckButton 의 회색 아이콘 대신
## _draw 로 그려 다른 UI 와 같은 아트 방향을 유지한다(03 문서 디자인 시스템).

signal toggled_on(on: bool)

var on := false
var _knob := 0.0  # 0=끔 1=켬 (애니메이션 값)

func setup(initial: bool) -> void:
	on = initial
	_knob = 1.0 if initial else 0.0
	custom_minimum_size = Vector2(96, 52)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		on = not on
		AudioBus.tap()
		FX.haptic(1)
		if FX.reduced():
			_knob = 1.0 if on else 0.0
			queue_redraw()
		else:
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void:
				_knob = v
				queue_redraw(), _knob, 1.0 if on else 0.0, 0.16) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggled_on.emit(on)
		accept_event()

func _draw() -> void:
	var h := minf(size.y, 52.0)
	var w := minf(size.x, 96.0)
	var y := (size.y - h) * 0.5
	var x := size.x - w
	var r := h * 0.5
	var track := UIKit.CREAM_DEEP.lerp(UIKit.CORAL, _knob)
	# 트랙(캡슐)
	draw_circle(Vector2(x + r, y + r), r, track)
	draw_circle(Vector2(x + w - r, y + r), r, track)
	draw_rect(Rect2(x + r, y, w - h, h), track, true)
	# 노브
	var kx := lerpf(x + r, x + w - r, _knob)
	draw_circle(Vector2(kx, y + r), r * 0.78, Color(1, 1, 1, 0.97))
	draw_circle(Vector2(kx, y + r), r * 0.78, Color(0.29, 0.25, 0.22, 0.06))

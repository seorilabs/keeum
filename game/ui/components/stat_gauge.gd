class_name StatGauge
extends Control
## 얇은 스탯 게이지(상단 정보바용). 아이콘 병행으로 색약 대응(03 문서).

var value := 0.0        # 0~1
var display_value := 0.0
var color := Color("7FA9D9")
var icon_char := ""
var caption := ""
var pulse := false
var _pulse_t := 0.0

func setup(p_color: Color, p_icon: String, p_caption: String = "") -> void:
	color = p_color
	icon_char = p_icon
	caption = p_caption
	custom_minimum_size = Vector2(0, 26)

func _ready() -> void:
	set_process(false)  # 보간·펄스가 있을 때만 켠다(HUD 게이지 상시 _process 방지)

func set_value(v: float, animate: bool = true) -> void:
	value = clampf(v, 0.0, 1.0)
	if not animate or FX.reduced():
		display_value = value
	elif absf(display_value - value) > 0.001:
		set_process(true)
	queue_redraw()

func warn_pulse() -> void:
	pulse = true
	_pulse_t = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if absf(display_value - value) > 0.001:
		display_value = lerpf(display_value, value, clampf(delta * 8.0, 0.0, 1.0))
		queue_redraw()
	if pulse:
		_pulse_t += delta
		if _pulse_t > 1.2:
			pulse = false
		queue_redraw()
	if not pulse and absf(display_value - value) <= 0.001:
		display_value = value
		set_process(false)

func _draw() -> void:
	var track_h := 12.0
	var y := (size.y - track_h) * 0.5
	var x0 := 34.0
	var w := size.x - x0 - 8.0
	# 아이콘 원
	draw_circle(Vector2(16, size.y * 0.5), 13, color)
	var f: Font = UIKit.body_font if UIKit.body_font != null else ThemeDB.fallback_font
	if icon_char != "":
		draw_string(f, Vector2(5, size.y * 0.5 + 7), icon_char, HORIZONTAL_ALIGNMENT_CENTER, 22, 18, Color.WHITE)
	# 트랙
	_rounded(Rect2(x0, y, w, track_h), Color(0.29, 0.25, 0.22, 0.12))
	# 채움
	var fill_w := maxf(track_h, w * display_value)
	var c := color
	if pulse:
		var glow: float = 0.5 + 0.5 * sin(_pulse_t * 12.0)
		c = color.lerp(Color.WHITE, glow * 0.5)
	_rounded(Rect2(x0, y, fill_w, track_h), c)

func _rounded(r: Rect2, c: Color) -> void:
	# 캡슐(양끝 반원 + 중앙 사각)로 실제 둥근 트랙을 그린다.
	var rad := r.size.y * 0.5
	var cy := r.position.y + rad
	draw_circle(Vector2(r.position.x + rad, cy), rad, c)
	draw_circle(Vector2(r.end.x - rad, cy), rad, c)
	if r.size.x > r.size.y:
		draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), c, true)

class_name GameIcon
extends Control
## 절차적 벡터 아이콘. 이모지 대체(웹 폰트 폴백 부재 대응) — _draw 로 직접 그린다.
## 게임의 다른 요소(캐릭터·장면·게이지)와 같은 프로시저 드로잉 아트 방향을 따른다.

var kind := "coin"
var icon_color := Color.WHITE
var _has_color := false

const DEFAULT_COLOR := {
	"coin": Color("E8B54D"), "gem": Color("3FA6B8"), "book": Color("E5735E"),
	"bag": Color("E5735E"), "gear": Color("6B5D50"), "film": Color("4A4038"),
	"ribbon": Color("E890A2"), "sparkle": Color("D69A2E"), "warning": Color("D69A2E"),
	"play": Color("6B5D50"), "heart": Color("E890A2"), "dice": Color("E5735E"),
	"check": Color("5F9A58"),
}

static func make(icon_kind: String, px: float = 28.0, color: Variant = null) -> GameIcon:
	var g := GameIcon.new()
	g.kind = icon_kind
	g.custom_minimum_size = Vector2(px, px)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color != null:
		g.icon_color = color
		g._has_color = true
	return g

func set_kind(k: String) -> void:
	kind = k
	queue_redraw()

func _col() -> Color:
	if _has_color:
		return icon_color
	return DEFAULT_COLOR.get(kind, Color("3A322B"))  # UIKit.TEXT (순환 참조 방지 위해 리터럴)

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	# 생성 아이콘(icon_<kind>)이 있으면 풀컬러 텍스처를 contain-fit 으로(색 파라미터는 무시).
	var tex := Art.tex("icon_" + kind)
	if tex != null:
		var ts := tex.get_size()
		var sc := s / maxf(ts.x, ts.y)
		var dw := ts.x * sc
		var dh := ts.y * sc
		draw_texture_rect(tex, Rect2(c.x - dw * 0.5, c.y - dh * 0.5, dw, dh), false)
		return
	var col := _col()
	match kind:
		"coin": _coin(c, s, col)
		"gem": _gem(c, s, col)
		"book": _book(c, s, col)
		"bag": _bag(c, s, col)
		"gear": _gear(c, s, col)
		"film": _film(c, s, col)
		"ribbon": _ribbon(c, s, col)
		"sparkle": _sparkle(c, s, col)
		"warning": _warning(c, s, col)
		"play": _play(c, s, col)
		"heart": _heart(c, s, col)
		"dice": _dice(c, s, col)
		"check": _check(c, s, col)

func _coin(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c, s * 0.42, col)
	draw_circle(c, s * 0.32, col.lightened(0.20))
	draw_arc(c, s * 0.37, PI * 1.05, PI * 1.5, 12, Color(1, 1, 1, 0.5), s * 0.05)

func _gem(c: Vector2, s: float, col: Color) -> void:
	var top := c.y - s * 0.22
	var w2 := s * 0.30
	var crown := c.y - s * 0.34
	var cw := s * 0.20
	var bot := c.y + s * 0.36
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - cw, crown), Vector2(c.x + cw, crown),
		Vector2(c.x + w2, top), Vector2(c.x - w2, top)]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - w2, top), Vector2(c.x + w2, top), Vector2(c.x, bot)]), col.lightened(0.08))
	var fl := col.darkened(0.20)
	draw_line(Vector2(c.x - cw, crown), Vector2(c.x, bot), fl, s * 0.03)
	draw_line(Vector2(c.x + cw, crown), Vector2(c.x, bot), fl, s * 0.03)
	draw_line(Vector2(c.x - w2, top), Vector2(c.x + w2, top), fl, s * 0.03)

func _book(c: Vector2, s: float, col: Color) -> void:
	var top := c.y - 0.22 * s
	var bot := c.y + 0.26 * s
	var mtop := c.y - 0.27 * s
	var mbot := c.y + 0.31 * s
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, mtop), Vector2(c.x - 0.34 * s, top),
		Vector2(c.x - 0.34 * s, bot), Vector2(c.x, mbot)]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, mtop), Vector2(c.x + 0.34 * s, top),
		Vector2(c.x + 0.34 * s, bot), Vector2(c.x, mbot)]), Color("5E8CC7"))  # UIKit.BLUE
	for i in 2:
		var yy := c.y - 0.04 * s + float(i) * 0.13 * s
		draw_line(Vector2(c.x - 0.26 * s, yy + 0.03 * s), Vector2(c.x - 0.06 * s, yy), Color(1, 1, 1, 0.7), s * 0.03)
		draw_line(Vector2(c.x + 0.06 * s, yy), Vector2(c.x + 0.26 * s, yy + 0.03 * s), Color(1, 1, 1, 0.7), s * 0.03)

func _bag(c: Vector2, s: float, col: Color) -> void:
	draw_arc(Vector2(c.x - 0.13 * s, c.y - 0.06 * s), 0.11 * s, PI, TAU, 12, col.darkened(0.12), s * 0.05)
	draw_arc(Vector2(c.x + 0.13 * s, c.y - 0.06 * s), 0.11 * s, PI, TAU, 12, col.darkened(0.12), s * 0.05)
	draw_rect(Rect2(c.x - 0.28 * s, c.y - 0.08 * s, 0.56 * s, 0.44 * s), col, true)
	draw_line(Vector2(c.x - 0.28 * s, c.y + 0.02 * s), Vector2(c.x + 0.28 * s, c.y + 0.02 * s), Color(1, 1, 1, 0.35), s * 0.03)

func _gear(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c, 0.32 * s, col)
	for i in 8:
		var a := TAU * float(i) / 8.0
		draw_circle(c + Vector2(cos(a), sin(a)) * 0.40 * s, 0.09 * s, col)
	draw_circle(c, 0.13 * s, Color("FBF3E7"))  # UIKit.CREAM (hole)

func _film(c: Vector2, s: float, col: Color) -> void:
	var by := c.y - 0.28 * s
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 0.30 * s, by), Vector2(c.x + 0.30 * s, by - 0.04 * s),
		Vector2(c.x + 0.30 * s, by + 0.10 * s), Vector2(c.x - 0.30 * s, by + 0.14 * s)]), col)
	for i in 3:
		var xx := c.x - 0.22 * s + float(i) * 0.18 * s
		draw_line(Vector2(xx, by - 0.01 * s), Vector2(xx + 0.06 * s, by + 0.12 * s), Color(1, 1, 1, 0.85), s * 0.035)
	draw_rect(Rect2(c.x - 0.30 * s, c.y - 0.12 * s, 0.60 * s, 0.42 * s), col.lightened(0.06), true)

func _ribbon(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y), Vector2(c.x - 0.32 * s, c.y - 0.22 * s), Vector2(c.x - 0.32 * s, c.y + 0.22 * s)]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y), Vector2(c.x + 0.32 * s, c.y - 0.22 * s), Vector2(c.x + 0.32 * s, c.y + 0.22 * s)]), col)
	draw_circle(c, 0.10 * s, col.darkened(0.14))

func _sparkle(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - 0.42 * s), Vector2(c.x + 0.13 * s, c.y),
		Vector2(c.x, c.y + 0.42 * s), Vector2(c.x - 0.13 * s, c.y)]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 0.42 * s, c.y), Vector2(c.x, c.y + 0.13 * s),
		Vector2(c.x + 0.42 * s, c.y), Vector2(c.x, c.y - 0.13 * s)]), col)
	draw_circle(Vector2(c.x + 0.30 * s, c.y - 0.30 * s), 0.06 * s, col)

func _warning(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - 0.36 * s), Vector2(c.x + 0.36 * s, c.y + 0.30 * s),
		Vector2(c.x - 0.36 * s, c.y + 0.30 * s)]), col)
	draw_rect(Rect2(c.x - 0.035 * s, c.y - 0.14 * s, 0.07 * s, 0.26 * s), Color("FFFDF6"), true)
	draw_circle(Vector2(c.x, c.y + 0.20 * s), 0.05 * s, Color("FFFDF6"))

func _play(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 0.20 * s, c.y - 0.28 * s), Vector2(c.x + 0.30 * s, c.y),
		Vector2(c.x - 0.20 * s, c.y + 0.28 * s)]), col)

func _heart(c: Vector2, s: float, col: Color) -> void:
	var r := 0.20 * s
	draw_circle(Vector2(c.x - r * 0.6, c.y - r * 0.35), r * 0.64, col)
	draw_circle(Vector2(c.x + r * 0.6, c.y - r * 0.35), r * 0.64, col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - r * 1.15, c.y - r * 0.02), Vector2(c.x + r * 1.15, c.y - r * 0.02),
		Vector2(c.x, c.y + r * 1.28)]), col)

func _dice(c: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(c.x - 0.34 * s, c.y - 0.34 * s, 0.68 * s, 0.68 * s), col, true)
	var pr := 0.07 * s
	var o := 0.18 * s
	for p: Vector2 in [Vector2(-o, -o), Vector2(o, -o), Vector2(0, 0), Vector2(-o, o), Vector2(o, o)]:
		draw_circle(c + p, pr, Color("FFFDF6"))

func _check(c: Vector2, s: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([
		Vector2(c.x - 0.26 * s, c.y + 0.02 * s), Vector2(c.x - 0.06 * s, c.y + 0.22 * s),
		Vector2(c.x + 0.28 * s, c.y - 0.22 * s)]), col, s * 0.10)

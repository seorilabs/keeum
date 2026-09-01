class_name FxBurst
extends Control
## _draw 기반 경량 파티클 버스트(1노드 1드로우, 수명 후 자동 해제).
## gl_compatibility·웹에서 안전하고 색 토큰을 그대로 쓴다. 04 문서 VFX 언어:
## 긍정=반짝이·하트, 보상=confetti, 스페셜=glow. FPS 저하 시 개수 자동 감소.

const DUR := 0.9

var _parts: Array[Dictionary] = []
var _kind := "sparkle"
var _life := 0.0


static func burst(parent: Control, at: Vector2, kind: String = "sparkle", count: int = 14) -> void:
	if FX.reduced() or parent == null or not parent.is_inside_tree():
		return
	var n := count
	if Engine.get_frames_per_second() < 40.0:
		n = maxi(4, int(float(count) * 0.5))  # 발열·저사양 시 파티클 자동 감소(06 문서 예산)
	var fb := FxBurst.new()
	fb._kind = kind
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.z_index = 60
	fb.position = at
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if kind == "glow":
		fb._parts.append({"vel": Vector2.ZERO, "size": 46.0, "rot": 0.0,
			"color": Color(0.66, 0.46, 0.77)})
	else:
		for i in n:
			var ang := rng.randf_range(-PI, PI)
			var speed := rng.randf_range(90.0, 240.0)
			fb._parts.append({
				"vel": Vector2(cos(ang), sin(ang) * 0.8 - 0.55) * speed,
				"size": rng.randf_range(7.0, 15.0),
				"rot": rng.randf_range(-PI, PI),
				"color": _pick_color(kind, rng),
			})
	parent.add_child(fb)


static func _pick_color(kind: String, rng: RandomNumberGenerator) -> Color:
	match kind:
		"heart":
			return UIKit.PINK if rng.randf() < 0.6 else Color("F4B8C1")
		"confetti":
			var pool: Array[Color] = [UIKit.CORAL, UIKit.SAGE, UIKit.BLUE, UIKit.AMBER, UIKit.PINK]
			return pool[rng.randi() % pool.size()]
	return UIKit.AMBER if rng.randf() < 0.7 else Color("F3D89A")


func _process(delta: float) -> void:
	_life += delta
	if _life >= DUR:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _life / DUR
	var alpha := clampf(1.0 - t * t, 0.0, 1.0)
	if _kind == "glow":
		var r := lerpf(30.0, 150.0, t)
		var c: Color = (_parts[0]["color"] as Color)
		c.a = alpha * 0.35
		draw_circle(Vector2.ZERO, r, c)
		c.a = alpha * 0.8
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, 4.0)
		return
	for p: Dictionary in _parts:
		var vel: Vector2 = p["vel"]
		var pos := vel * _life + Vector2(0.0, 190.0) * _life * _life
		var sz := float(p["size"]) * (1.0 - t * 0.4)
		var c: Color = p["color"]
		c.a = alpha
		match _kind:
			"heart":
				_draw_heart(pos, sz, c)
			"confetti":
				draw_set_transform(pos, float(p["rot"]) + t * 5.0, Vector2.ONE)
				draw_rect(Rect2(-sz * 0.5, -sz * 0.35, sz, sz * 0.7), c, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				var w := maxf(2.0, sz * 0.22)
				draw_line(pos + Vector2(-sz, 0), pos + Vector2(sz, 0), c, w)
				draw_line(pos + Vector2(0, -sz), pos + Vector2(0, sz), c, w)


func _draw_heart(c: Vector2, r: float, col: Color) -> void:
	var lobe := r * 0.5
	draw_circle(c + Vector2(-lobe * 0.9, -lobe * 0.5), lobe, col)
	draw_circle(c + Vector2(lobe * 0.9, -lobe * 0.5), lobe, col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.92, -lobe * 0.25),
		c + Vector2(r * 0.92, -lobe * 0.25),
		c + Vector2(0.0, r * 0.95),
	]), col)

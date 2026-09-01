class_name ChildAvatar
extends Control
## 자녀 캐릭터. 생성 바디 스프라이트(assets/art, face-blank)가 있으면 그 위에 표정을 코드로
## 그리고(DEC-034), 없으면 기존 프로시저 드로잉으로 폴백한다.
## 표정이 반응 컷의 생명(04 문서): 기쁨·신남·시무룩·지침·뿌듯·반항·집중.

var stage := "infant"
var expression := "happy"
var hair := "mushroom"
var skin := Color(0.97, 0.86, 0.78)
var hair_color := Color(0.30, 0.24, 0.20)
var outfit := Color("F28C79")
var cosmetics: Dictionary = {}  # slot -> 표시명 (Profile.equipped 주입)
## 배경 무대 위에 세울 때: 중앙 정렬 대신 발이 아래쪽 바닥선에 닿게 그린다.
var align_bottom := false
## 무대 대비 캐릭터 크기 비율(1.0 = 컨트롤 짧은 변 기준 최대).
var draw_scale := 1.0

var _t := 0.0
var _blink_t := 0.0
var _next_blink := 3.2
var reduce_motion := false

func set_look(p_stage: String, p_expression: String) -> void:
	stage = p_stage
	expression = p_expression
	queue_redraw()

func set_appearance(p_hair: String, p_outfit: Color) -> void:
	hair = p_hair
	outfit = p_outfit
	queue_redraw()

func _process(delta: float) -> void:
	if reduce_motion:
		return
	_t += delta
	_blink_t += delta
	if _blink_t > _next_blink + 0.14:
		_blink_t = 0.0
		_next_blink = randf_range(2.6, 5.2)
	queue_redraw()

func _blinking() -> bool:
	return not reduce_motion and _blink_t > _next_blink

func _draw() -> void:
	var s := minf(size.x, size.y) * draw_scale
	var cx := size.x * 0.5
	var bob := 0.0 if reduce_motion else sin(_t * 2.2) * s * 0.012
	var cy := size.y * 0.5 + bob
	if align_bottom:
		cy = size.y - s * 0.5 + bob

	# 생성 바디 스프라이트 경로(있으면 우선).
	var body_name := Art.char_body_name(stage, hair, str(cosmetics.get("outfit", "")))
	var body_tex := Art.tex(body_name)
	if body_tex != null:
		_draw_sprite(body_tex, body_name, s, cx, cy)
		return

	# ---------------- 프로시저 폴백 ----------------
	# 성장 단계별 비율(유아 동글 → 고등 길쭉).
	var head_r := s * 0.20
	var body_h := s * 0.30
	match stage:
		"infant": head_r = s * 0.23; body_h = s * 0.24
		"elementary": head_r = s * 0.20; body_h = s * 0.30
		"middle": head_r = s * 0.18; body_h = s * 0.34
		"high", "exam": head_r = s * 0.165; body_h = s * 0.38

	var head_cy := cy - body_h * 0.35
	var body_top := head_cy + head_r * 0.72

	# 그림자
	draw_circle(Vector2(cx, cy + body_h * 0.62), s * 0.22, Color(0.29, 0.25, 0.22, 0.08))

	# 몸통(둥근 사다리꼴)
	var bw := head_r * 1.7
	var body_col := _outfit_color()
	var body_pts := PackedVector2Array([
		Vector2(cx - bw * 0.5, body_top),
		Vector2(cx + bw * 0.5, body_top),
		Vector2(cx + bw * 0.62, body_top + body_h),
		Vector2(cx - bw * 0.62, body_top + body_h),
	])
	draw_colored_polygon(body_pts, body_col)
	# 교복 칼라(중등 이상, 또는 교복 코스튬)
	if stage == "middle" or stage == "high" or stage == "exam" \
			or str(cosmetics.get("outfit", "")) == "새 교복 세트":
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - bw * 0.22, body_top),
			Vector2(cx + bw * 0.22, body_top),
			Vector2(cx, body_top + body_h * 0.22),
		]), Color(0.98, 0.98, 0.98, 0.9))

	# 머리
	draw_circle(Vector2(cx, head_cy), head_r, skin)
	_draw_hair(cx, head_cy, head_r)

	# 볼터치
	var cheek := Color("F4B8C1")
	cheek.a = 0.55
	draw_circle(Vector2(cx - head_r * 0.55, head_cy + head_r * 0.28), head_r * 0.20, cheek)
	draw_circle(Vector2(cx + head_r * 0.55, head_cy + head_r * 0.28), head_r * 0.20, cheek)

	_draw_face(cx, head_cy, head_r)
	_draw_stage_prop(cx, head_cy, head_r, body_top, body_h, bw)
	_draw_cosmetics(cx, head_cy, head_r, body_top, body_h, bw)

## 생성 스프라이트 + 얼굴 앵커 표정 오버레이.
func _draw_sprite(tex: Texture2D, body_name: String, s: float, cx: float, cy: float) -> void:
	var side := s * 0.96
	var rect := Rect2(cx - side * 0.5, cy - side * 0.5, side, side)
	# 발치 접지 그림자(납작한 타원) — 스프라이트 하단 기준.
	draw_set_transform(Vector2(cx, rect.end.y - side * 0.06), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, side * 0.26, Color(0.29, 0.25, 0.22, 0.13))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(tex, rect, false)
	var a := Art.face_anchor(body_name)
	var fcx := rect.position.x + rect.size.x * float(a["cx"])
	var fcy := rect.position.y + rect.size.y * float(a["cy"])
	var fr := rect.size.x * float(a["r"])
	_draw_face(fcx, fcy, fr)
	if stage == "high" or stage == "exam":
		var dc := Color(0.5, 0.55, 0.65, 0.35)
		draw_circle(Vector2(fcx - fr * 0.42, fcy + fr * 0.28), fr * 0.14, dc)
		draw_circle(Vector2(fcx + fr * 0.42, fcy + fr * 0.28), fr * 0.14, dc)
	_draw_cosmetics(fcx, fcy, fr, fcy + fr, rect.size.y * 0.38, fr * 2.2)

## outfit 코스메틱 장착 시 프로시저 몸통 색 프리셋.
func _outfit_color() -> Color:
	match str(cosmetics.get("outfit", "")):
		"봄나들이 코스튬": return Color("A7C4A0")
		"새 교복 세트": return Color("4A5A78")
		"한복 나들이 세트": return Color("E890A2")
		"우주비행사 코스튬": return Color("EDEDF2")
	return outfit

func _draw_hair(cx: float, cy: float, r: float) -> void:
	var top := cy - r
	match hair:
		"twin_tail", "long_wave":
			draw_circle(Vector2(cx - r * 0.9, cy), r * 0.35, hair_color)
			draw_circle(Vector2(cx + r * 0.9, cy), r * 0.35, hair_color)
	# 앞머리 캡
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var a := PI + PI * float(i) / float(steps)
		pts.append(Vector2(cx + cos(a) * r * 1.02, cy + sin(a) * r * 1.02))
	pts.append(Vector2(cx + r, cy - r * 0.05))
	pts.append(Vector2(cx - r, cy - r * 0.05))
	draw_colored_polygon(pts, hair_color)

func _draw_face(cx: float, cy: float, r: float) -> void:
	var ex := r * 0.42
	var ey := cy + r * 0.05
	var eye := Color("4A4038")
	if _blinking():
		# 블링크: 감은 눈(짧은 수평선)
		draw_line(Vector2(cx - ex - r * 0.14, ey), Vector2(cx - ex + r * 0.14, ey), eye, 3.0)
		draw_line(Vector2(cx + ex - r * 0.14, ey), Vector2(cx + ex + r * 0.14, ey), eye, 3.0)
	else:
		match expression:
			"happy", "excited", "proud":
				# 반달 눈(웃음)
				_draw_arc_eye(Vector2(cx - ex, ey), r * 0.18, eye, true)
				_draw_arc_eye(Vector2(cx + ex, ey), r * 0.18, eye, true)
			"tired", "sad":
				_draw_arc_eye(Vector2(cx - ex, ey), r * 0.18, eye, false)
				_draw_arc_eye(Vector2(cx + ex, ey), r * 0.18, eye, false)
			"angry":
				draw_line(Vector2(cx - ex - r * 0.15, ey - r * 0.18), Vector2(cx - ex + r * 0.12, ey - r * 0.05), eye, 3.0)
				draw_line(Vector2(cx + ex + r * 0.15, ey - r * 0.18), Vector2(cx + ex - r * 0.12, ey - r * 0.05), eye, 3.0)
				draw_circle(Vector2(cx - ex, ey), r * 0.09, eye)
				draw_circle(Vector2(cx + ex, ey), r * 0.09, eye)
			_:
				draw_circle(Vector2(cx - ex, ey), r * 0.11, eye)
				draw_circle(Vector2(cx + ex, ey), r * 0.11, eye)

	# 입
	var my := cy + r * 0.55
	match expression:
		"happy", "proud":
			_draw_smile(Vector2(cx, my), r * 0.30, eye, 1.0)
		"excited":
			draw_circle(Vector2(cx, my), r * 0.14, Color("C0605A"))
		"sad", "tired":
			_draw_smile(Vector2(cx, my + r * 0.08), r * 0.26, eye, -0.8)
		"angry":
			draw_line(Vector2(cx - r * 0.2, my), Vector2(cx + r * 0.2, my), eye, 3.0)
		"focused":
			draw_line(Vector2(cx - r * 0.12, my), Vector2(cx + r * 0.12, my), eye, 3.0)
		_:
			_draw_smile(Vector2(cx, my), r * 0.22, eye, 0.4)

	# 지침: 땀방울 / 뿌듯: 반짝
	if expression == "tired":
		draw_circle(Vector2(cx + r * 0.9, cy - r * 0.1), r * 0.10, Color("7FA9D9"))
	elif expression == "proud" or expression == "excited":
		_draw_sparkle(Vector2(cx + r * 1.05, cy - r * 0.7), r * 0.16)
		_draw_sparkle(Vector2(cx - r * 1.0, cy - r * 0.5), r * 0.11)

func _draw_arc_eye(c: Vector2, r: float, col: Color, up: bool) -> void:
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var a := (PI if up else 0.0) + PI * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * (1.0 if up else 1.0)))
	draw_polyline(pts, col, 3.0, true)

func _draw_smile(c: Vector2, r: float, col: Color, curve: float) -> void:
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var tt := float(i) / float(steps)
		var x := lerpf(-r, r, tt)
		var y := curve * r * (1.0 - pow(2.0 * tt - 1.0, 2.0)) * 0.9
		pts.append(c + Vector2(x, y))
	draw_polyline(pts, col, 3.5, true)

func _draw_sparkle(c: Vector2, r: float) -> void:
	var col := Color("E8B54D")
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, 3.0)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, 3.0)

func _draw_stage_prop(cx: float, head_cy: float, r: float, body_top: float, body_h: float, bw: float) -> void:
	match stage:
		"elementary":
			# 책가방 끈
			draw_line(Vector2(cx - bw * 0.32, body_top), Vector2(cx - bw * 0.32, body_top + body_h * 0.7), Color("E8B54D"), 6.0)
			draw_line(Vector2(cx + bw * 0.32, body_top), Vector2(cx + bw * 0.32, body_top + body_h * 0.7), Color("E8B54D"), 6.0)
		"high", "exam":
			# 다크서클
			var dc := Color(0.5, 0.55, 0.65, 0.35)
			draw_circle(Vector2(cx - r * 0.42, head_cy + r * 0.28), r * 0.14, dc)
			draw_circle(Vector2(cx + r * 0.42, head_cy + r * 0.28), r * 0.14, dc)

# ---------------------------------------------------------------- 코스메틱
## 장착 코스메틱 렌더(가챠 보상의 시각 폐쇄). Art.tex 존재 시 스프라이트, 없으면 도형.
## outfit·theme 은 여기가 아니라 몸통 색(_outfit_color)·배경(main)에서 처리.
func _draw_cosmetics(cx: float, head_cy: float, r: float, body_top: float, body_h: float, bw: float) -> void:
	for slot: String in cosmetics:
		var name := str(cosmetics[slot])
		var info := Art.cosmetic(name)
		if info.is_empty() or slot == "outfit" or slot == "theme":
			continue
		var asset := str(info.get("asset", ""))
		var t := Art.tex(asset)
		match slot:
			"hat":
				if t != null:
					draw_texture_rect(t, Rect2(cx - r * 1.2, head_cy - r * 2.1, r * 2.4, r * 1.5), false)
				else:
					_draw_strawhat(cx, head_cy, r)
			"hairpin":
				if t != null:
					draw_texture_rect(t, Rect2(cx + r * 0.35, head_cy - r * 1.25, r * 0.8, r * 0.8), false)
				else:
					_draw_ribbon_pin(Vector2(cx + r * 0.72, head_cy - r * 0.85), r * 0.30)
			"glasses":
				if t != null:
					draw_texture_rect(t, Rect2(cx - r * 0.95, head_cy - r * 0.25, r * 1.9, r * 0.8), false)
				else:
					_draw_glasses(cx, head_cy, r)
			"scarf":
				if t != null:
					draw_texture_rect(t, Rect2(cx - r * 0.95, head_cy + r * 0.75, r * 1.9, r * 0.9), false)
				else:
					draw_arc(Vector2(cx, head_cy + r * 0.78), r * 0.72, 0.25, PI - 0.25, 14, Color("F4B8C1"), r * 0.34)
			"prop":
				var at := Vector2(cx + bw * 0.95, body_top + body_h * 0.55)
				if t != null:
					draw_texture_rect(t, Rect2(at.x - r * 0.6, at.y - r * 0.9, r * 1.4, r * 1.6), false)
				elif name == "노란 우산":
					_draw_umbrella(at, r)
				else:
					_draw_puppy(at, r)
			"pet":
				var pat := Vector2(cx - bw * 1.05, head_cy + r * 0.2)
				var pbob := 0.0 if reduce_motion else sin(_t * 3.1) * r * 0.12
				if t != null:
					draw_texture_rect(t, Rect2(pat.x - r * 0.55, pat.y - r * 0.55 + pbob, r * 1.1, r * 1.1), false)
				else:
					_draw_fairy(pat + Vector2(0, pbob), r)

func _draw_strawhat(cx: float, head_cy: float, r: float) -> void:
	var straw := Color("EBCB8B")
	var band := Color("D08770")
	var top := head_cy - r * 0.95
	draw_set_transform(Vector2(cx, top), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, r * 1.45, straw)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(cx, top - r * 0.28), r * 0.72, straw)
	draw_line(Vector2(cx - r * 0.72, top - r * 0.1), Vector2(cx + r * 0.72, top - r * 0.1), band, r * 0.16)

func _draw_ribbon_pin(c: Vector2, r: float) -> void:
	var pink := Color("E890A2")
	draw_colored_polygon(PackedVector2Array([c, c + Vector2(-r, -r * 0.6), c + Vector2(-r, r * 0.6)]), pink)
	draw_colored_polygon(PackedVector2Array([c, c + Vector2(r, -r * 0.6), c + Vector2(r, r * 0.6)]), pink)
	draw_circle(c, r * 0.28, Color("C0605A"))

func _draw_glasses(cx: float, head_cy: float, r: float) -> void:
	var col := Color("4A4038")
	var ex := r * 0.42
	var ey := head_cy + r * 0.05
	draw_arc(Vector2(cx - ex, ey), r * 0.30, 0.0, TAU, 20, col, 3.0)
	draw_arc(Vector2(cx + ex, ey), r * 0.30, 0.0, TAU, 20, col, 3.0)
	draw_line(Vector2(cx - ex + r * 0.30, ey), Vector2(cx + ex - r * 0.30, ey), col, 3.0)

func _draw_umbrella(at: Vector2, r: float) -> void:
	var yel := Color("E8B54D")
	draw_arc(at, r * 0.75, PI, TAU, 16, yel, r * 0.3)
	draw_line(at, at + Vector2(0, r * 1.1), Color("4A4038"), 3.0)

func _draw_puppy(at: Vector2, r: float) -> void:
	var fur := Color("EBCB8B")
	draw_circle(at, r * 0.5, fur)
	draw_circle(at + Vector2(-r * 0.42, -r * 0.38), r * 0.18, fur)
	draw_circle(at + Vector2(r * 0.42, -r * 0.38), r * 0.18, fur)
	draw_circle(at + Vector2(-r * 0.16, -r * 0.05), r * 0.05, Color("4A4038"))
	draw_circle(at + Vector2(r * 0.16, -r * 0.05), r * 0.05, Color("4A4038"))
	draw_circle(at + Vector2(0, r * 0.14), r * 0.07, Color("C0605A"))

func _draw_fairy(at: Vector2, r: float) -> void:
	var body := Color("A7C4A0")
	var wing := Color(0.9, 0.96, 0.9, 0.8)
	draw_circle(at + Vector2(-r * 0.4, -r * 0.15), r * 0.26, wing)
	draw_circle(at + Vector2(r * 0.4, -r * 0.15), r * 0.26, wing)
	draw_circle(at, r * 0.34, body)
	_draw_sparkle(at + Vector2(0, -r * 0.6), r * 0.16)

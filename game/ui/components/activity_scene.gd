class_name ActivityScene
extends Control
## 활동별 장면 애니메이션. 외부 아트 없이 태그별 배경 소품 + 캐릭터 모션 + 전경 파티클을
## 프로시저로 연출한다. 3레이어: self(_draw 배경) < avatar(캐릭터) < _fx(전경 파티클).

var tag := "home"
var activity_name := ""
var axis := "leisure"
var stage := "elementary"
var reduced := false

var avatar: ChildAvatar
var _fx: Control
var t := 0.0

const TINT := {
	"academy": Color("E9E4F0"), "home": Color("FBF1E0"), "public": Color("E4F0E7"),
	"online": Color("EAF0F6"), "self": Color("F3ECDD"), "tutor": Color("F4ECDE"),
	"nature": Color("E4F1DA"), "family": Color("FCE9E3"), "rest": Color("ECE8F3"),
	"art": Color("F3E7F2"), "sport": Color("E2EDF5"), "work": Color("F0ECDC"),
}
const EXPR := {
	"academy": "focused", "home": "focused", "public": "focused", "online": "focused",
	"self": "focused", "tutor": "focused", "nature": "excited", "family": "happy",
	"rest": "happy", "art": "proud", "sport": "excited", "work": "tired",
}

func _ready() -> void:
	clip_contents = true
	avatar = ChildAvatar.new()
	avatar.reduce_motion = reduced
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avatar)
	var fx := FxLayer.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.scene = self
	_fx = fx
	add_child(_fx)

var _has_bg_art := false

func play(activity: Dictionary, child_stage: String, hair: String, outfit: Color) -> void:
	tag = str(activity.get("tag", "home"))
	activity_name = str(activity.get("name", ""))
	axis = str(activity.get("axis", "leisure"))
	stage = child_stage
	t = 0.0
	_has_bg_art = Art.tex("bg_act_" + tag) != null
	if avatar != null:
		avatar.reduce_motion = reduced
		avatar.set_appearance(hair, outfit)
		avatar.set_look(stage, EXPR.get(tag, "happy"))
	queue_redraw()

func _process(delta: float) -> void:
	if avatar != null:
		# 생성 배경 위에서는 캐릭터를 바닥선에 세운다(공중 부양 방지).
		avatar.size = size
		avatar.align_bottom = _has_bg_art
		avatar.draw_scale = 0.78 if _has_bg_art else 1.0
		if reduced:
			avatar.position = Vector2.ZERO
		else:
			t += delta
			avatar.position = _character_motion()
	if _fx != null:
		_fx.size = size
		_fx.queue_redraw()
	if not reduced:
		queue_redraw()

func _character_motion() -> Vector2:
	var s := minf(size.x, size.y)
	match tag:
		"nature", "sport", "family", "art":
			return Vector2(0, -absf(sin(t * 3.2)) * s * 0.06)
		"academy", "work":
			return Vector2(sin(t * 22.0) * s * 0.006, sin(t * 1.2) * s * 0.01 + s * 0.01)
		"rest":
			return Vector2(0, sin(t * 1.4) * s * 0.012)
		_:
			return Vector2(0, sin(t * 2.0) * s * 0.02)

# ---------------------------------------------------------------- 배경(_draw)
func _draw() -> void:
	var w := size.x
	var h := size.y
	# 생성 배경 아트(bg_act_<tag>)가 있으면 cover-fit 으로 깔고 프로시저 소품은 생략.
	# 캐릭터 모션·전경 파티클(FxLayer)은 별도 노드라 그대로 살아 있다.
	var tex := Art.tex("bg_act_" + tag)
	if tex != null:
		var ts := tex.get_size()
		var sc := maxf(w / ts.x, h / ts.y)
		var dw := ts.x * sc
		var dh := ts.y * sc
		draw_texture_rect(tex, Rect2((w - dw) * 0.5, (h - dh) * 0.5, dw, dh), false)
		return
	# 태그 틴트 라운드 배경
	var tint: Color = TINT.get(tag, UIKit.CREAM)
	draw_rect(Rect2(0, 0, w, h), tint, true)
	match tag:
		"academy": _bg_academy(w, h)
		"home", "self", "online": _bg_desk(w, h)
		"public": _bg_board(w, h)
		"tutor": _bg_tutor(w, h)
		"nature": _bg_nature(w, h)
		"family": _bg_family(w, h)
		"rest": _bg_rest(w, h)
		"art": _bg_art(w, h)
		"sport": _bg_sport(w, h)
		"work": _bg_work(w, h)

func _bg_academy(w: float, h: float) -> void:
	draw_rect(Rect2(0, h * 0.84, w, h * 0.16), Color("C9A886"), true)  # 책상
	# 벽시계 — 초침 회전
	var c := Vector2(w * 0.82, h * 0.28)
	var r := w * 0.10
	draw_circle(c, r, Color.WHITE)
	draw_arc(c, r, 0, TAU, 32, Color("8C7A6B"), 3.0)
	var ang := -PI * 0.5 + t * 2.2
	draw_line(c, c + Vector2(cos(ang), sin(ang)) * r * 0.8, Color("4A4038"), 3.0)
	draw_line(c, c + Vector2(cos(t * 0.6), sin(t * 0.6)) * r * 0.5, Color("8C7A6B"), 4.0)
	# 책 스택
	draw_rect(Rect2(w * 0.12, h * 0.72, w * 0.20, h * 0.05), Color("E5735E"), true)
	draw_rect(Rect2(w * 0.14, h * 0.67, w * 0.18, h * 0.05), Color("7FA9D9"), true)

func _bg_desk(w: float, h: float) -> void:
	draw_rect(Rect2(0, h * 0.84, w, h * 0.16), Color("D8B98C"), true)
	# 램프 글로우
	var lc := Vector2(w * 0.82, h * 0.24)
	for i in 4:
		var rr := w * (0.05 + i * 0.035)
		var col := Color("F6D98A", 0.16 - i * 0.03)
		draw_circle(lc, rr, col)
	# 펼친 책
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.30, h * 0.80), Vector2(w * 0.50, h * 0.76),
		Vector2(w * 0.50, h * 0.86), Vector2(w * 0.30, h * 0.88)]), Color("FFF6E6"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.50, h * 0.76), Vector2(w * 0.70, h * 0.80),
		Vector2(w * 0.70, h * 0.88), Vector2(w * 0.50, h * 0.86)]), Color("FBEFD8"))

func _bg_board(w: float, h: float) -> void:
	draw_rect(Rect2(w * 0.1, h * 0.08, w * 0.8, h * 0.34), Color("3E6B52"), true)
	for i in 3:
		var y := h * (0.16 + i * 0.08)
		draw_line(Vector2(w * 0.16, y), Vector2(w * (0.4 + i * 0.12), y), Color("EFEAD8", 0.8), 3.0)

func _bg_tutor(w: float, h: float) -> void:
	draw_rect(Rect2(0, h * 0.84, w, h * 0.16), Color("D8B98C"), true)
	# 옆에 앉은 선생 실루엣
	var hx := w * 0.2
	draw_circle(Vector2(hx, h * 0.5), w * 0.09, Color("B7A599"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx - w * 0.11, h * 0.9), Vector2(hx + w * 0.11, h * 0.9),
		Vector2(hx + w * 0.08, h * 0.6), Vector2(hx - w * 0.08, h * 0.6)]), Color("B7A599"))

func _bg_nature(w: float, h: float) -> void:
	# 해 + 회전 광선
	var sc := Vector2(w * 0.2, h * 0.2)
	draw_circle(sc, w * 0.09, Color("F6C85A"))
	for i in 8:
		var a := t * 0.6 + i * TAU / 8.0
		draw_line(sc + Vector2(cos(a), sin(a)) * w * 0.11,
			sc + Vector2(cos(a), sin(a)) * w * 0.15, Color("F6C85A"), 3.0)
	# 잔디 + 나무
	draw_rect(Rect2(0, h * 0.82, w, h * 0.18), Color("A7C98F"), true)
	_tree(w * 0.12, h * 0.82, w * 0.08)
	_tree(w * 0.88, h * 0.82, w * 0.09)

func _tree(x: float, ground: float, r: float) -> void:
	draw_rect(Rect2(x - r * 0.15, ground - r * 1.2, r * 0.3, r * 1.2), Color("A67C52"))
	draw_circle(Vector2(x, ground - r * 1.4), r, Color("7FA96A"))

func _bg_family(w: float, h: float) -> void:
	draw_rect(Rect2(0, h * 0.84, w, h * 0.16), Color("EAD6C4"), true)
	# 양옆 부모 실루엣(어깨)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.05, h), Vector2(w * 0.28, h),
		Vector2(w * 0.22, h * 0.62), Vector2(w * 0.02, h * 0.62)]), Color("D8A48F", 0.5))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 1.05, h), Vector2(w * 0.72, h),
		Vector2(w * 0.78, h * 0.62), Vector2(w * 0.98, h * 0.62)]), Color("9CB6C9", 0.5))

func _bg_rest(w: float, h: float) -> void:
	# 달
	draw_circle(Vector2(w * 0.82, h * 0.2), w * 0.08, Color("F3EEDA"))
	draw_circle(Vector2(w * 0.86, h * 0.18), w * 0.07, TINT["rest"])
	# 이불
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, h), Vector2(0, h * 0.8), Vector2(w, h * 0.86), Vector2(w, h)]), Color("C9BEE0"))

func _bg_art(w: float, h: float) -> void:
	draw_rect(Rect2(0, h * 0.86, w, h * 0.14), Color("D8B98C"), true)
	# 이젤 + 캔버스
	var ex := w * 0.2
	draw_line(Vector2(ex, h * 0.4), Vector2(ex - w * 0.06, h * 0.86), Color("A67C52"), 4.0)
	draw_line(Vector2(ex, h * 0.4), Vector2(ex + w * 0.06, h * 0.86), Color("A67C52"), 4.0)
	draw_rect(Rect2(ex - w * 0.09, h * 0.34, w * 0.18, h * 0.2), Color("FFFBF0"), true)
	draw_circle(Vector2(ex - w * 0.02, h * 0.4), w * 0.03, Color("E5735E"))
	draw_circle(Vector2(ex + w * 0.03, h * 0.46), w * 0.025, Color("7FA9D9"))

func _bg_sport(w: float, h: float) -> void:
	draw_rect(Rect2(0, h * 0.82, w, h * 0.18), Color("9CC08C"), true)
	# 튀는 공
	var by := h * (0.6 - absf(sin(t * 3.0)) * 0.25)
	draw_circle(Vector2(w * 0.78, by), w * 0.06, Color("E5735E"))
	draw_arc(Vector2(w * 0.78, by), w * 0.06, 0, TAU, 20, Color("FFFFFF", 0.7), 2.0)

func _bg_work(w: float, h: float) -> void:
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("C99B72"), true)  # 카운터
	draw_rect(Rect2(w * 0.1, h * 0.6, w * 0.22, h * 0.1), Color("EFE7D2"), true)  # 표지판

# ---------------------------------------------------------------- 전경 파티클
func draw_fx(fx: Control) -> void:
	var w := size.x
	var h := size.y
	match tag:
		"academy", "work": _fx_sweat(fx, w, h)
		"home", "self", "online", "public": _fx_letters(fx, w, h)
		"tutor": _fx_bubble(fx, w, h)
		"nature": _fx_butterfly(fx, w, h)
		"family": _fx_hearts(fx, w, h)
		"rest": _fx_sleep(fx, w, h)
		"art": _fx_sparkle(fx, w, h)
		"sport": _fx_speed(fx, w, h)

func _phase(i: int, speed: float) -> float:
	return fposmod(t * speed + float(i) * 0.37, 1.0)

func _fx_sweat(fx: Control, w: float, h: float) -> void:
	for i in 2:
		var p := _phase(i, 0.9)
		var x := w * (0.62 + i * 0.06)
		var y := h * (0.34 + p * 0.2)
		fx.draw_circle(Vector2(x, y), w * 0.018 * (1.0 - p), Color("7FA9D9", 1.0 - p))

func _fx_letters(fx: Control, w: float, h: float) -> void:
	var glyphs := ["가", "나", "1", "＋", "ㄱ"]
	var f := _font()
	for i in 4:
		var p := _phase(i, 0.4)
		var x := w * (0.28 + i * 0.13)
		var y := h * (0.7 - p * 0.5)
		fx.draw_string(f, Vector2(x, y), glyphs[i % glyphs.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.sz(20), Color("7FA9D9", 1.0 - p))

func _fx_bubble(fx: Control, w: float, h: float) -> void:
	var pulse := 0.85 + 0.15 * sin(t * 4.0)
	var c := Vector2(w * 0.7, h * 0.3)
	fx.draw_circle(c, w * 0.07 * pulse, Color("FFFFFF", 0.9))
	fx.draw_string(_font(), c + Vector2(-w * 0.02, w * 0.025), "?",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.sz(22), Color("4A4038"))

func _fx_butterfly(fx: Control, w: float, h: float) -> void:
	var x := w * (0.5 + 0.32 * sin(t * 1.3))
	var y := h * (0.35 + 0.14 * sin(t * 2.1))
	var flap := absf(sin(t * 10.0)) * w * 0.02 + w * 0.012
	fx.draw_circle(Vector2(x - flap, y), w * 0.02, Color("E890A2"))
	fx.draw_circle(Vector2(x + flap, y), w * 0.02, Color("C39BD3"))

func _fx_hearts(fx: Control, w: float, h: float) -> void:
	for i in 3:
		var p := _phase(i, 0.5)
		var x := w * (0.35 + i * 0.15 + sin(t * 2.0 + i) * 0.03)
		var y := h * (0.62 - p * 0.5)
		_heart(fx, Vector2(x, y), w * 0.03 * (1.0 - p * 0.4), Color("E890A2", 1.0 - p))

func _heart(fx: Control, c: Vector2, r: float, col: Color) -> void:
	fx.draw_circle(c + Vector2(-r * 0.5, -r * 0.3), r * 0.6, col)
	fx.draw_circle(c + Vector2(r * 0.5, -r * 0.3), r * 0.6, col)
	fx.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r, -r * 0.1), c + Vector2(r, -r * 0.1), c + Vector2(0, r)]), col)

func _fx_sleep(fx: Control, w: float, h: float) -> void:
	var f := _font()
	for i in 3:
		var p := _phase(i, 0.35)
		var x := w * (0.6 + p * 0.12)
		var y := h * (0.4 - p * 0.22)
		fx.draw_string(f, Vector2(x, y), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1,
			UIKit.sz(16 + int(p * 14)), Color("9C8FC0", 1.0 - p))

func _fx_sparkle(fx: Control, w: float, h: float) -> void:
	for i in 4:
		var p := _phase(i, 1.2)
		var a := float(i) * 1.7
		var x := w * (0.3 + 0.4 * fposmod(a, 1.0))
		var y := h * (0.3 + 0.35 * fposmod(a * 1.3, 1.0))
		var s := w * 0.02 * sin(p * PI)
		var col := Color("E8B54D", sin(p * PI))
		fx.draw_line(Vector2(x - s, y), Vector2(x + s, y), col, 2.0)
		fx.draw_line(Vector2(x, y - s), Vector2(x, y + s), col, 2.0)

func _fx_speed(fx: Control, w: float, h: float) -> void:
	for i in 3:
		var p := _phase(i, 1.6)
		var y := h * (0.45 + i * 0.1)
		var x := w * (0.7 - p * 0.4)
		fx.draw_line(Vector2(x, y), Vector2(x + w * 0.12, y), Color("7FA9D9", 0.6 * (1.0 - p)), 3.0)

func _font() -> Font:
	return UIKit.body_font if UIKit.body_font != null else ThemeDB.fallback_font


## 전경 파티클 레이어(캐릭터 위에 그린다).
class FxLayer:
	extends Control
	var scene: ActivityScene
	func _draw() -> void:
		if scene != null and is_instance_valid(scene):
			scene.draw_fx(self)

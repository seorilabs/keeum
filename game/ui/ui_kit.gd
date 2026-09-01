class_name UIKit
extends RefCounted
## UI 공통 토큰·위젯 빌더. 03-ui-ux-spec 컬러 토큰과 터치 48dp 규칙을 코드로 고정한다.
## 늘어나는 UI(텍스트·게이지·버튼)는 Godot 렌더(04 문서), 캐릭터는 ChildAvatar 프로시저 드로잉.

# 컬러 토큰 (다크 금지, 웜다크브라운 텍스트)
const CREAM := Color("FBF3E7")
const CREAM_DEEP := Color("F3E7D3")
const CORAL := Color("E5735E")     # 정서 (가독성 위해 진하게)
const SAGE := Color("7FA97A")      # 체력
const BLUE := Color("5E8CC7")      # 성적
const AMBER := Color("D69A2E")     # 스트레스
const PINK := Color("E890A2")      # 유대감
const TEXT := Color("3A322B")      # 본문 (더 진한 웜다크브라운)
const TEXT_SOFT := Color(0.32, 0.27, 0.23, 0.92)  # 보조 텍스트도 충분한 대비
const CARD := Color("FFFBF4")
const TALENT := Color("A876C4")    # 특기(보라)
const MONEY := Color("5F9A58")
const PREMIUM := Color("3FA6B8")

const TOUCH_MIN := 60

# 번들 폰트 (main._apply_theme 에서 주입). 본문=Gothic A1 ExtraBold, 제목=Black Han Sans.
static var body_font: Font = null
static var title_font: Font = null
const FONT_SCALE := 1.18

static func sz(size: int) -> int:
	return int(round(float(size) * FONT_SCALE))

## 기기 safe area(노치·제스처바)를 캔버스 좌표(폭 1080 기준)로 환산. 데스크톱·웹은 0.
static func safe_insets() -> Dictionary:
	var w := DisplayServer.window_get_size()
	if w.x <= 0:
		return {"top": 0.0, "bottom": 0.0}
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var top_px := maxi(0, safe.position.y)
	var bottom_px := maxi(0, screen.y - safe.position.y - safe.size.y)
	var scale := 1080.0 / float(w.x)
	return {"top": float(top_px) * scale, "bottom": float(bottom_px) * scale}

static func stat_color(key: String) -> Color:
	match key:
		"academic", "korean", "english", "math", "science", "social": return BLUE
		"emotion": return CORAL
		"stamina": return SAGE
		"stress": return AMBER
		"bonding": return PINK
		"talent": return TALENT
		"money": return MONEY
		"premium": return PREMIUM
	return TEXT

# ---------------------------------------------------------------- 위젯
## wrap=false 가 기본. HBox 행 라벨은 wrap 을 끄지 않으면 확장 spacer 때문에 세로로 접힌다.
## 여러 문장 문단만 wrap=true 로 준다.
static func label(text: String, size: int = 30, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if body_font != null:
		l.add_theme_font_override("font", body_font)
	l.add_theme_font_size_override("font_size", sz(size))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func title(text: String, size: int = 46) -> Label:
	var l := label(text, size, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	if title_font != null:
		l.add_theme_font_override("font", title_font)
	return l

# ---------------------------------------------------------------- 벡터 아이콘
## 이모지 대체(웹 폰트 폴백 부재 대응). GameIcon 벡터 노드를 반환.
static func icon(kind: String, px: int = 28, color: Variant = null) -> GameIcon:
	return GameIcon.make(kind, float(px), color)

## 아이콘 + 라벨 한 줄(HBox). 화폐·상태 표시용.
static func icon_text(kind: String, text: String, size: int = 24, color: Color = TEXT,
		icon_color: Variant = null) -> HBoxContainer:
	var h := hbox(6)
	h.add_child(icon(kind, sz(size) + 2, icon_color))
	h.add_child(label(text, size, color))
	return h

## 선두 아이콘 + 텍스트 버튼. 버튼 위에 오버레이(HBox)를 얹어 텍스트에 이모지를 쓰지 않는다.
## 아이콘 노드는 b.get_meta("icon_node") 로 접근해 상태 전환 시 set_kind 가능.
static func icon_button(kind: String, text: String, primary: bool = false,
		size: int = -1, icon_color: Variant = null) -> Button:
	var b := button("", primary)
	var lbl_size := size if size > 0 else (31 if primary else 29)
	var fg := Color.WHITE if primary else TEXT
	var box := hbox(8)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon(kind, sz(lbl_size) + 4, icon_color)
	box.add_child(ic)
	if text != "":
		var lbl := label(text, lbl_size, fg)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if primary and title_font != null:
			lbl.add_theme_font_override("font", title_font)
		box.add_child(lbl)
	b.add_child(box)
	b.set_meta("icon_node", ic)
	return b

static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN)
	if primary and title_font != null:
		b.add_theme_font_override("font", title_font)
	elif body_font != null:
		b.add_theme_font_override("font", body_font)
	b.add_theme_font_size_override("font_size", sz(31 if primary else 29))
	var bg := CORAL if primary else CARD
	var fg := Color.WHITE if primary else TEXT
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_color_hover", fg)
	b.add_theme_color_override("font_color_pressed", fg)
	b.add_theme_color_override("font_color_focus", fg)
	b.add_theme_stylebox_override("normal", _btn_style(bg))
	b.add_theme_stylebox_override("hover", _btn_style(bg.lightened(0.05)))
	b.add_theme_stylebox_override("pressed", _btn_style(bg.darkened(0.08)))
	b.add_theme_stylebox_override("focus", _btn_style(bg))
	b.add_theme_stylebox_override("disabled", _btn_style(CREAM_DEEP))
	FX.press(b)  # 프레스 스케일 + 라이트 햅틱 일괄 주입(03 문서 피드백 1단)
	return b

## 카드 스타일 입력창. 포커스 시 코랄 보더(온보딩 이름 입력 등).
static func line_edit(placeholder: String = "", size: int = 28) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, TOUCH_MIN)
	if body_font != null:
		e.add_theme_font_override("font", body_font)
	e.add_theme_font_size_override("font_size", sz(size))
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(TEXT_SOFT, 0.55))
	e.add_theme_color_override("caret_color", CORAL)
	var normal := card_style(CARD, 16)
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = CORAL
	focus.set_border_width_all(3)
	e.add_theme_stylebox_override("normal", normal)
	e.add_theme_stylebox_override("focus", focus)
	return e

static func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 18
	s.corner_radius_top_right = 18
	s.corner_radius_bottom_left = 18
	s.corner_radius_bottom_right = 18
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0.29, 0.25, 0.22, 0.10)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	return s

## 게임 톤 슬라이더(코랄 채움 + 크림 트랙 + 흰 그래버).
static func slider(value: float, step: float = 0.05) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, TOUCH_MIN)
	var track := StyleBoxFlat.new()
	track.bg_color = CREAM_DEEP
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = CORAL
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _grabber_texture())
	s.add_theme_icon_override("grabber_highlight", _grabber_texture())
	return s

static var _grabber: ImageTexture = null

static func _grabber_texture() -> ImageTexture:
	if _grabber != null:
		return _grabber
	var px := 40
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(px) * 0.5
	for y in px:
		for x in px:
			var d := Vector2(float(x) - c + 0.5, float(y) - c + 0.5).length()
			if d <= c - 1.0:
				img.set_pixel(x, y, Color.WHITE)
			elif d <= c:
				img.set_pixel(x, y, Color(1, 1, 1, c - d))
	_grabber = ImageTexture.create_from_image(img)
	return _grabber

static func panel(bg: Color = CARD, radius: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(bg, radius))
	return p

static func card_style(bg: Color = CARD, radius: int = 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	s.shadow_color = Color(0.29, 0.25, 0.22, 0.08)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

static func vbox(sep: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h: int = 0) -> Control:
	var c := Control.new()
	if h > 0:
		c.custom_minimum_size = Vector2(0, h)
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func margin(all: int = 24) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all)
	m.add_theme_constant_override("margin_bottom", all)
	return m

class_name OnboardingScreen
extends UIScreen
## SCR-001 온보딩·아이 만들기. 세계관 진입 + 애착 형성.
## 성별·이름·첫인상 선택 → 새 회차 시작. 텍스트 벽 금지, 한 비트에 한 개념.

var _gender := "neutral"
var _impression_id := "bright"
var _name_edit: LineEdit
var _gender_btns: Dictionary = {}
var _impression_btns: Dictionary = {}
var _avatar: ChildAvatar

const GENDER_LABEL := {"son": "아들", "daughter": "딸", "neutral": "중성"}
const HAIR_DEFAULT := {"son": "short_black", "daughter": "twin_tail", "neutral": "mushroom"}

func enter(_data: Variant = null) -> void:
	var root := page_root(60)

	# 타이틀 비트(스토리보드 0:00-0:15): 문장 → 타이틀 → 아이 순차 등장. 입력은 즉시 허용.
	var pre := UIKit.label("오늘부터,", 32, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(pre)
	var title := UIKit.title("당신은 이 아이의 부모입니다", 40)
	root.add_child(title)

	_avatar = ChildAvatar.new()
	_avatar.custom_minimum_size = Vector2(0, 220)
	_avatar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_avatar.size_flags_stretch_ratio = 0.45  # 긴 화면(20:9)에서 아이가 더 크게 등장
	_avatar.reduce_motion = reduce_motion()
	_avatar.set_look("infant", "happy")
	root.add_child(_avatar)
	FX.pop_in(pre, 0.0)
	FX.pop_in(title, 0.3)
	FX.pop_in(_avatar, 0.6)

	var body := scroll_body(root)

	# 성별(외형·인칭 전용)
	body.add_child(UIKit.label("어떤 아이인가요?", 28, UIKit.TEXT))
	var grow := UIKit.hbox(10)
	for g: String in ["son", "daughter", "neutral"]:
		var b := UIKit.button(GENDER_LABEL[g])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_gender.bind(g))
		grow.add_child(b)
		_gender_btns[g] = b
	body.add_child(grow)

	# 이름
	body.add_child(UIKit.label("이름을 지어주세요", 28, UIKit.TEXT))
	var nrow := UIKit.hbox(10)
	_name_edit = UIKit.line_edit("", 30)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nrow.add_child(_name_edit)
	var dice := UIKit.icon_button("dice", "")
	dice.custom_minimum_size = Vector2(UIKit.TOUCH_MIN, UIKit.TOUCH_MIN)
	dice.size_flags_horizontal = Control.SIZE_SHRINK_END
	dice.pressed.connect(_random_name)
	nrow.add_child(dice)
	body.add_child(nrow)

	# 첫인상
	body.add_child(UIKit.label("첫인상은 어때요?", 28, UIKit.TEXT))
	var impressions: Array = GameController.content.profiles.get("first_impressions", [])
	for imp: Dictionary in impressions:
		var card := _impression_card(imp)
		body.add_child(card)
		_impression_btns[str(imp.get("id", ""))] = card

	body.add_child(UIKit.spacer(8))

	var start := UIKit.button("이 아이와 시작하기", true)
	start.pressed.connect(_start)
	root.add_child(start)

	_random_name()
	_refresh()

func _impression_card(imp: Dictionary) -> Button:
	var b := UIKit.button("%s — %s" % [imp.get("label", ""), imp.get("desc", "")])
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_on_impression.bind(str(imp.get("id", ""))))
	return b

func _on_gender(g: String) -> void:
	_gender = g
	AudioBus.tap()
	_avatar.set_appearance(HAIR_DEFAULT.get(g, "mushroom"), UIKit.CORAL)
	_bounce_avatar()
	_refresh()

func _bounce_avatar() -> void:
	if reduce_motion() or not _avatar.is_inside_tree():
		return
	_avatar.pivot_offset = _avatar.size * 0.5
	var tw := _avatar.create_tween()
	tw.tween_property(_avatar, "scale", Vector2(1.06, 1.06), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_avatar, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_impression(id: String) -> void:
	_impression_id = id
	AudioBus.tap()
	_avatar.set_look("infant", "excited")
	_refresh()

func _random_name() -> void:
	var pool: Array = GameController.content.profiles.get("names", {}).get(_gender, ["아이"])
	if pool.is_empty():
		pool = ["아이"]
	_name_edit.text = str(pool[randi() % pool.size()])

func _refresh() -> void:
	for g: String in _gender_btns:
		_style_selected(_gender_btns[g], g == _gender)
	for id: String in _impression_btns:
		_style_selected(_impression_btns[id], id == _impression_id)

func _style_selected(b: Button, selected: bool) -> void:
	var bg := UIKit.CORAL if selected else UIKit.CARD
	var fg := Color.WHITE if selected else UIKit.TEXT
	b.add_theme_stylebox_override("normal", UIKit._btn_style(bg))
	b.add_theme_stylebox_override("hover", UIKit._btn_style(bg.lightened(0.05)))
	b.add_theme_color_override("font_color", fg)

func _start() -> void:
	var impressions: Array = GameController.content.profiles.get("first_impressions", [])
	var imp := {}
	for i: Dictionary in impressions:
		if str(i.get("id", "")) == _impression_id:
			imp = i
	var nm := _name_edit.text.strip_edges()
	if nm == "":
		nm = "아이"
	var config := {
		"name": nm,
		"gender": _gender,
		"impression": imp,
		"appearance": {"hair": HAIR_DEFAULT.get(_gender, "mushroom"), "outfit": "F28C79"},
	}
	AudioBus.bonding()
	GameController.new_game(config)
	router.goto("home")

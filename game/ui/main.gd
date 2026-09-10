extends Control
## 화면 라우터. 배경·스크린 호스트·토스트·안드로이드 백버튼을 담당하고,
## core 인터루드 큐(next_step)에 따라 화면을 전환한다.
## 조립 계층(Godot)만 여기 존재하고 규칙은 GameController→core 로 위임.
## 테스트 드라이버(--ui-smoke/--ui-play)는 tools/ui_harness.gd 로 분리.

var _host: Control
var _toast_label: Label
var _save_failed_banner: Control
var _current: UIScreen
var _current_name := ""
var _bg: TextureRect
var _quit_layer: Control
var _harness: UIHarness

const SCREENS := {
	"onboarding": "res://game/ui/screens/onboarding_screen.gd",
	"home": "res://game/ui/screens/home_screen.gd",
	"activity": "res://game/ui/screens/activity_screen.gd",
	"result": "res://game/ui/screens/result_screen.gd",
	"term": "res://game/ui/screens/term_screen.gd",
	"event": "res://game/ui/screens/event_screen.gd",
	"transition": "res://game/ui/screens/transition_screen.gd",
	"application": "res://game/ui/screens/application_screen.gd",
	"ending": "res://game/ui/screens/ending_screen.gd",
	"codex": "res://game/ui/screens/codex_screen.gd",
	"shop": "res://game/ui/screens/shop_screen.gd",
	"gacha": "res://game/ui/screens/gacha_screen.gd",
	"mileage_exchange": "res://game/ui/screens/mileage_exchange_screen.gd",
	"settings": "res://game/ui/screens/settings_screen.gd",
}

## 화면 → BGM 트랙(assets/audio/bgm_<key>.ogg). 감정 비트만 전조·회고로 분기(04 문서).
const BGM_MAP := {"transition": "transition", "application": "transition", "ending": "ending"}

func _ready() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		FX.force_reduced = true  # 헤드리스 하네스: 연출 즉시 경로(결정성 보장)
	_apply_theme()
	_build_background()
	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	_build_toast()
	_build_save_failed_banner()
	GameController.save_result.connect(_on_save_result)
	_show_load_status_notice()
	# 안드로이드 백버튼: 노티피케이션이 자식 노드까지 전파되지 않는 경우가 있어
	# Window 시그널도 함께 연결한다(중복 호출은 _on_back 에서 프레임 가드로 무시).
	var win := get_window()
	if win != null and not win.go_back_requested.is_connected(_on_back):
		win.go_back_requested.connect(_on_back)
	if "--ui-smoke" in OS.get_cmdline_args() or "--ui-smoke" in OS.get_cmdline_user_args():
		_harness = UIHarness.new(self)
		_harness.call_deferred("run_smoke")
		return
	if "--ui-play" in OS.get_cmdline_user_args():
		_harness = UIHarness.new(self)
		_harness.call_deferred("run_play")
		return
	_route_initial()

func _exit_tree() -> void:
	# 정적 텍스처 캐시 해제("resources still in use at exit" 방지).
	Art._cache.clear()
	Art._anchors.clear()

func _route_initial() -> void:
	var gc := GameController
	if gc.run != null:
		if not gc.run.current_step.is_empty():
			# 화면에 떠 있었지만 선택이 아직 해결되지 않은 인터루드(#16) — 새로
			# 뽑지 않고 저장된 항목 그대로 재개한다.
			_show_step(gc.run.current_step)
		elif gc.run.has_steps():
			advance_step()  # 다음 미해결 인터루드(이벤트/전환기/입시)로 진행
		elif gc.run.is_final_turn():
			goto("application")
		else:
			goto("home")
	else:
		goto("onboarding")

# ---------------------------------------------------------------- 내비게이션
func current_screen() -> UIScreen:
	return _current

func goto(screen_name: String, data: Variant = null) -> void:
	if not SCREENS.has(screen_name):
		push_error("main: 알 수 없는 화면 " + screen_name)
		return
	var old := _current
	if old != null and is_instance_valid(old):
		if FX.reduced():
			old.queue_free()
		else:
			# 퇴장: 입력 차단 후 짧은 페이드 + 아래로 미세 하강(04 문서 "짧은 페이드")
			old.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var otw := old.create_tween()
			otw.set_parallel(true)
			otw.tween_property(old, "modulate:a", 0.0, 0.12)
			otw.tween_property(old, "position:y", old.position.y + 10.0, 0.12)
			otw.chain().tween_callback(old.queue_free)
	var scr: UIScreen = load(SCREENS[screen_name]).new()
	_host.add_child(scr)
	scr.setup(self)
	scr.enter(data)
	_current = scr
	_current_name = screen_name
	AudioBus.play_bgm(str(BGM_MAP.get(screen_name, "home")))
	if not FX.reduced():
		scr.modulate.a = 0.0
		scr.position.y = 12.0
		var tw := scr.create_tween()
		tw.set_parallel(true)
		tw.tween_property(scr, "modulate:a", 1.0, 0.18)
		tw.tween_property(scr, "position:y", 0.0, 0.22) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## core 인터루드 큐를 따라 다음 화면으로.
func advance_step() -> void:
	_show_step(GameController.run.next_step())

## step 딕셔너리({"screen":...})에 맞는 화면으로 이동. 큐에서 새로 꺼내지 않고
## 저장된 current_step 을 그대로 재개할 때도 쓴다(#16).
func _show_step(step: Dictionary) -> void:
	match str(step.get("screen", "home")):
		"home":
			GameController.save_game()
			goto("home")
		"event":
			goto("event", step["event"])
		"term":
			goto("term")
		"transition":
			goto("transition", step["transition"])
		"application":
			goto("application")
		_:
			goto("home")

# ---------------------------------------------------------------- 안드로이드 백버튼
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()

var _back_frame := -1

func _on_back() -> void:
	# 노티피케이션과 시그널이 함께 오는 경우 한 프레임에 한 번만 처리.
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame
	if _quit_layer != null and _quit_layer.visible:
		_quit_layer.visible = false
		return
	var has_run := GameController.run != null
	match _current_name:
		"codex", "shop", "settings":
			AudioBus.tap()
			goto("home" if has_run else "onboarding")
		"gacha":
			AudioBus.tap()
			goto("shop")
		"mileage_exchange":
			AudioBus.tap()
			goto("gacha")
		"activity":
			AudioBus.tap()
			goto("home")
		"home", "onboarding":
			_show_quit_confirm()
		_:
			pass  # 진행·감정 비트 화면(result/term/event/transition/application/ending)은 무시

func _show_quit_confirm() -> void:
	if _quit_layer == null:
		_quit_layer = _build_quit_confirm()
		add_child(_quit_layer)
	_quit_layer.visible = true

func _build_quit_confirm() -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 90
	var dim := ColorRect.new()
	dim.color = Color(0.23, 0.19, 0.16, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	# CenterContainer 로 감싸야 패널이 실제 중앙에 놓인다(PRESET_CENTER 는 최소 크기를 모른다).
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := UIKit.panel(UIKit.CARD, 24)
	panel.custom_minimum_size = Vector2(620, 0)
	var v := UIKit.vbox(16)
	panel.add_child(v)
	v.add_child(UIKit.label("게임을 끝낼까요?", 30, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("진행 상황은 자동 저장돼 있어요.", 23, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var stay := UIKit.button("계속하기", true)
	stay.pressed.connect(func() -> void:
		AudioBus.tap()
		_quit_layer.visible = false)
	v.add_child(stay)
	var quit := UIKit.button("종료")
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)
	center.add_child(panel)
	return layer

# ---------------------------------------------------------------- 토스트
func toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 0.0
	_toast_label.visible = true
	var tw := _toast_label.create_tween()
	tw.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.5)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _toast_label.visible = false)

func _build_toast() -> void:
	var panel := UIKit.panel(UIKit.TEXT, 16)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position.y -= 140.0 + float(UIKit.safe_insets()["bottom"])
	panel.z_index = 100
	panel.visible = false
	var l := UIKit.label("", 26, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(l)
	add_child(panel)
	_toast_label = l
	# 토스트 표시 시 패널도 함께 보이도록 라벨 가시성에 연동.
	l.visibility_changed.connect(func() -> void: panel.visible = l.visible)

# ------------------------------------------------------------ 저장 실패 배너(#22)
## 저장이 조용히 지나가지 않도록 화면 어디에 있든 뜨는 배너. 토스트와 달리
## 자동으로 사라지지 않고, save_result(true) 가 올 때까지(재시도 성공) 남는다.
func _on_save_result(success: bool) -> void:
	_save_failed_banner.visible = not success

func _build_save_failed_banner() -> void:
	var panel := UIKit.panel(UIKit.CARD, 18)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position.y += 20.0 + float(UIKit.safe_insets()["top"])
	panel.z_index = 100
	panel.visible = false
	var h := UIKit.hbox(16)
	panel.add_child(h)
	h.add_child(UIKit.label("저장에 실패했어요. 진행 상황은 남아 있으니 다시 시도해 주세요.", 22, UIKit.TEXT))
	var retry := UIKit.button("다시 저장", true)
	retry.pressed.connect(func() -> void:
		AudioBus.tap()
		GameController.save_game())
	h.add_child(retry)
	add_child(panel)
	_save_failed_banner = panel

## 세이브 로드 결과(손상/복구)를 실행당 한 번 안내한다. 정상·첫 실행은 알릴 것이 없다.
func _show_load_status_notice() -> void:
	var text := _load_notice_text(GameController.last_load_status)
	if not text.is_empty():
		toast(text)

func _load_notice_text(status: String) -> String:
	match status:
		LocalSave.STATUS_RECOVERED:
			return "이전 저장이 손상돼 있어 직전 백업으로 복구했어요."
		LocalSave.STATUS_CORRUPT:
			return "저장 파일이 손상돼 새로 시작해요. 손상된 파일은 따로 보관했어요."
		LocalSave.STATUS_FUTURE_VERSION:
			return "더 최신 버전에서 만든 저장이라 이 버전에서는 불러올 수 없어요. 앱을 업데이트해 주세요. 기존 저장은 그대로 남아 있어요."
		_:
			return ""

# ---------------------------------------------------------------- 배경/테마
func _build_background() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_bg)
	_apply_background()
	GameController.profile_changed.connect(_apply_background)

## 테마 코스메틱(가챠 스페셜) 장착 시 배경 교체. Art 텍스처가 있으면 그것을, 없으면
## 가독성을 지키는 라이트 파스텔 그라디언트 폴백(텍스트 웜다크브라운 대비 유지).
func _apply_background() -> void:
	var theme_name := ""
	if GameController.profile != null:
		theme_name = str(GameController.profile.equipped.get("theme", ""))
	var info := Art.cosmetic(theme_name)
	if not info.is_empty():
		var t := Art.tex(str(info.get("asset", "")))
		if t != null:
			_bg.texture = t
			_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			return
	var top := UIKit.CREAM
	var bot := UIKit.CREAM_DEEP
	match theme_name:
		"별빛 밤하늘 테마":
			top = Color("DFE3F5"); bot = Color("BCC5EA")
		"구름 위 다락방 테마":
			top = Color("FBEFE2"); bot = Color("F3D9C0")
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bot)
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.texture = tex

func _apply_theme() -> void:
	# 번들 폰트: 본문 Gothic A1 ExtraBold, 제목 Black Han Sans. 이모지·누락 글자는 시스템 폰트로 폴백.
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"])
	var body: FontFile = load("res://game/ui/fonts/GothicA1-ExtraBold.ttf")
	var title: FontFile = load("res://game/ui/fonts/BlackHanSans-Regular.ttf")
	if body != null:
		body.fallbacks = [emoji]
		UIKit.body_font = body
	if title != null:
		title.fallbacks = [body if body != null else emoji, emoji]
		UIKit.title_font = title
	var t := Theme.new()
	if body != null:
		t.default_font = body
	t.default_font_size = UIKit.sz(30)
	theme = t

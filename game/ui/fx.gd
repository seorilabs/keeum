class_name FX
extends Object
## 공통 모션/주스 유틸(전부 static). 03 문서 피드백 5단 계약의 코드 계층.
## reduce_motion(또는 헤드리스)에서는 트윈을 만들지 않고 최종 상태를 즉시 적용해
## --ui-smoke/--ui-play 의 결정성을 지킨다. 런타임 플래그는 Settings 가 기동 시 주입한다.

static var reduce_motion := false   # Settings 주입(파티클·바운스 축소)
static var haptic_level := 1        # 0=끔 1=보통 2=강 (Settings 주입)
static var force_reduced := false   # 헤드리스 하네스에서 main 이 true 로


static func reduced() -> bool:
	return force_reduced or reduce_motion


## alpha 0→1 + scale 0.94→1 등장. scale 은 레이아웃 불변이라 컨테이너 자식에도 안전.
## 아직 트리 밖이면 진입 시점으로 이연한다(빌더 패턴에서 add_child 전 호출 허용).
static func pop_in(n: Control, delay: float = 0.0) -> void:
	if reduced():
		return
	if not n.is_inside_tree():
		n.tree_entered.connect(func() -> void: pop_in(n, delay), CONNECT_ONE_SHOT)
		return
	_center_pivot(n)
	n.modulate.a = 0.0
	n.scale = Vector2(0.94, 0.94)
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, 0.22)
	tw.tween_property(n, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 자식 일괄 스태거 등장. 총합 0.3s 상한(캡처·페이싱 안정화, 04 문서 스태거 규정).
static func stagger_children(c: Control, step: float = 0.05) -> void:
	if reduced():
		return
	var kids: Array[Control] = []
	for ch: Node in c.get_children():
		if ch is Control and (ch as Control).visible:
			kids.append(ch as Control)
	if kids.is_empty():
		return
	var s := minf(step, 0.3 / float(kids.size()))
	for i in kids.size():
		pop_in(kids[i], s * float(i))


## 숫자 카운트업. fmt 예: "%d", "+%d", "%d점". 트리 밖이면 진입 시점으로 이연.
static func count_up(l: Label, to: int, from: int = 0, dur: float = 0.5, fmt: String = "%d") -> void:
	if reduced():
		l.text = fmt % to
		return
	if not l.is_inside_tree():
		l.text = fmt % from
		l.tree_entered.connect(func() -> void: count_up(l, to, from, dur, fmt), CONNECT_ONE_SHOT)
		return
	var tw := l.create_tween()
	tw.tween_method(func(v: float) -> void: l.text = fmt % int(round(v)),
		float(from), float(to), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 앰버 경고 펄스 1회. 연타 금지(진행 중이면 무시, 04 문서).
static func pulse_amber(n: Control) -> void:
	if reduced() or not n.is_inside_tree() or n.has_meta("fx_pulsing"):
		return
	n.set_meta("fx_pulsing", true)
	var tw := n.create_tween()
	tw.tween_property(n, "modulate", Color(1.0, 0.82, 0.5), 0.18)
	tw.tween_property(n, "modulate", Color.WHITE, 0.5)
	tw.tween_callback(func() -> void: n.remove_meta("fx_pulsing"))


## 버튼 프레스 스케일 + 라이트 햅틱. UIKit.button() 이 일괄 호출.
static func press(b: BaseButton) -> void:
	b.button_down.connect(func() -> void:
		haptic(1)
		if reduced() or not b.is_inside_tree():
			return
		_center_pivot(b)
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.06))
	b.button_up.connect(func() -> void:
		if reduced() or not b.is_inside_tree():
			b.scale = Vector2.ONE
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## 햅틱. level 1=라이트(카드 탭·결과 긍정) 2=미디엄(가족 컷·전환기 성공). 04 문서 매핑.
static func haptic(level: int = 1) -> void:
	if haptic_level == 0 or force_reduced:
		return
	if not (OS.has_feature("mobile") or OS.has_feature("web")):
		return
	var ms := 20 if level <= 1 else 45
	if haptic_level >= 2:
		ms = int(float(ms) * 1.6)
	Input.vibrate_handheld(ms)


static func _center_pivot(n: Control) -> void:
	n.pivot_offset = n.size * 0.5
	if not n.has_meta("fx_pivot"):
		n.set_meta("fx_pivot", true)
		n.resized.connect(func() -> void: n.pivot_offset = n.size * 0.5)

class_name DeltaPopup
extends Label
## 스탯 델타 팝업. 색상으로 부상 후 소멸(04 문서 VFX 언어).
## 동시 다발 시 delay 로 스태거(04 문서: 델타 팝업 스태거 규정).

static func spawn(parent: Control, at: Vector2, text: String, color: Color, reduced: bool,
		icon_kind: String = "", delay: float = 0.0) -> void:
	var l := DeltaPopup.new()
	l.text = text
	if UIKit.title_font != null:
		l.add_theme_font_override("font", UIKit.title_font)
	l.add_theme_font_size_override("font_size", UIKit.sz(32))
	l.add_theme_color_override("font_color", color)
	l.position = at
	l.z_index = 50
	if icon_kind != "":
		var px := UIKit.sz(28)
		var ic := GameIcon.make(icon_kind, float(px), color)
		ic.position = Vector2(-float(px) - 2.0, 4.0)
		l.add_child(ic)
	parent.add_child(l)
	if reduced:
		# 노드 소속 트윈: 부모가 먼저 해제돼도 freed 콜백이 남지 않는다.
		var dt := l.create_tween()
		dt.tween_interval(0.9 + delay)
		dt.tween_callback(l.queue_free)
		return
	var tw := l.create_tween()
	if delay > 0.0:
		l.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void: l.visible = true)
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", at.y - 60, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

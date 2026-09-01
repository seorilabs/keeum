class_name ShareCard
extends RefCounted
## 엔딩 결과 공유 카드(1080×1350)를 SubViewport 로 오프스크린 렌더해 user:// 에 PNG 저장.
## 네이티브 공유 인텐트·웹 다운로드는 다음 게이트(스토어 빌드) — 여기서는 저장까지.

static func save(host: Node, ending: Dictionary, child_name: String, hair: String,
		outfit: Color, generation: int) -> String:
	if DisplayServer.get_name().to_lower() == "headless":
		return ""
	var vp := SubViewport.new()
	vp.size = Vector2i(1080, 1350)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	vp.add_child(_build_card(ending, child_name, hair, outfit, generation))
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return ""
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return ""
	var path := "user://share_%s.png" % str(ending.get("id", "ending"))
	if img.save_png(path) != OK:
		return ""
	return path

static func _build_card(ending: Dictionary, child_name: String, hair: String,
		outfit: Color, generation: int) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.custom_minimum_size = Vector2(1080, 1350)

	var grad := Gradient.new()
	grad.set_color(0, Color("FDEBD8"))
	grad.set_color(1, UIKit.CREAM_DEEP)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = gtex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# 엔딩 CG 가 있으면 상단에 깔고, 없으면 아바타를 크게.
	var cg := Art.tex("cg_" + str(ending.get("id", "")))
	if cg != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = cg
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.position = Vector2(60, 80)
		tex_rect.size = Vector2(960, 620)
		tex_rect.clip_contents = true
		root.add_child(tex_rect)
	else:
		var avatar := ChildAvatar.new()
		avatar.reduce_motion = true
		avatar.set_appearance(hair, outfit)
		avatar.set_look("high", "proud")
		avatar.position = Vector2(240, 60)
		avatar.size = Vector2(600, 640)
		root.add_child(avatar)

	var v := UIKit.vbox(18)
	v.position = Vector2(80, 760)
	v.size = Vector2(920, 520)
	root.add_child(v)
	var title := UIKit.title(str(ending.get("title", "")), 56)
	v.add_child(title)
	v.add_child(UIKit.label("%s · %s" % [ending.get("university", ""), ending.get("career", "")],
		34, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer(20))
	v.add_child(UIKit.label("%d번째 아이, %s의 이야기" % [generation, child_name],
		32, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer(30))
	v.add_child(UIKit.label("— 내 새끼 대학 보내기 —", 28, UIKit.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	return root

class_name GachaScreen
extends UIScreen
## SCR-012 코스메틱 뽑기. 성능 무영향. 확률·천장 상시 공개(정책 필수, DEC-010/029).
## 표기 확률과 추첨 로직 일치를 보장(스페셜 3% / 레어 17% / 일반 80%, 천장 40회).
## 리브얼 연출: 선물 상자 → 순차 공개(탭=전량 즉시). 페이크·니어미스·재촉 없음(압박형 금지).
## 확률·천장 패널은 리브얼 중에도 가리지 않는다.

const PROB_SPECIAL := 0.03
const PROB_RARE := 0.17
const PITY := 40
const COST_SINGLE := 150
const COST_TEN := 1350
const MILEAGE := {"special": 100, "rare": 20, "normal": 5}
const POOL := {
	"special": ["별빛 밤하늘 테마", "숲의 요정 펫", "구름 위 다락방 테마"],
	"rare": ["봄나들이 코스튬", "새 교복 세트", "한복 나들이 세트", "우주비행사 코스튬"],
	"normal": ["리본 핀", "동그란 안경", "노란 우산", "강아지 인형", "밀짚모자", "폭신 목도리"],
}

var _rng := RandomNumberGenerator.new()
var _pity_label: Label
var _premium_label: Label
var _mileage_label: Label
var _results: VBoxContainer
var _revealing := false
var _skip := false

func enter(_data: Variant = null) -> void:
	_rng.seed = randi()
	GameController.track("raise_gacha_view", {})
	var root := page_root(54)

	var top := UIKit.hbox(8)
	top.add_child(UIKit.title("코스메틱 뽑기", 36))
	top.add_child(UIKit.spacer())
	var pbox := UIKit.hbox(6)
	pbox.add_child(UIKit.icon("gem", UIKit.sz(26) + 2, UIKit.PREMIUM))
	_premium_label = UIKit.label("%d" % GameController.profile.premium, 26, UIKit.PREMIUM)
	pbox.add_child(_premium_label)
	top.add_child(pbox)
	root.add_child(top)

	# 확률·천장 공개 패널(구매 직전 상시 표시)
	var disc := UIKit.panel(UIKit.CARD, 18)
	var dv := UIKit.vbox(6)
	disc.add_child(dv)
	dv.add_child(UIKit.label("확률 공개 (유상·무상 통합 동일)", 24, UIKit.TEXT))
	dv.add_child(_prob_row("스페셜 (테마·펫)", "3.0%", UIKit.TALENT))
	dv.add_child(_prob_row("레어 (코스튬 세트)", "17.0%", UIKit.BLUE))
	dv.add_child(_prob_row("일반 (파츠·소품)", "80.0%", UIKit.SAGE))
	_pity_label = UIKit.label("", 22, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true)
	dv.add_child(_pity_label)
	_mileage_label = UIKit.label("", 22, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true)
	dv.add_child(_mileage_label)
	root.add_child(disc)
	_refresh_labels()

	var single := UIKit.icon_button("gem", "단차 뽑기 · %d" % COST_SINGLE, true)
	single.pressed.connect(_pull.bind(1, COST_SINGLE))
	root.add_child(single)
	var ten := UIKit.icon_button("gem", "10연 뽑기 · %d (10%% 할인)" % COST_TEN)
	ten.pressed.connect(_pull.bind(10, COST_TEN))
	root.add_child(ten)

	var body := scroll_body(root)
	_results = UIKit.vbox(8)
	body.add_child(_results)

	var back := UIKit.button("상점으로")
	back.pressed.connect(func() -> void:
		AudioBus.tap()
		router.goto("shop"))
	root.add_child(back)
	FX.stagger_children(root, 0.05)

func _prob_row(name: String, pct: String, color: Color) -> Control:
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(name, 22, UIKit.TEXT))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(pct, 24, color))
	return row

func _refresh_labels() -> void:
	var p: Profile = GameController.profile
	_premium_label.text = "%d" % p.premium
	_pity_label.text = "천장까지 %d회 (누적 %d/%d 시 스페셜 확정)" % [PITY - p.gacha_pity, p.gacha_pity, PITY]
	_mileage_label.text = "마일리지 %d · 교환소에서 원하는 코스메틱과 교환" % p.mileage

func _pull(count: int, cost: int) -> void:
	if _revealing:
		_skip = true  # 공개 중 재탭 = 남은 행 즉시 공개
		return
	var p: Profile = GameController.profile
	if p.premium < cost:
		router.toast("젬이 부족해요 (일일 무료 통화·업적으로도 모을 수 있어요)")
		AudioBus.stress_nudge()
		return
	p.add_premium(-cost)
	for c: Node in _results.get_children():
		c.queue_free()
	# 추첨·저장은 연출과 완전 분리(표기 확률 일치 보증 유지).
	var results: Array = []
	var got_special := false
	for i in count:
		var r := _draw_one(p)
		results.append(r)
		if r["tier"] == "special":
			got_special = true
	GameController.save_game()
	GameController.track("raise_gacha_pull", {"pull_count": count, "pity_count": p.gacha_pity, "paid_or_free": "premium"})
	_refresh_labels()
	if reduce_motion():
		for r: Dictionary in results:
			_results.add_child(_result_row(r))
		if got_special:
			AudioBus.sting("sting_gacha_special")
		else:
			AudioBus.chime()
		return
	_play_reveal(results, got_special)

## 리브얼: 선물 상자 팝 → (스페셜 전조) → 행 순차 공개. 상자·화면 탭 = 전량 즉시 공개.
func _play_reveal(results: Array, got_special: bool) -> void:
	_revealing = true
	_skip = false
	var box := UIKit.button("")
	box.custom_minimum_size = Vector2(0, 120)
	var bv := UIKit.vbox(4)
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gift := GameIcon.make("ribbon", float(UIKit.sz(48)), UIKit.CORAL)
	var gift_wrap := UIKit.hbox(0)
	gift_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	gift_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift_wrap.add_child(gift)
	bv.add_child(gift_wrap)
	var hint := UIKit.label("선물이 도착했어요 · 탭해서 열기", 22, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(hint)
	box.add_child(bv)
	box.pressed.connect(func() -> void: _skip = true)
	_results.add_child(box)
	FX.pop_in(box)
	AudioBus.chime()

	await _delay_or_skip(0.7)
	if not is_inside_tree():
		return
	if got_special and not _skip:
		# 스페셜 전조: 보라 글로우 1회(니어미스·페이크 없음 — 실제 결과일 때만)
		box.modulate = Color(0.85, 0.75, 1.0)
		FxBurst.burst(box, box.size * 0.5, "glow", 1)
		AudioBus.sting("sting_gacha_special")
		FX.haptic(2)
		await _delay_or_skip(0.6)
		if not is_inside_tree():
			return
	box.queue_free()

	for i in results.size():
		var r: Dictionary = results[i]
		var row := _result_row(r)
		_results.add_child(row)
		FX.pop_in(row)
		if str(r["tier"]) == "special":
			FxBurst.burst(row, Vector2(60.0, row.size.y * 0.5 + 30.0), "glow", 1)
			FX.haptic(2)
		if not _skip and i < results.size() - 1:
			await _delay_or_skip(0.22)
			if not is_inside_tree():
				return
	if got_special:
		AudioBus.positive()
	else:
		AudioBus.chime()
	_revealing = false

func _delay_or_skip(sec: float) -> void:
	if _skip:
		return
	# 화면 소속 트윈 대기: 화면이 해제되면 트윈이 죽어 코루틴이 조용히 끝난다.
	var tw := create_tween()
	tw.tween_interval(sec)
	await tw.finished

func _draw_one(p: Profile) -> Dictionary:
	p.gacha_pity += 1
	var tier := ""
	if p.gacha_pity >= PITY:
		tier = "special"
		p.gacha_pity = 0
	else:
		var r := _rng.randf()
		if r < PROB_SPECIAL:
			tier = "special"
			p.gacha_pity = 0
		elif r < PROB_SPECIAL + PROB_RARE:
			tier = "rare"
		else:
			tier = "normal"
	var pool: Array = POOL[tier]
	var item := str(pool[_rng.randi() % pool.size()])
	var dup := p.owned_cosmetics.has(item)
	if dup:
		p.mileage += int(MILEAGE[tier])
	else:
		p.owned_cosmetics.append(item)
	return {"item": item, "tier": tier, "dup": dup}

func _result_row(r: Dictionary) -> Control:
	var color := UIKit.SAGE
	var tname := "일반"
	var ticon := "dice"
	match r["tier"]:
		"special": color = UIKit.TALENT; tname = "스페셜"; ticon = "sparkle"
		"rare": color = UIKit.BLUE; tname = "레어"; ticon = "ribbon"
	var item := str(r["item"])
	var panel := UIKit.panel(UIKit.CARD, 14)
	var h := UIKit.hbox(8)
	panel.add_child(h)
	# 코스메틱 아이콘(생성 에셋 접합부 — 없으면 티어 벡터 아이콘)
	var info := Art.cosmetic(item)
	var thumb := Art.tex(str(info.get("asset", ""))) if not info.is_empty() else null
	if thumb != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = thumb
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(44, 44)
		h.add_child(tex_rect)
	else:
		h.add_child(UIKit.icon(ticon, UIKit.sz(26) + 2, color))
	h.add_child(UIKit.label("[%s]" % tname, 22, color))
	h.add_child(UIKit.label(item, 24, UIKit.TEXT))
	h.add_child(UIKit.spacer())
	if bool(r["dup"]):
		h.add_child(UIKit.label("중복 → 마일리지", 20, UIKit.TEXT_SOFT))
	else:
		var new_label := UIKit.label("NEW", 20, UIKit.CORAL)
		h.add_child(new_label)
		FX.pop_in(new_label, 0.2)
		# 보상 시각 폐쇄: 바로 입히기(아바타·배경에 즉시 반영)
		if not info.is_empty():
			var wear := UIKit.button("입히기")
			wear.custom_minimum_size = Vector2(120, UIKit.TOUCH_MIN)
			wear.pressed.connect(func() -> void:
				AudioBus.bonding()
				GameController.equip_cosmetic(str(info.get("slot", "")), item)
				router.toast("%s 장착! 홈에서 확인해 보세요" % item))
			h.add_child(wear)
	return panel

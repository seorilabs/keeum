class_name ApplicationScreen
extends UIScreen
## 입시 원서 선택. 최종 스탯 + 원서 선택으로 다중 엔딩이 분기한다.

const OPTION_HINT := {
	"hanul": "성적이 높을수록 유리해요. 도전!",
	"stable": "무리 없이 합격을 노려요.",
	"art": "특기가 빛나는 길이에요.",
	"free": "성적 밖에서 자기 길을 찾아요.",
}
const OPTION_ORDER := ["hanul", "stable", "art", "free"]

func enter(_data: Variant = null) -> void:
	var run: GameRun = GameController.run
	GameController.save_game()

	var root := page_root(60)
	root.add_child(UIKit.label("· 열아홉, 입시 ·", 22, UIKit.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UIKit.title("어느 길로 원서를 낼까요?", 34))

	var summary := UIKit.panel(UIKit.CARD, 22)
	var sv := UIKit.vbox(8)
	summary.add_child(sv)
	sv.add_child(_row("성적 평균", run.child.academic_average(), "%d점", UIKit.BLUE))
	sv.add_child(_row("특기", run.child.talent, "%d", UIKit.TALENT))
	sv.add_child(_row("정서", run.child.emotion, "%d", UIKit.CORAL))
	sv.add_child(_row("유대감", run.household.bonding, "%d", UIKit.PINK))
	sv.add_child(_row("스트레스", run.child.stress, "%d", UIKit.AMBER))
	root.add_child(summary)

	var body := scroll_body(root)
	for app: String in OPTION_ORDER:
		var b := UIKit.button("%s\n%s" % [GameController.application_label(app), OPTION_HINT.get(app, "")])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 90)
		b.pressed.connect(_choose.bind(app))
		body.add_child(b)
	FX.stagger_children(body, 0.07)

## 19년 육아의 결산 — 수치를 카운트업으로 회고(피드백 4단).
func _row(name: String, value: int, fmt: String, color: Color) -> Control:
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(name, 26, UIKit.TEXT))
	row.add_child(UIKit.spacer())
	var vlabel := UIKit.label(fmt % value, 28, color)
	row.add_child(vlabel)
	FX.count_up(vlabel, value, 0, 0.6, fmt)
	return row

func _choose(app: String) -> void:
	AudioBus.chime()
	var run: GameRun = GameController.run
	run.set_application(app)
	var ending := run.determine_ending()
	router.goto("ending", ending)

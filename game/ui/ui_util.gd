class_name UIUtil
extends RefCounted
## UI 표시 계산 헬퍼(표정·색·라벨). 규칙 아님(core 참조만).

static func mood_expression(child: Child) -> String:
	if child.stress >= 82:
		return "tired"
	elif child.stress >= 62:
		return "sad"
	elif child.emotion >= 75:
		return "proud"
	elif child.emotion >= 55:
		return "happy"
	return "neutral"

static func reaction_expression(result: Dictionary, child: Child) -> String:
	var stress_up := int(result.get("stress", 0))
	var bonding_up := int(result.get("bonding", 0))
	var subj_total := 0
	for k: String in result.get("subjects", {}):
		subj_total += int(result["subjects"][k])
	if stress_up >= 12:
		return "tired"
	if bonding_up >= 6:
		return "happy"
	if subj_total >= 14:
		return "proud"
	if int(result.get("talent", 0)) >= 6:
		return "excited"
	if child.stress >= 70:
		return "sad"
	return "happy"

static func configure_avatar(avatar: ChildAvatar, run: GameRun, reduced: bool) -> void:
	avatar.reduce_motion = reduced
	var hair := str(run.child.appearance.get("hair", "mushroom"))
	var outfit := Color(str(run.child.appearance.get("outfit", "F28C79")))
	avatar.set_appearance(hair, outfit)
	if GameController.profile != null:
		avatar.cosmetics = GameController.profile.equipped
	avatar.set_look(run.child.stage, mood_expression(run.child))

static func mood_line(run: GameRun) -> String:
	var c := run.child
	if c.stress >= 85:
		return "\"...더는 못 하겠어요.\" 아이가 지쳐 있어요."
	if c.stress >= 65:
		return "요즘 부쩍 예민해졌어요. 쉼이 필요해 보여요."
	if run.household.bonding >= 70 and c.emotion >= 70:
		return "아이가 활짝 웃어요. 오늘도 마음이 단단해요."
	if c.emotion >= 60:
		return "%s은(는) 오늘도 씩씩하게 하루를 보냈어요." % c.name
	return "조금 시무룩하지만, 곁에 있어 주면 괜찮아요."

static func revealed_text(revealed: Array) -> String:
	if revealed.is_empty():
		return ""
	var names: Array[String] = []
	for axis: String in revealed:
		names.append(str(Balance.APTITUDE_NAME.get(axis, axis)))
	return "새로운 적성 발견: %s" % ", ".join(names)

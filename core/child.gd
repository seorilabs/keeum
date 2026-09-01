class_name Child
extends RefCounted
## 자녀 상태 (엔진 독립). 회차 단위로 reset 되는 데이터.
##
## 선천 4층 프로필(기질·적성·체질·멘탈) + 성적/체력/정서/특기/스트레스.
## 성별(gender)은 외형·인칭 전용이며 스탯·이벤트·엔딩 로직에서 참조하지 않는다.

const STAT_MAX := 100

var id: String = ""
var name: String = ""
var gender: String = "neutral"  # son / daughter / neutral — 외형 전용
var appearance: Dictionary = {}  # 파츠 프리셋
var seed: int = 0

# 선천 4층
var temperament: String = "diligent"
var aptitude_grades: Dictionary = {}    # {axis: "A".."E"}
var aptitude_revealed: Dictionary = {}  # {axis: bool}  디스커버리
var mental_tolerance: int = 50          # 스트레스내성 0~100
var resilience: int = 50                # 회복탄력성 0~100
var constitution: int = 50              # 체질(기초체력) 0~100

# 나이·단계
var age: int = 4
var stage: String = "infant"

# 스탯
var subject_scores: Dictionary = {}  # {subject: int}
var stamina: int = 60
var emotion: int = 60
var talent: int = 10
var stress: int = 20

func _init() -> void:
	for subject: String in Balance.SUBJECTS:
		if subject != "talent":
			subject_scores[subject] = 20
	for axis: String in Balance.APTITUDES:
		aptitude_revealed[axis] = false

static func clampi_stat(v: int) -> int:
	return clampi(v, 0, STAT_MAX)

func add_stress(delta: int) -> void:
	stress = clampi_stat(stress + delta)

func add_emotion(delta: int) -> void:
	emotion = clampi_stat(emotion + delta)

func add_stamina(delta: int) -> void:
	stamina = clampi_stat(stamina + delta)

func add_talent(delta: int) -> void:
	talent = clampi_stat(talent + delta)

func add_subject(subject: String, delta: int) -> void:
	if subject == "talent":
		add_talent(delta)
		return
	var cur: int = int(subject_scores.get(subject, 0))
	subject_scores[subject] = clampi_stat(cur + delta)

func subject_value(subject: String) -> int:
	if subject == "talent":
		return talent
	return int(subject_scores.get(subject, 0))

## 입시 핵심 5과목 평균(특기 제외).
func academic_average() -> int:
	var total := 0
	var n := 0
	for subject: String in Balance.SUBJECTS:
		if subject == "talent":
			continue
		total += subject_value(subject)
		n += 1
	return int(round(float(total) / float(maxi(n, 1))))

## 활동으로 관련 적성을 드러낸다(디스커버리).
func reveal_aptitudes_for_subject(subject: String) -> Array[String]:
	var newly: Array[String] = []
	for axis: String in Balance.SUBJECT_APTITUDES.get(subject, []):
		if not bool(aptitude_revealed.get(axis, false)):
			aptitude_revealed[axis] = true
			newly.append(axis)
	return newly

func is_aptitude_revealed(axis: String) -> bool:
	return bool(aptitude_revealed.get(axis, false))

func aptitude_display(axis: String) -> String:
	if is_aptitude_revealed(axis):
		return str(aptitude_grades.get(axis, "C"))
	return "?"

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "gender": gender, "appearance": appearance, "seed": seed,
		"temperament": temperament, "aptitude_grades": aptitude_grades.duplicate(),
		"aptitude_revealed": aptitude_revealed.duplicate(),
		"mental_tolerance": mental_tolerance, "resilience": resilience, "constitution": constitution,
		"age": age, "stage": stage,
		"subject_scores": subject_scores.duplicate(),
		"stamina": stamina, "emotion": emotion, "talent": talent, "stress": stress,
	}

static func from_dict(d: Dictionary) -> Child:
	var c := Child.new()
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", ""))
	c.gender = str(d.get("gender", "neutral"))
	c.appearance = d.get("appearance", {})
	c.seed = int(d.get("seed", 0))
	c.temperament = str(d.get("temperament", "diligent"))
	c.aptitude_grades = d.get("aptitude_grades", {})
	c.aptitude_revealed = d.get("aptitude_revealed", {})
	c.mental_tolerance = int(d.get("mental_tolerance", 50))
	c.resilience = int(d.get("resilience", 50))
	c.constitution = int(d.get("constitution", 50))
	c.age = int(d.get("age", 4))
	c.stage = str(d.get("stage", "infant"))
	c.subject_scores = d.get("subject_scores", {})
	c.stamina = int(d.get("stamina", 60))
	c.emotion = int(d.get("emotion", 60))
	c.talent = int(d.get("talent", 10))
	c.stress = int(d.get("stress", 20))
	return c

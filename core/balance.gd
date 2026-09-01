class_name Balance
extends RefCounted
## 밸런스 상수 원장 (엔진 독립).
##
## 02-gdd.md 성장 공식·궁합 매트릭스 v0 수치를 코드화한다. 모든 값은 Remote Config
## 튜닝 대상이므로 GameRun 이 override 딕셔너리로 덮어쓸 수 있게 static getter 로 노출한다.
## core 는 Godot·Firebase·광고·결제 SDK 를 import 하지 않는다(RefCounted 만 사용).

# --- 기질 (temperament) ---
const TEMPERAMENTS: Array[String] = [
	"diligent", "distracted", "competitive", "sensitive", "immersive", "relaxed",
]
const TEMPERAMENT_NAME := {
	"diligent": "성실형", "distracted": "산만형", "competitive": "승부욕형",
	"sensitive": "감성형", "immersive": "몰입형", "relaxed": "느긋형",
}

# --- 학습 방법 (method) ---
const METHODS: Array[String] = [
	"preemptive", "deep", "self", "drill", "concept", "group", "spartan", "experience",
]
const METHOD_NAME := {
	"preemptive": "선행", "deep": "심화", "self": "자기주도", "drill": "양치기",
	"concept": "개념이해", "group": "그룹", "spartan": "스파르타", "experience": "체험·게임화",
}
# K_방법(효율) 과 S_스트레스원.
const METHOD_K := {
	"spartan": 1.40, "preemptive": 1.30, "drill": 1.20, "deep": 1.15,
	"concept": 1.00, "group": 1.05, "self": 0.90, "experience": 0.45,
}
const METHOD_STRESS := {
	"spartan": 18.0, "preemptive": 12.0, "drill": 9.0, "deep": 8.0,
	"concept": 5.0, "group": 6.0, "self": 4.0, "experience": -4.0,
}

# --- 기관 (institution) B_기관 ---
const INSTITUTION_B := {
	"specialty": 13.0,  # 단과 전문학원
	"tutor": 11.0,      # 개인과외
	"academy": 7.0,     # 종합입시학원
	"online": 6.0,      # 인강
	"study": 5.0,       # 자습·독서실
	"afterschool": 4.0, # 방과후
	"none": 0.0,
}

# --- 적성 등급 배수 M_적성 ---
const GRADE_MULT := {"A": 1.4, "B": 1.2, "C": 1.0, "D": 0.8, "E": 0.6}
const GRADES: Array[String] = ["A", "B", "C", "D", "E"]

# --- 인지 적성 6축 (신체감각 포함: 특기 산출용) ---
const APTITUDES: Array[String] = [
	"memory", "understanding", "language", "math", "creative", "physical",
]
const APTITUDE_NAME := {
	"memory": "암기", "understanding": "이해", "language": "언어",
	"math": "수리", "creative": "창의", "physical": "신체감각",
}

# --- 과목 → 적성 매핑 ---
const SUBJECTS: Array[String] = ["korean", "english", "math", "science", "social", "talent"]
const SUBJECT_NAME := {
	"korean": "국어", "english": "영어", "math": "수학",
	"science": "과학", "social": "탐구", "talent": "특기",
}
const SUBJECT_APTITUDES := {
	"korean": ["language", "understanding"],
	"english": ["language", "memory"],
	"math": ["math", "understanding"],
	"science": ["understanding", "math"],
	"social": ["memory", "understanding"],
	"talent": ["creative", "physical"],
}

# --- M_궁합 매트릭스 (기질 × 방법) + T_기질 ---
# 열 순서: preemptive deep self drill concept group spartan experience
const COMPAT := {
	"diligent":    {"preemptive": 1.1, "deep": 1.2, "self": 1.3, "drill": 1.2, "concept": 1.0, "group": 1.0, "spartan": 1.1, "experience": 0.9},
	"distracted":  {"preemptive": 0.7, "deep": 0.8, "self": 0.8, "drill": 0.9, "concept": 1.0, "group": 1.0, "spartan": 0.6, "experience": 1.3},
	"competitive": {"preemptive": 1.2, "deep": 1.2, "self": 0.9, "drill": 1.1, "concept": 0.9, "group": 1.3, "spartan": 1.3, "experience": 0.8},
	"sensitive":   {"preemptive": 0.8, "deep": 1.0, "self": 1.1, "drill": 0.8, "concept": 1.3, "group": 1.1, "spartan": 0.6, "experience": 1.3},
	"immersive":   {"preemptive": 1.1, "deep": 1.3, "self": 1.3, "drill": 0.8, "concept": 1.4, "group": 0.9, "spartan": 0.9, "experience": 1.2},
	"relaxed":     {"preemptive": 0.9, "deep": 1.0, "self": 1.0, "drill": 1.0, "concept": 1.1, "group": 1.1, "spartan": 0.9, "experience": 1.1},
}
const TEMPERAMENT_T := {
	"diligent": 0.9, "distracted": 1.3, "competitive": 1.0,
	"sensitive": 1.3, "immersive": 1.0, "relaxed": 0.7,
}

# --- 연령 단계 ---
# 유아(4~7) → 초등(8~13) → 중등(14~16) → 고등(17~19) → 입시(19)
const STAGES: Array[String] = ["infant", "elementary", "middle", "high", "exam"]
const STAGE_NAME := {
	"infant": "유아", "elementary": "초등", "middle": "중등", "high": "고등", "exam": "입시",
}
# 각 단계 턴 수(1턴=1개월). 합계 약 48턴.
const STAGE_TURNS := {
	"infant": 6, "elementary": 12, "middle": 12, "high": 15, "exam": 3,
}
const STAGE_START_AGE := {
	"infant": 4, "elementary": 8, "middle": 14, "high": 17, "exam": 19,
}
const TURNS_PER_SEMESTER := 4

# --- 경제 ---
const BASE_INCOME_PER_TURN := 50
const START_MONEY := 300
const START_PREMIUM := 60

# --- 스트레스 → 컨디션 계수 M_컨디션 ---
const BURNOUT_THRESHOLD := 90

static func condition_mult(stress: int, emotion: int, stamina: int) -> float:
	var base: float
	if stress < 40:
		base = 1.0
	elif stress < 60:
		base = 0.9
	elif stress < 75:
		base = 0.75
	elif stress < 90:
		base = 0.55
	else:
		base = 0.35
	if emotion >= 70 and stamina >= 60:
		base += 0.1
	return base

static func grade_mult(grade: String) -> float:
	return GRADE_MULT.get(grade, 1.0)

## 과목의 M_적성 = 관련 두 적성 등급 배수의 평균.
static func subject_aptitude_mult(subject: String, aptitude_grades: Dictionary) -> float:
	var axes: Array = SUBJECT_APTITUDES.get(subject, [])
	if axes.is_empty():
		return 1.0
	var total := 0.0
	for axis: String in axes:
		total += grade_mult(str(aptitude_grades.get(axis, "C")))
	return total / float(axes.size())

static func compat_mult(temperament: String, method: String) -> float:
	var row: Dictionary = COMPAT.get(temperament, {})
	return float(row.get(method, 1.0))

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

# --- 선천 4층 프로필: 체질·회복탄력성 보정 (DEC-014 의 「체질」·「멘탈」 층, #27) ---
## 두 축의 기준선. **기준선에서는 모든 보정이 정확히 0/1배**라 기존 수치(AC-001~003·
## 번아웃 90)가 그대로 남는다. 아이 생성 범위는 35~70이라 보정은 그 폭 안에서만 움직인다.
const INNATE_BASELINE := 50

## 학습 활동 1건의 기본 체력 소모. 체질이 이 부하를 덜어 준다.
const LEARN_STAMINA_COST := 2
## 체질 ±25 → 학습 체력 소모 ∓1. 생성 범위(35~70)에서 소모는 1~3 사이다.
const CONSTITUTION_LOAD_SPAN := 25.0

## 회복탄력성 ±50 → 정서 회복량 ±50%. 생성 범위에서 0.85~1.20배다.
const RESILIENCE_RECOVERY_SPAN := 100.0

## 회복탄력성 ±5 → 번아웃 임계 ±1. 생성 범위에서 임계는 87~94다.
const BURNOUT_RESILIENCE_SPAN := 5.0

## 번아웃 임계. 고정 90이 아니라 멘탈 층(회복탄력성)이 밀어 올리거나 끌어내린다.
## 잘 버티는 아이는 더 늦게, 잘 무너지는 아이는 더 일찍 번아웃에 닿는다.
static func burnout_threshold(resilience: int) -> int:
	var shift := int(round(float(resilience - INNATE_BASELINE) / BURNOUT_RESILIENCE_SPAN))
	return clampi(BURNOUT_THRESHOLD + shift, 80, 99)

## 정서 회복량 보정. 회복탄력성이 높을수록 같은 여가에서 더 크게 돌아온다.
## 깎이는 쪽(음수)에는 걸지 않는다 — 탄력성은 회복 축이지 피해 감소 축이 아니다.
static func emotion_recovery(amount: int, resilience: int) -> int:
	if amount <= 0:
		return amount
	var mult := 1.0 + float(resilience - INNATE_BASELINE) / RESILIENCE_RECOVERY_SPAN
	return maxi(1, int(round(float(amount) * mult)))

## 학습 활동의 체력 소모. 체질이 높을수록 같은 활동을 덜 지친 채 버틴다.
static func learn_stamina_cost(constitution: int) -> int:
	var relief := float(constitution - INNATE_BASELINE) / CONSTITUTION_LOAD_SPAN
	return maxi(1, int(round(float(LEARN_STAMINA_COST) - relief)))

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

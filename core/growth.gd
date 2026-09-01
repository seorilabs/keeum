class_name Growth
extends RefCounted
## 결정적 성장·스트레스 공식 (엔진 독립, 순수 함수).
##
## 02-gdd.md:
##   Δ과목 = B_기관 × K_방법 × M_적성 × M_궁합 × M_컨디션   (소수 절사)
##   ΔStress = S_방법 × T_기질 × (1 − 멘탈내성/200) − 여가·휴식 회복   (반올림)
##
## AC-001~003 을 재현하도록 절사(subject)·반올림(stress) 규칙을 고정한다.

## 과목 성장 델타. 절사(int, 0 방향)로 고정.
static func subject_delta(
		institution_b: float, method_k: float, aptitude_mult: float,
		compat_mult: float, condition_mult: float) -> int:
	var raw := institution_b * method_k * aptitude_mult * compat_mult * condition_mult
	return int(raw)  # 소수 절사

## 스트레스 델타. 반올림으로 고정. mental = 멘탈 스트레스내성(0~100).
static func stress_delta(method_stress: float, temperament_t: float, mental_tolerance: int) -> int:
	var raw := method_stress * temperament_t * (1.0 - float(mental_tolerance) / 200.0)
	return int(round(raw))

## 학습 활동 1건의 과목별 델타를 계산해 딕셔너리로 반환.
## activity: 기관/방법/과목 정보를 담은 Dictionary. child: Child.
static func learn_result(activity: Dictionary, child: Child) -> Dictionary:
	var institution: String = activity.get("institution", "none")
	var method: String = activity.get("method", "concept")
	var b: float = Balance.INSTITUTION_B.get(institution, 0.0)
	var k: float = Balance.METHOD_K.get(method, 1.0)
	var compat := Balance.compat_mult(child.temperament, method)
	var cond := Balance.condition_mult(child.stress, child.emotion, child.stamina)
	var subject_deltas := {}
	for subject: String in activity.get("subjects", []):
		var apt := Balance.subject_aptitude_mult(subject, child.aptitude_grades)
		var d := subject_delta(b, k, apt, compat, cond)
		if d != 0:
			subject_deltas[subject] = d
	var s: float = Balance.METHOD_STRESS.get(method, 0.0)
	var t: float = Balance.TEMPERAMENT_T.get(child.temperament, 1.0)
	var ds := stress_delta(s, t, child.mental_tolerance)
	return {
		"subjects": subject_deltas,
		"stress": ds,
		"condition": cond,
	}

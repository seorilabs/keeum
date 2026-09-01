class_name Household
extends RefCounted
## 가계 상태 (회차 단위). 재력·유대감·유혹 이력은 아이 회차와 함께 reset 된다.
## 프리미엄 통화·도감·코스메틱·해금은 Profile(영속)이 소유한다.

var money: int = Balance.START_MONEY   # 가계 재력(소프트 화폐)
var bonding: int = 30                  # 유대감 0~100 (느린 누적)
var generation: int = 1                # 몇 번째 아이(회차)

# 유혹별 상태: {id: {"uses": int, "dependency": int, "risk": int}}
var temptation_state: Dictionary = {}

func add_money(delta: int) -> void:
	money = maxi(0, money + delta)

func can_afford(cost: int) -> bool:
	return money >= cost

func add_bonding(delta: int) -> void:
	bonding = clampi(bonding + delta, 0, 100)

func temptation(id: String) -> Dictionary:
	if not temptation_state.has(id):
		temptation_state[id] = {"uses": 0, "dependency": 0, "risk": 0}
	return temptation_state[id]

func total_temptation_uses() -> int:
	var total := 0
	for id: String in temptation_state:
		total += int(temptation_state[id].get("uses", 0))
	return total

func to_dict() -> Dictionary:
	return {
		"money": money, "bonding": bonding, "generation": generation,
		"temptation_state": temptation_state.duplicate(true),
	}

static func from_dict(d: Dictionary) -> Household:
	var h := Household.new()
	h.money = int(d.get("money", Balance.START_MONEY))
	h.bonding = int(d.get("bonding", 30))
	h.generation = int(d.get("generation", 1))
	h.temptation_state = d.get("temptation_state", {})
	return h

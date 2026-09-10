class_name Profile
extends RefCounted
## 영속 프로필. 회차를 넘어 유지되는 도감·프리미엄 통화·코스메틱·가챠 상태.
## 05-economy: 프리미엄=하드 화폐, 도감·해금·코스메틱은 persist.

var schema_version: int = SaveSchema.CURRENT_VERSION  # #45: to_dict 가 기록하고 from_dict 가 판독한다
var premium: int = Balance.START_PREMIUM  # 💎 하드 화폐
var mileage: int = 0                      # 가챠 마일리지
var gacha_pity: int = 0                   # 천장 카운트(40회)
var ad_removed: bool = false
var total_runs: int = 0
var ad_daily_key: String = ""  # 보상형 광고 일일 캡(#34) 기준일. AdGateway 소유
var ad_daily_count: int = 0    # 위 기준일의 보상형 광고 시청 횟수

# 도감: 수집한 엔딩 id 집합과 회차 기록.
var collected_endings: Array = []         # Array[String]
var run_records: Array = []               # Array[Dictionary]
var owned_cosmetics: Array = []           # Array[String]
var equipped: Dictionary = {}             # slot -> 코스메틱 표시명 (owned_cosmetics 키와 동일)

func has_ending(id: String) -> bool:
	return collected_endings.has(id)

func register_ending(id: String) -> bool:
	## 신규 등록이면 true.
	if collected_endings.has(id):
		return false
	collected_endings.append(id)
	return true

func add_premium(delta: int) -> void:
	premium = maxi(0, premium + delta)

func add_run_record(rec: Dictionary) -> void:
	run_records.append(rec)
	total_runs += 1

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"premium": premium, "mileage": mileage, "gacha_pity": gacha_pity,
		"ad_removed": ad_removed, "total_runs": total_runs,
		"ad_daily_key": ad_daily_key, "ad_daily_count": ad_daily_count,
		"collected_endings": collected_endings.duplicate(),
		"run_records": run_records.duplicate(true),
		"owned_cosmetics": owned_cosmetics.duplicate(),
		"equipped": equipped.duplicate(),
	}

static func from_dict(d: Dictionary) -> Profile:
	var p := Profile.new()
	p.schema_version = int(d.get("schema_version", 0))
	p.premium = int(d.get("premium", Balance.START_PREMIUM))
	p.mileage = int(d.get("mileage", 0))
	p.gacha_pity = int(d.get("gacha_pity", 0))
	p.ad_removed = bool(d.get("ad_removed", false))
	p.total_runs = int(d.get("total_runs", 0))
	p.ad_daily_key = String(d.get("ad_daily_key", ""))
	p.ad_daily_count = int(d.get("ad_daily_count", 0))
	p.collected_endings = d.get("collected_endings", [])
	p.run_records = d.get("run_records", [])
	p.owned_cosmetics = d.get("owned_cosmetics", [])
	p.equipped = d.get("equipped", {})
	return p

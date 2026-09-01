class_name Art
extends Object
## 생성 에셋 단일 접합부. res://assets/art/<name>.png 이 있으면 텍스처, 없으면 null 을 돌려
## 호출부가 기존 프로시저 드로잉으로 폴백한다(에셋 도착 시 코드 수정 없이 승격).
## 헤어·코스메틱·계절 등 표시명→에셋 매핑도 여기서만 관리한다.

const DIR := "res://assets/art/"
const ANCHORS_PATH := "res://assets/art/face-anchors.json"

## 가챠 코스메틱 표시명(저장 키 그대로) → 슬롯·에셋. asset 은 outfit 만 접미사(cos_*),
## 나머지는 파일명 전체. 슬롯당 1개 장착(prop 2종은 상호 배타).
const COSMETICS := {
	"별빛 밤하늘 테마": {"slot": "theme", "asset": "bg_theme_starrynight"},
	"구름 위 다락방 테마": {"slot": "theme", "asset": "bg_theme_attic"},
	"숲의 요정 펫": {"slot": "pet", "asset": "pet_forest_fairy"},
	"봄나들이 코스튬": {"slot": "outfit", "asset": "cos_spring"},
	"새 교복 세트": {"slot": "outfit", "asset": "cos_uniform"},
	"한복 나들이 세트": {"slot": "outfit", "asset": "cos_hanbok"},
	"우주비행사 코스튬": {"slot": "outfit", "asset": "cos_astro"},
	"리본 핀": {"slot": "hairpin", "asset": "acc_ribbon"},
	"동그란 안경": {"slot": "glasses", "asset": "acc_glasses"},
	"노란 우산": {"slot": "prop", "asset": "acc_umbrella"},
	"강아지 인형": {"slot": "prop", "asset": "acc_puppy"},
	"밀짚모자": {"slot": "hat", "asset": "acc_strawhat"},
	"폭신 목도리": {"slot": "scarf", "asset": "acc_muffler"},
}

## 헤어 9 id → 시각 계열 3종(DEC-034). 프리셋(profiles.json)과 1:1 대응.
const HAIR_FAMILY := {
	"short_black": "short", "short_brown": "short", "curly": "short",
	"twin_tail": "twin", "long_wave": "twin", "bob": "twin",
	"mushroom": "mushroom", "short_soft": "mushroom", "wavy_short": "mushroom",
}

static var _cache: Dictionary = {}
static var _anchors: Dictionary = {}
static var _anchors_loaded := false


static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		t = load(path) as Texture2D
	_cache[name] = t
	return t


static func has_art(name: String) -> bool:
	return tex(name) != null


## 캐릭터 바디 텍스처 이름. exam 은 high 아트 공용. outfit 코스메틱 장착 시 코스튬 바디.
static func char_body_name(stage: String, hair_id: String, outfit_cosmetic: String = "") -> String:
	var st := "high" if stage == "exam" else stage
	if outfit_cosmetic != "" and COSMETICS.has(outfit_cosmetic):
		return "char_%s_%s" % [st, str((COSMETICS[outfit_cosmetic] as Dictionary).get("asset", ""))]
	return "char_%s_%s" % [st, hair_family(hair_id)]


static func hair_family(hair_id: String) -> String:
	return str(HAIR_FAMILY.get(hair_id, "mushroom"))


static func cosmetic(display_name: String) -> Dictionary:
	return COSMETICS.get(display_name, {}) as Dictionary


## 바디 스프라이트의 얼굴 앵커(정규화 좌표). 에셋 생산 시 face-anchors.json 으로 튜닝.
static func face_anchor(body_name: String) -> Dictionary:
	if not _anchors_loaded:
		_anchors_loaded = true
		if FileAccess.file_exists(ANCHORS_PATH):
			var txt := FileAccess.get_file_as_string(ANCHORS_PATH)
			var parsed: Variant = JSON.parse_string(txt)
			if parsed is Dictionary:
				_anchors = parsed
	var d := _anchors.get(body_name, {}) as Dictionary
	return {
		"cx": float(d.get("cx", 0.5)),
		"cy": float(d.get("cy", 0.30)),
		"r": float(d.get("r", 0.16)),
	}


## 턴 → 계절(학기 4턴 = 한 계절 순환). 홈 배경 variant 선택용.
@warning_ignore("integer_division")
static func season(turn: int) -> String:
	var idx := ((maxi(1, turn) - 1) / 4) % 4
	return ["spring", "summer", "autumn", "winter"][idx]

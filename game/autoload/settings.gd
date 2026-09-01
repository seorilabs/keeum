extends Node
## 사용자 설정 영속화 오토로드. 게임 세이브(LocalSave)와 분리된 user://keeum_settings.cfg 를 쓰며,
## 데이터 초기화(reset_all)에도 접근성·오디오 설정은 유지된다(03 문서 접근성 계약).
## 기동 시 FX(모션·햅틱)·AudioBus(음소거·볼륨)에 값을 주입한다.

const PATH := "user://keeum_settings.cfg"
const SECTION := "settings"

var muted := false
var reduce_motion := false
var haptic_level := 1     # 0=끔 1=보통 2=강
var bgm_volume := 0.8     # 0~1 선형
var sfx_volume := 0.9


func _ready() -> void:
	_load()
	_apply()


func set_value(key: String, v: Variant) -> void:
	set(key, v)
	_apply()
	_save()


func _apply() -> void:
	FX.reduce_motion = reduce_motion
	FX.haptic_level = haptic_level
	AudioBus.muted = muted
	if AudioBus.has_method("apply_volumes"):
		AudioBus.apply_volumes(bgm_volume, sfx_volume)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	muted = bool(cfg.get_value(SECTION, "muted", muted))
	reduce_motion = bool(cfg.get_value(SECTION, "reduce_motion", reduce_motion))
	haptic_level = int(cfg.get_value(SECTION, "haptic_level", haptic_level))
	bgm_volume = clampf(float(cfg.get_value(SECTION, "bgm_volume", bgm_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "muted", muted)
	cfg.set_value(SECTION, "reduce_motion", reduce_motion)
	cfg.set_value(SECTION, "haptic_level", haptic_level)
	cfg.set_value(SECTION, "bgm_volume", bgm_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.save(PATH)

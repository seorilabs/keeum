extends Node
## 오디오 어댑터. BGM/SFX 버스를 런타임 구성하고, assets/audio 에 에셋이 있으면 파일을,
## 없으면 절차 사인 톤 폴백을 재생한다(game-sound-pipeline 산출물 접합부 — 도착 시 코드 무수정 승격).
## 04-art-audio-bible 무드: 절제·따뜻함. 스트레스 경고는 짧은 저음(연타 금지).

const MIX_RATE := 44100
const POOL_SIZE := 6
const SFX_DIR := "res://assets/audio/sfx/"
const AUDIO_DIR := "res://assets/audio/"

var muted := false:
	set(v):
		muted = v
		AudioServer.set_bus_mute(0, v)  # Master 일괄(BGM 포함)

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}        # 사인 톤 캐시
var _file_cache: Dictionary = {}   # 파일 스트림 캐시(부재 시 null 캐시)
var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_active := 0
var _bgm_key := "__none"
# 헤드리스는 더미 오디오 드라이버라 stop 이 믹스되지 않아 파일 스트림이 종료 시 leak 로
# 보고된다 — 파일 로드를 생략하고 사인 폴백만 쓴다(하네스는 오디오 내용을 검증하지 않는다).
@onready var _headless: bool = DisplayServer.get_name().to_lower() == "headless"

func _ready() -> void:
	_make_bus("BGM")
	_make_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 2:
		var bp := AudioStreamPlayer.new()
		bp.bus = "BGM"
		add_child(bp)
		_bgm_players.append(bp)

func _exit_tree() -> void:
	# 플레이어의 stream 참조까지 해제("resources still in use at exit" 방지).
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	for bp: AudioStreamPlayer in _bgm_players:
		bp.stop()
		bp.stream = null
	_cache.clear()
	_file_cache.clear()

func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

## Settings 가 기동·변경 시 주입(0~1 선형).
func apply_volumes(bgm: float, sfx: float) -> void:
	var bi := AudioServer.get_bus_index("BGM")
	if bi >= 0:
		AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(0.0001, bgm)))
	var si := AudioServer.get_bus_index("SFX")
	if si >= 0:
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(0.0001, sfx)))

# ---------------------------------------------------------------- BGM
## 트랙 크로스페이드(플레이어 2개, 동일 key 무시). 트랙 파일이 없으면 페이드 아웃(무음).
## main.goto() 가 화면 → 트랙 맵으로 호출한다.
func play_bgm(key: String) -> void:
	if key == _bgm_key:
		return
	_bgm_key = key
	var stream := _file_stream(AUDIO_DIR + "bgm_" + key, ["ogg"])
	var cur := _bgm_players[_bgm_active]
	if stream == null:
		if cur.playing:
			_fade(cur, -40.0, 0.8, true)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_bgm_active = 1 - _bgm_active
	var nxt := _bgm_players[_bgm_active]
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	_fade(nxt, 0.0, 1.0, false)
	if cur.playing:
		_fade(cur, -40.0, 1.0, true)

func stop_bgm() -> void:
	_bgm_key = "__none"
	for p: AudioStreamPlayer in _bgm_players:
		if p.playing:
			_fade(p, -40.0, 0.6, true)

func _fade(p: AudioStreamPlayer, to_db: float, dur: float, stop_after: bool) -> void:
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", to_db, dur)
	if stop_after:
		tw.tween_callback(p.stop)

# ---------------------------------------------------------------- 공개 SFX
func tap() -> void:
	if muted:
		return
	if not _play_file(SFX_DIR + "tap"):
		_play("tap", 520.0, 0.06, 0.18, 0.0)

func positive() -> void:
	if muted:
		return
	if not _play_file(AUDIO_DIR + "sting_positive"):
		# 밝은 상승 스팅어(두 음).
		_play("pos1", 660.0, 0.09, 0.22, 0.0)
		_play("pos2", 880.0, 0.12, 0.22, 0.05)

func bonding() -> void:
	if muted:
		return
	if not _play_file(AUDIO_DIR + "sting_bonding"):
		# 하트 스팅어(따뜻한 5도).
		_play("bond1", 587.0, 0.14, 0.24, 0.0)
		_play("bond2", 784.0, 0.18, 0.24, 0.06)

func stress_nudge() -> void:
	if muted:
		return
	if not _play_file(SFX_DIR + "stress_nudge"):
		# 절제된 저음 넛지 1회.
		_play("stress", 180.0, 0.16, 0.16, 0.0)

func chime() -> void:
	if muted:
		return
	if not _play_file(SFX_DIR + "chime"):
		_play("chime", 990.0, 0.16, 0.2, 0.0)

func page() -> void:
	if muted:
		return
	if not _play_file(SFX_DIR + "page"):
		_play("page", 400.0, 0.05, 0.12, 0.0)

## 이름 지정 스팅어(assets/audio/<name>.wav|ogg). 없으면 positive 폴백.
## 예: sting("sting_gacha_special"), sting("sting_new_ending").
func sting(name: String) -> void:
	if muted:
		return
	if not _play_file(AUDIO_DIR + name):
		positive()

# ---------------------------------------------------------------- 내부
func _play_file(base_path: String) -> bool:
	var s := _file_stream(base_path, ["wav", "ogg"])
	if s == null:
		return false
	_emit(s)
	return true

func _file_stream(base_path: String, exts: Array) -> AudioStream:
	if _headless:
		return null
	if _file_cache.has(base_path):
		return _file_cache[base_path]
	var s: AudioStream = null
	for ext: String in exts:
		var path := base_path + "." + ext
		if ResourceLoader.exists(path, "AudioStream"):
			s = load(path) as AudioStream
			break
	_file_cache[base_path] = s
	return s

func _play(key: String, freq: float, dur: float, vol: float, delay: float) -> void:
	if muted:
		return
	var stream := _tone(key, freq, dur, vol)
	if delay > 0.0:
		var t := get_tree().create_timer(delay)
		t.timeout.connect(_emit.bind(stream))
	else:
		_emit(stream)

func _emit(stream: AudioStream) -> void:
	if _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()

func _tone(key: String, freq: float, dur: float, vol: float) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var attack := int(count * 0.12)
	var release := int(count * 0.5)
	for i in count:
		var t := float(i) / float(MIX_RATE)
		var env := 1.0
		if i < attack:
			env = float(i) / float(maxi(1, attack))
		elif i > count - release:
			env = float(count - i) / float(maxi(1, release))
		var sample := sin(TAU * freq * t) * env * vol
		var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	_cache[key] = wav
	return wav

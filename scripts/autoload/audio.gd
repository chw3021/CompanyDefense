# 효과음 + BGM. 버스 볼륨은 Save 설정을 따른다.
extends Node

const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const POOL := 10
const SFX_DIR := "res://assets/sfx/"
const BGM_PATH := "res://assets/bgm/office.wav"
const SFX_IDS := ["click", "hit", "projectile", "impact", "promote", "wave", "boss", "win", "lose"]

var _streams := {}  # id -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _last_ms := {}  # id -> 마지막 재생 시각(ms)
var _web_unlocked := false
var _bgm: AudioStreamPlayer
var _bgm_id := ""


func _ready() -> void:
	_ensure_buses()
	apply_volumes()
	_load_streams()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = BUS_BGM
	add_child(_bgm)
	# 모바일/웹 브라우저는 첫 터치 전에 AudioContext 가 잠긴다
	if OS.has_feature("web"):
		set_process_input(true)
	else:
		play_bgm("office")


func _input(event: InputEvent) -> void:
	if _web_unlocked or not OS.has_feature("web"):
		return
	var tap := event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey
	if not tap or not event.is_pressed():
		return
	_web_unlocked = true
	set_process_input(false)
	# 제스처 안에서 한 번 재생해야 이후 오디오가 나온다
	if not Save.sfx_muted() and _streams.has("click"):
		play("click", 1.0, 0)
	play_bgm("office")


func _ensure_buses() -> void:
	_ensure_bus(BUS_BGM)
	_ensure_bus(BUS_SFX)


func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, BUS_MASTER)


func apply_volumes() -> void:
	_set_bus_linear(BUS_MASTER, Save.volume_master())
	_set_bus_linear(BUS_BGM, Save.volume_bgm())
	# 음소거 토글은 효과음만 끈다. BGM 은 슬라이더를 따른다.
	_set_bus_linear(BUS_SFX, 0.0 if Save.sfx_muted() else Save.volume_sfx())


func _set_bus_linear(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func _load_streams() -> void:
	for id in SFX_IDS:
		var path: String = SFX_DIR + id + ".wav"
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
	if ResourceLoader.exists(BGM_PATH):
		var stream: AudioStream = load(BGM_PATH)
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_streams["office"] = stream


## gap_ms 안이면 같은 효과음을 다시 안 낸다 (전투 스팸 방지)
func play(id: String, pitch := 1.0, gap_ms := 40) -> void:
	if Save.sfx_muted() or not _streams.has(id) or _players.is_empty():
		return
	if Save.volume_master() <= 0.001 or Save.volume_sfx() <= 0.001:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -99999)) < gap_ms:
		return
	_last_ms[id] = now
	var p: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = clampf(pitch, 0.7, 1.4)
	p.play()


func play_bgm(id: String = "office") -> void:
	if not _streams.has(id) or _bgm == null:
		return
	if _bgm_id == id and _bgm.playing:
		return
	_bgm_id = id
	_bgm.stream = _streams[id]
	_bgm.play()


func stop_bgm() -> void:
	_bgm_id = ""
	if _bgm:
		_bgm.stop()


func click() -> void:
	play("click", randf_range(0.95, 1.05), 30)


func hit() -> void:
	play("hit", randf_range(0.9, 1.1), 50)


func projectile() -> void:
	play("projectile", randf_range(0.92, 1.12), 45)


func impact() -> void:
	play("impact", randf_range(0.9, 1.15), 55)


func promote() -> void:
	play("promote", randf_range(0.95, 1.05), 80)


func wave() -> void:
	play("wave", 1.0, 120)


func boss() -> void:
	play("boss", 1.0, 200)


func win() -> void:
	play("win", 1.0, 300)


func lose() -> void:
	play("lose", 1.0, 300)

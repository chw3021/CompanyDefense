# 효과음 + BGM. 버스 볼륨은 Save 설정을 따른다.
# 웹(Godot 4.3+): Sample 기본값은 커스텀 버스/루프와 잘 안 맞아서 Stream 강제 + 제스처 unlock.
extends Node

const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const POOL := 10
const SFX_DIR := "res://assets/sfx/"
const BGM_DIR := "res://assets/bgm/"
const SFX_IDS := ["click", "hit", "projectile", "impact", "promote", "wave", "boss", "win", "lose"]
## 루프 BGM. clear/defeated 는 종료 징글(원샷)
const BGM_LOOP_IDS := ["lobby", "shop", "stage_easy", "stage_hard"]
const BGM_STING_IDS := ["clear", "defeated"]

var _streams := {}  # id -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _last_ms := {}  # id -> 마지막 재생 시각(ms)
var _web_unlocked := false
var _bgm: AudioStreamPlayer
var _bgm_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	apply_volumes()
	_load_streams()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		_force_stream_playback(p)
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = BUS_BGM
	_force_stream_playback(_bgm)
	add_child(_bgm)
	# 모바일/웹 브라우저는 첫 제스처 전에 AudioContext 가 잠긴다
	if OS.has_feature("web"):
		set_process_input(true)
		set_process_unhandled_input(true)
		# GUI 가 입력을 먹어도 unlock 되도록 뷰포트에도 건다
		if get_viewport():
			get_viewport().gui_focus_changed.connect(func(_c): pass)
	else:
		play_bgm("lobby")


func _force_stream_playback(p: AudioStreamPlayer) -> void:
	if not OS.has_feature("web"):
		return
	# 0 Default / 1 Stream / 2 Sample — 웹 Sample 은 버스·루프에서 묵음 나는 경우가 있다
	p.playback_type = 1


func _input(event: InputEvent) -> void:
	_try_web_unlock(event)


func _unhandled_input(event: InputEvent) -> void:
	_try_web_unlock(event)


func _try_web_unlock(event: InputEvent) -> void:
	if _web_unlocked or not OS.has_feature("web"):
		return
	if not (event is InputEventMouseButton or event is InputEventScreenTouch \
			or event is InputEventKey or event is InputEventJoypadButton):
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventScreenTouch and not event.pressed:
		return
	if event is InputEventKey and not event.pressed:
		return
	if event is InputEventJoypadButton and not event.pressed:
		return
	_finish_web_unlock()


## 버튼 콜백 등 사용자 제스처 안에서 호출. 웹 오디오를 연다.
func ensure_web_unlocked() -> void:
	if OS.has_feature("web"):
		_finish_web_unlock()


func _finish_web_unlock() -> void:
	if _web_unlocked:
		return
	_web_unlocked = true
	set_process_input(false)
	set_process_unhandled_input(false)
	_resume_web_audio_context()
	# Master 버스가 잠겨 있으면 전부 묵음
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, false)
	apply_volumes()
	# 제스처 안에서 반드시 한 번 play 해야 이후 오디오가 열린다
	if _streams.has("click") and not Save.sfx_muted():
		_play_now("click", 1.0)
	play_bgm("lobby")


## HTML 쪽 별도 AudioContext 가 아니라, 페이지에 열린 컨텍스트를 전부 resume 한다
func _resume_web_audio_context() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			try {
				var resumeOne = function (ctx) {
					if (ctx && ctx.state === 'suspended' && ctx.resume) ctx.resume();
				};
				if (typeof GodotAudio !== 'undefined') {
					resumeOne(GodotAudio.ctx);
					if (GodotAudio.audioContext) resumeOne(GodotAudio.audioContext);
				}
				if (window.Godot && Godot.ctx) resumeOne(Godot.ctx);
				// 엔진이 만든 컨텍스트가 전역에 안 보이면, 새로 만들지 않고 기존만 깨운다
				if (window.__godotAudioContext) resumeOne(window.__godotAudioContext);
			} catch (e) {}
		})();
	""")


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
	for id in BGM_LOOP_IDS:
		_load_bgm(id, true)
	for id in BGM_STING_IDS:
		_load_bgm(id, false)
	# 예전 호출(play_bgm("office")) 호환
	if _streams.has("lobby"):
		_streams["office"] = _streams["lobby"]


func _load_bgm(id: String, loop: bool) -> void:
	var path := BGM_DIR + id + ".wav"
	# 새 트랙이 없거나 import 실패하면 예전 office 로 폴백
	if not ResourceLoader.exists(path):
		path = BGM_DIR + "office.wav"
		if not ResourceLoader.exists(path):
			return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	# import 원본을 직접 건드리면 웹 Sample/Stream 등록이 깨질 수 있어 복제본에 루프를 건다
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	_streams[id] = stream


## gap_ms 안이면 같은 효과음을 다시 안 낸다 (전투 스팸 방지)
func play(id: String, pitch := 1.0, gap_ms := 40) -> void:
	if Save.sfx_muted() or not _streams.has(id) or _players.is_empty():
		return
	if Save.volume_master() <= 0.001 or Save.volume_sfx() <= 0.001:
		return
	# 웹: unlock 전 play 는 브라우저가 막아 묵음. 제스처 핸들러에서만 unlock 한다.
	if OS.has_feature("web") and not _web_unlocked:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -99999)) < gap_ms:
		return
	_last_ms[id] = now
	_play_now(id, pitch)


func _play_now(id: String, pitch: float) -> void:
	if not _streams.has(id) or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = clampf(pitch, 0.7, 1.4)
	# 버스가 없으면 Master 로 떨어뜨려 묵음 방지
	if AudioServer.get_bus_index(p.bus) < 0:
		p.bus = BUS_MASTER
	p.play()


func play_bgm(id: String = "lobby") -> void:
	if id == "office":
		id = "lobby"
	if _bgm == null:
		return
	# 요청 트랙이 없으면 lobby → office 순으로 폴백
	if not _streams.has(id):
		if _streams.has("lobby"):
			id = "lobby"
		elif _streams.has("office"):
			id = "office"
		else:
			return
	if OS.has_feature("web") and not _web_unlocked:
		return
	if Save.volume_master() <= 0.001 or Save.volume_bgm() <= 0.001:
		return
	if _bgm_id == id and _bgm.playing:
		return
	_bgm_id = id
	_bgm.stream = _streams[id]
	if AudioServer.get_bus_index(_bgm.bus) < 0:
		_bgm.bus = BUS_MASTER
	_bgm.play()


## 스테이지 난이도에 맞는 전투 BGM (쉬움=stage_easy, 그 외=stage_hard)
func play_stage_bgm(stage_id: int) -> void:
	var diff := "보통"
	if StageDefs.STAGES.has(stage_id):
		diff = str(StageDefs.STAGES[stage_id].get("difficulty", "보통"))
	play_bgm("stage_easy" if diff == "쉬움" else "stage_hard")


## 종료 징글: 루프 BGM 을 끊고 한 번만 재생
func play_sting(id: String) -> void:
	if not _streams.has(id) or _bgm == null:
		return
	if OS.has_feature("web") and not _web_unlocked:
		return
	_bgm_id = id
	_bgm.stream = _streams[id]
	if AudioServer.get_bus_index(_bgm.bus) < 0:
		_bgm.bus = BUS_MASTER
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
	# Suno Clear 트랙이 있으면 징글로, 없으면 짧은 SFX
	if _streams.has("clear"):
		play_sting("clear")
	else:
		play("win", 1.0, 300)


func lose() -> void:
	if _streams.has("defeated"):
		play_sting("defeated")
	else:
		play("lose", 1.0, 300)

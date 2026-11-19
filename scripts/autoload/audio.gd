# 효과음 + BGM. 버스 볼륨은 Save 설정을 따른다.
# 웹: Sample 재생 + 제스처 unlock. 콘솔에 [Audio] 로그를 남겨 묵음 원인을 추적한다.
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
## 0 Default / 1 Stream / 2 Sample — 웹은 Sample 이 기본·권장
const PLAYBACK_SAMPLE := 2

var _streams := {}  # id -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _last_ms := {}  # id -> 마지막 재생 시각(ms)
var _web_unlocked := false
var _bgm: AudioStreamPlayer
var _bgm_id := ""
var _pending_bgm := "lobby"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	apply_volumes()
	_load_streams()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		_configure_player(p)
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = BUS_BGM
	_configure_player(_bgm)
	add_child(_bgm)
	_alog("ready web=%s streams=%s master=%.2f bgm=%.2f sfx=%.2f muted_sfx=%s bus_bgm=%d" % [
		OS.has_feature("web"),
		str(_streams.keys()),
		Save.volume_master(), Save.volume_bgm(), Save.volume_sfx(),
		Save.sfx_muted(),
		AudioServer.get_bus_index(BUS_BGM),
	])
	if OS.has_feature("web"):
		set_process_input(true)
		set_process_unhandled_input(true)
	else:
		play_bgm("lobby")


func _alog(msg: String) -> void:
	var line := "[Audio] %s" % msg
	print(line)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log(%s)" % JSON.stringify(line))


func _configure_player(p: AudioStreamPlayer) -> void:
	if not OS.has_feature("web"):
		return
	# Stream(1) 은 싱글스레드 웹에서 묵음·끊김이 잦아서 Sample 강제
	p.playback_type = PLAYBACK_SAMPLE


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
	_alog("gesture unlock type=%s" % event.get_class())
	_finish_web_unlock()


## 버튼 콜백 등 사용자 제스처 안에서 호출. 웹 오디오를 연다.
func ensure_web_unlocked() -> void:
	if OS.has_feature("web"):
		_alog("ensure_web_unlocked unlocked=%s" % _web_unlocked)
		_finish_web_unlock()


func _finish_web_unlock() -> void:
	if _web_unlocked:
		return
	_web_unlocked = true
	set_process_input(false)
	set_process_unhandled_input(false)
	var ctx := _resume_web_audio_context()
	_alog("unlock ctx=%s" % ctx)
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, false)
	apply_volumes()
	# 제스처 안에서 반드시 한 번 play 해야 이후 오디오가 열린다
	if _streams.has("click") and not Save.sfx_muted():
		_play_now("click", 1.0)
		_alog("unlock click played")
	else:
		_alog("unlock click skipped has=%s muted=%s" % [_streams.has("click"), Save.sfx_muted()])
	play_bgm(_pending_bgm if _pending_bgm != "" else "lobby")
	# Sample/컨텍스트가 한 프레임 늦게 붙는 경우 대비
	call_deferred("_verify_bgm_after_unlock")


func _verify_bgm_after_unlock() -> void:
	await get_tree().create_timer(0.15).timeout
	var playing := _bgm != null and _bgm.playing
	_alog("post-unlock bgm_id=%s playing=%s pos=%.2f stream=%s" % [
		_bgm_id, playing,
		_bgm.get_playback_position() if _bgm else -1.0,
		str(_bgm.stream) if _bgm else "null",
	])
	if not playing and _pending_bgm != "":
		_alog("retry play_bgm(%s)" % _pending_bgm)
		_bgm_id = ""
		play_bgm(_pending_bgm)


## HTML 쪽 컨텍스트 resume + 상태 문자열 반환
func _resume_web_audio_context() -> String:
	if not OS.has_feature("web"):
		return "n/a"
	var state: Variant = JavaScriptBridge.eval("""
		(function () {
			try {
				var resumeOne = function (ctx) {
					if (ctx && ctx.state === 'suspended' && ctx.resume) ctx.resume();
					return ctx ? String(ctx.state) : '';
				};
				var states = [];
				if (typeof GodotAudio !== 'undefined') {
					states.push('GodotAudio.ctx=' + resumeOne(GodotAudio.ctx));
					if (GodotAudio.audioContext) states.push('GodotAudio.audioContext=' + resumeOne(GodotAudio.audioContext));
				} else {
					states.push('GodotAudio=undefined');
				}
				if (window.Godot && Godot.ctx) states.push('Godot.ctx=' + resumeOne(Godot.ctx));
				if (window.__godotAudioContext) states.push('__godot=' + resumeOne(window.__godotAudioContext));
				return states.join('; ');
			} catch (e) {
				return 'error:' + String(e);
			}
		})();
	""")
	return str(state)


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
		_alog("bus missing: %s" % bus)
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func _load_streams() -> void:
	for id in SFX_IDS:
		var path: String = SFX_DIR + id + ".wav"
		if not ResourceLoader.exists(path):
			_alog("sfx missing: %s" % path)
			continue
		var stream: AudioStream = load(path)
		if stream == null:
			_alog("sfx load null: %s" % path)
			continue
		_register_sample(stream, id)
		_streams[id] = stream
	for id in BGM_LOOP_IDS:
		_load_bgm(id, true)
	for id in BGM_STING_IDS:
		_load_bgm(id, false)
	if _streams.has("lobby"):
		_streams["office"] = _streams["lobby"]
	_alog("loaded sfx/bgm count=%d keys=%s" % [_streams.size(), str(_streams.keys())])


func _register_sample(stream: AudioStream, id: String) -> void:
	if not OS.has_feature("web") or stream == null:
		return
	if AudioServer.has_method("register_stream_as_sample"):
		AudioServer.register_stream_as_sample(stream)
		_alog("registered sample: %s" % id)
	else:
		_alog("register_stream_as_sample missing for %s" % id)


func _load_bgm(id: String, loop: bool) -> void:
	var path := BGM_DIR + id + ".wav"
	var used_fallback := false
	if not ResourceLoader.exists(path):
		_alog("bgm missing: %s → office" % path)
		path = BGM_DIR + "office.wav"
		used_fallback = true
		if not ResourceLoader.exists(path):
			_alog("bgm office also missing")
			return
	var stream: AudioStream = load(path)
	if stream == null:
		_alog("bgm load null: %s" % path)
		return
	# import 원본을 직접 건드리면 웹 Sample 등록이 깨질 수 있어 복제본에 루프를 건다
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		_alog("bgm %s wav mix=%s rate=%s frames=%s loop=%s fallback=%s" % [
			id,
			(stream as AudioStreamWAV).mix_rate,
			(stream as AudioStreamWAV).format,
			(stream as AudioStreamWAV).data.size(),
			loop,
			used_fallback,
		])
	else:
		_alog("bgm %s type=%s fallback=%s" % [id, stream.get_class(), used_fallback])
	_register_sample(stream, id)
	_streams[id] = stream


## gap_ms 안이면 같은 효과음을 다시 안 낸다 (전투 스팸 방지)
func play(id: String, pitch := 1.0, gap_ms := 40) -> void:
	if Save.sfx_muted() or not _streams.has(id) or _players.is_empty():
		return
	if Save.volume_master() <= 0.001 or Save.volume_sfx() <= 0.001:
		return
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
	if AudioServer.get_bus_index(p.bus) < 0:
		p.bus = BUS_MASTER
	p.play()


func play_bgm(id: String = "lobby") -> void:
	if id == "office":
		id = "lobby"
	_pending_bgm = id
	if _bgm == null:
		_alog("play_bgm(%s) aborted: no player" % id)
		return
	if not _streams.has(id):
		if _streams.has("lobby"):
			_alog("play_bgm(%s) missing → lobby" % id)
			id = "lobby"
		elif _streams.has("office"):
			_alog("play_bgm(%s) missing → office" % id)
			id = "office"
		else:
			_alog("play_bgm(%s) aborted: no stream" % id)
			return
	if OS.has_feature("web") and not _web_unlocked:
		_alog("play_bgm(%s) deferred until unlock" % id)
		return
	if Save.volume_master() <= 0.001 or Save.volume_bgm() <= 0.001:
		_alog("play_bgm(%s) aborted: volume master=%.2f bgm=%.2f" % [
			id, Save.volume_master(), Save.volume_bgm()])
		return
	if _bgm_id == id and _bgm.playing:
		_alog("play_bgm(%s) already playing" % id)
		return
	_bgm_id = id
	_bgm.stream = _streams[id]
	# 웹 Sample 이 커스텀 버스에서 묵음이면 Master 로 떨어뜨린다
	if AudioServer.get_bus_index(_bgm.bus) < 0:
		_bgm.bus = BUS_MASTER
	_bgm.play()
	_alog("play_bgm(%s) start bus=%s playing=%s playback_type=%s" % [
		id, _bgm.bus, _bgm.playing, _bgm.playback_type if OS.has_feature("web") else -1])
	# Sample+커스텀 버스 묵음이면 Master 재시도
	if OS.has_feature("web"):
		call_deferred("_ensure_bgm_audible")


func _ensure_bgm_audible() -> void:
	await get_tree().create_timer(0.05).timeout
	if _bgm == null or _bgm_id == "" or not _streams.has(_bgm_id):
		return
	if _bgm.playing and _bgm.get_playback_position() > 0.0:
		return
	# playing 이어도 position 0 고정이면 묵음일 수 있음 → Master 재시도
	_alog("bgm not advancing on bus=%s → retry Master" % _bgm.bus)
	_bgm.stop()
	_bgm.bus = BUS_MASTER
	_bgm.stream = _streams[_bgm_id]
	_bgm.play()
	_alog("bgm Master retry playing=%s pos=%.2f" % [_bgm.playing, _bgm.get_playback_position()])


## 스테이지 난이도에 맞는 전투 BGM (쉬움=stage_easy, 그 외=stage_hard)
func play_stage_bgm(stage_id: int) -> void:
	var diff := "보통"
	if StageDefs.STAGES.has(stage_id):
		diff = str(StageDefs.STAGES[stage_id].get("difficulty", "보통"))
	play_bgm("stage_easy" if diff == "쉬움" else "stage_hard")


## 종료 징글: 루프 BGM 을 끊고 한 번만 재생
func play_sting(id: String) -> void:
	if not _streams.has(id) or _bgm == null:
		_alog("play_sting(%s) aborted has=%s" % [id, _streams.has(id)])
		return
	if OS.has_feature("web") and not _web_unlocked:
		_alog("play_sting(%s) deferred until unlock" % id)
		return
	_pending_bgm = ""
	_bgm_id = id
	_bgm.stream = _streams[id]
	if AudioServer.get_bus_index(_bgm.bus) < 0:
		_bgm.bus = BUS_MASTER
	_bgm.play()
	_alog("play_sting(%s) playing=%s" % [id, _bgm.playing])


func stop_bgm() -> void:
	_bgm_id = ""
	_pending_bgm = ""
	if _bgm:
		_bgm.stop()
	_alog("stop_bgm")


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
	if _streams.has("clear"):
		play_sting("clear")
	else:
		play("win", 1.0, 300)


func lose() -> void:
	if _streams.has("defeated"):
		play_sting("defeated")
	else:
		play("lose", 1.0, 300)

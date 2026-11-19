# 효과음 + BGM. 버스 볼륨은 Save 설정을 따른다.
# 웹: SFX=Sample, BGM=Stream(워크렛→destination). 제스처로 AudioContext resume.
# 클릭마다 BGM 을 다시 켜지 않는다. 콘솔 [Audio] 로그로 추적.
extends Node

const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const POOL := 10
const SFX_DIR := "res://assets/sfx/"
const BGM_DIR := "res://assets/bgm/"
const SFX_IDS := ["click", "hit", "projectile", "impact", "promote", "wave", "boss", "win", "lose"]
const BGM_LOOP_IDS := ["lobby", "shop", "stage_easy", "stage_hard"]
const BGM_STING_IDS := ["clear", "defeated"]
## 0 Default / 1 Stream / 2 Sample
const PLAYBACK_STREAM := 1
const PLAYBACK_SAMPLE := 2

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _last_ms := {}
var _web_unlocked := false
var _bgm: AudioStreamPlayer
var _bgm_id := ""
var _pending_bgm := "lobby"
var _unlock_tries := 0
var _probed_dest := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	apply_volumes()
	_load_streams()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		if OS.has_feature("web"):
			p.playback_type = PLAYBACK_SAMPLE
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = BUS_BGM
	if OS.has_feature("web"):
		# Sample 버스가 destination 에서 끊겨도 Stream 워크렛은 스피커에 남는다
		_bgm.playback_type = PLAYBACK_STREAM
		_bgm.bus = BUS_MASTER
	add_child(_bgm)
	_alog("ready web=%s count=%d master=%.2f bgm=%.2f muted_sfx=%s bgm_bus=%s bgm_type=%s" % [
		OS.has_feature("web"), _streams.size(),
		Save.volume_master(), Save.volume_bgm(), Save.sfx_muted(), _bgm.bus,
		_bgm.playback_type if OS.has_feature("web") else -1,
	])
	if OS.has_feature("web"):
		_publish_ctx_to_window()
		set_process(true)
		set_process_input(true)
		set_process_unhandled_input(true)
	else:
		play_bgm("lobby")


func _process(_dt: float) -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_publish_ctx_to_window()
	if _web_unlocked:
		set_process(false)


func _alog(msg: String) -> void:
	var line := "[Audio] %s" % msg
	print(line)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log(%s)" % JSON.stringify(line))


func _input(event: InputEvent) -> void:
	_try_web_unlock(event)


func _unhandled_input(event: InputEvent) -> void:
	_try_web_unlock(event)


func _try_web_unlock(event: InputEvent) -> void:
	if not OS.has_feature("web") or _web_unlocked:
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
	_unlock_tries += 1
	_alog("gesture try=%d type=%s" % [_unlock_tries, event.get_class()])
	_finish_web_unlock()


## 버튼 콜백용. 이미 unlock 됐으면 BGM 을 건드리지 않는다.
func ensure_web_unlocked() -> void:
	if not OS.has_feature("web"):
		return
	if _web_unlocked:
		_resume_web_audio_context()
		return
	_alog("ensure_web_unlocked try unlock")
	_finish_web_unlock()


func _finish_web_unlock() -> void:
	if _web_unlocked:
		return
	_publish_ctx_to_window()
	var ctx := _resume_web_audio_context()
	_alog("unlock ctx=%s" % ctx)
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, false)
	apply_volumes()
	if _streams.has("click") and not Save.sfx_muted():
		_play_now("click", 1.0)
	play_bgm(_pending_bgm if _pending_bgm != "" else "lobby", true)
	_probe_destination_once()
	call_deferred("_after_unlock_tick")


func _after_unlock_tick() -> void:
	await get_tree().create_timer(0.35).timeout
	var ctx := _ctx_state()
	var pos := _bgm.get_playback_position() if _bgm else -1.0
	var playing := _bgm != null and _bgm.playing
	_alog("post-unlock ctx=%s id=%s playing=%s pos=%.3f vol_db=%.1f" % [
		ctx, _bgm_id, playing, pos, _bgm.volume_db if _bgm else 0.0,
	])
	# ctx running 이면 unlock 성공으로 본다. pos 는 Stream 에서 늦게 오를 수 있음
	if ctx.find("running") >= 0:
		_mark_unlocked()
		# 아직 안 나가면 한 번 더 재생 (재시작은 unlock 직후 1회만)
		if _bgm and (not _bgm.playing or pos < 0.01):
			_alog("post-unlock restart bgm once")
			var id := _pending_bgm if _pending_bgm != "" else "lobby"
			_bgm_id = ""
			play_bgm(id, true)
	else:
		_alog("ctx not running — wait next gesture")


func _mark_unlocked() -> void:
	if _web_unlocked:
		return
	_web_unlocked = true
	set_process_input(false)
	set_process_unhandled_input(false)
	_alog("fully unlocked")


## destination 에 GainNode 가 붙어 있는지 한 번만 찍는다 (Sample 버스 단선 진단)
func _probe_destination_once() -> void:
	if _probed_dest or not OS.has_feature("web"):
		return
	_probed_dest = true
	var r: Variant = JavaScriptBridge.eval("""
		(function () {
			try {
				var ctx = window.__godotAudioContext
					|| (window.GodotAudio && window.GodotAudio.ctx) || null;
				if (!ctx) return 'no-ctx';
				var dest = ctx.destination;
				var n = dest.numberOfInputs;
				return 'state=' + ctx.state + ' destInputs=' + n + ' sampleRate=' + ctx.sampleRate;
			} catch (e) { return 'err:' + String(e); }
		})();
	""")
	_alog("dest probe: %s" % str(r))


func _publish_ctx_to_window() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			try {
				if (typeof GodotAudio !== 'undefined' && GodotAudio.ctx) {
					window.__godotAudioContext = GodotAudio.ctx;
					window.GodotAudio = GodotAudio;
				}
			} catch (e) {}
		})();
	""")


func _ctx_state() -> String:
	if not OS.has_feature("web"):
		return "n/a"
	var state: Variant = JavaScriptBridge.eval("""
		(function () {
			try {
				var ctx = (typeof GodotAudio !== 'undefined' && GodotAudio.ctx)
					|| window.__godotAudioContext || null;
				return ctx ? String(ctx.state) : 'no-ctx';
			} catch (e) { return 'error'; }
		})();
	""")
	return str(state)


func _resume_web_audio_context() -> String:
	if not OS.has_feature("web"):
		return "n/a"
	var state: Variant = JavaScriptBridge.eval("""
		(function () {
			try {
				var ctx = (typeof GodotAudio !== 'undefined' && GodotAudio.ctx)
					|| window.__godotAudioContext || null;
				if (!ctx) return 'no-ctx';
				window.__godotAudioContext = ctx;
				if (typeof GodotAudio !== 'undefined') window.GodotAudio = GodotAudio;
				if (ctx.state === 'suspended' && ctx.resume) {
					ctx.resume().then(function () {
						console.log('[Audio/html] resume ok', ctx.state);
					}).catch(function (e) {
						console.warn('[Audio/html] resume fail', e);
					});
				}
				try {
					var buf = ctx.createBuffer(1, 1, 22050);
					var src = ctx.createBufferSource();
					src.buffer = buf;
					src.connect(ctx.destination);
					src.start(0);
				} catch (e2) {}
				return String(ctx.state);
			} catch (e) {
				return 'error:' + String(e);
			}
		})();
	""")
	return str(state)


func _ensure_buses() -> void:
	_ensure_bus(BUS_BGM)
	_ensure_bus(BUS_SFX)


## 웹 add_bus() 는 JS 버스 목록을 꼬아 Master 가 destination 에서 빠질 수 있음 (godot#119026).
func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.bus_count = idx + 1
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, BUS_MASTER)
	_alog("created bus %s at %d" % [name, idx])


func apply_volumes() -> void:
	_set_bus_linear(BUS_MASTER, Save.volume_master())
	_set_bus_linear(BUS_BGM, Save.volume_bgm())
	_set_bus_linear(BUS_SFX, 0.0 if Save.sfx_muted() else Save.volume_sfx())
	if _bgm and OS.has_feature("web"):
		# Stream+Master 직행: BGM 슬라이더를 플레이어 gain 에 반영
		_bgm.volume_db = linear_to_db(maxf(Save.volume_bgm() * Save.volume_master(), 0.0001))


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
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path)
		if stream == null:
			continue
		_register_sample(stream, id)
		_streams[id] = stream
	for id in BGM_LOOP_IDS:
		_load_bgm(id, true)
	for id in BGM_STING_IDS:
		_load_bgm(id, false)
	if _streams.has("lobby"):
		_streams["office"] = _streams["lobby"]
	_alog("loaded count=%d" % _streams.size())


func _register_sample(stream: AudioStream, id: String) -> void:
	if not OS.has_feature("web") or stream == null:
		return
	# BGM 은 Stream 재생이라 샘플 등록 불필요. SFX 만.
	if id in BGM_LOOP_IDS or id in BGM_STING_IDS or id == "office":
		return
	if AudioServer.has_method("register_stream_as_sample"):
		AudioServer.register_stream_as_sample(stream)
		_alog("registered sample: %s" % id)


func _load_bgm(id: String, loop: bool) -> void:
	var path := BGM_DIR + id + ".wav"
	var used_fallback := false
	if not ResourceLoader.exists(path):
		path = BGM_DIR + "office.wav"
		used_fallback = true
		if not ResourceLoader.exists(path):
			return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		_alog("bgm %s format=%s mix=%s bytes=%s loop=%s fallback=%s" % [
			id, (stream as AudioStreamWAV).format, (stream as AudioStreamWAV).mix_rate,
			(stream as AudioStreamWAV).data.size(), loop, used_fallback,
		])
	_streams[id] = stream


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


## force=true: 웹 unlock 직후 첫 재생. 같은 곡이 이미 재생 중이면 건드리지 않는다.
func play_bgm(id: String = "lobby", force := false) -> void:
	if id == "office":
		id = "lobby"
	_pending_bgm = id
	if _bgm == null:
		return
	if not _streams.has(id):
		if _streams.has("lobby"):
			id = "lobby"
		elif _streams.has("office"):
			id = "office"
		else:
			_alog("play_bgm(%s) no stream" % id)
			return
	if OS.has_feature("web") and not force and not _web_unlocked:
		_alog("play_bgm(%s) deferred" % id)
		return
	if Save.volume_master() <= 0.001 or Save.volume_bgm() <= 0.001:
		_alog("play_bgm(%s) volume blocked" % id)
		return
	# 같은 곡이 이미 재생 중이면 재시작하지 않음 (버튼 연타로 끊기는 거 방지)
	if _bgm_id == id and _bgm.playing:
		return
	_bgm_id = id
	_bgm.stream = _streams[id]
	if OS.has_feature("web"):
		_bgm.playback_type = PLAYBACK_STREAM
		_bgm.bus = BUS_MASTER
		_bgm.volume_db = linear_to_db(maxf(Save.volume_bgm() * Save.volume_master(), 0.0001))
	elif AudioServer.get_bus_index(_bgm.bus) < 0:
		_bgm.bus = BUS_MASTER
	_bgm.play()
	_alog("play_bgm(%s) force=%s bus=%s type=%s vol=%.1f playing=%s" % [
		id, force, _bgm.bus,
		_bgm.playback_type if OS.has_feature("web") else -1,
		_bgm.volume_db, _bgm.playing,
	])


func play_stage_bgm(stage_id: int) -> void:
	var diff := "보통"
	if StageDefs.STAGES.has(stage_id):
		diff = str(StageDefs.STAGES[stage_id].get("difficulty", "보통"))
	play_bgm("stage_easy" if diff == "쉬움" else "stage_hard")


func play_sting(id: String) -> void:
	if not _streams.has(id) or _bgm == null:
		return
	if OS.has_feature("web") and not _web_unlocked:
		return
	_pending_bgm = ""
	_bgm_id = id
	_bgm.stream = _streams[id]
	if OS.has_feature("web"):
		_bgm.playback_type = PLAYBACK_STREAM
		_bgm.bus = BUS_MASTER
	_bgm.play()
	_alog("play_sting(%s)" % id)


func stop_bgm() -> void:
	_bgm_id = ""
	_pending_bgm = ""
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
	if _streams.has("clear"):
		play_sting("clear")
	else:
		play("win", 1.0, 300)


func lose() -> void:
	if _streams.has("defeated"):
		play_sting("defeated")
	else:
		play("lose", 1.0, 300)

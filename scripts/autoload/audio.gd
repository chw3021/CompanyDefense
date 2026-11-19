# 효과음 + BGM. 버스 볼륨은 Save 설정을 따른다.
# 웹 BGM: Godot Stream/Sample 이 싱글스레드에서 묵음이라 HTML5 Audio(bgm/*.wav)로 재생.
# 웹 SFX: Godot Sample. 콘솔 [Audio] 로그로 추적.
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
const PLAYBACK_SAMPLE := 2

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _last_ms := {}
var _web_unlocked := false
var _bgm: AudioStreamPlayer  # 네이티브(데스크톱/안드로이드) 전용
var _bgm_id := ""
var _pending_bgm := "lobby"
var _unlock_tries := 0


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
	if not OS.has_feature("web"):
		_bgm = AudioStreamPlayer.new()
		_bgm.bus = BUS_BGM
		add_child(_bgm)
	_alog("ready web=%s sfx=%d master=%.2f bgm=%.2f muted_sfx=%s html5_bgm=%s" % [
		OS.has_feature("web"), _streams.size(),
		Save.volume_master(), Save.volume_bgm(), Save.sfx_muted(),
		OS.has_feature("web"),
	])
	if OS.has_feature("web"):
		_publish_ctx_to_window()
		_html_bgm_preload()
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


func ensure_web_unlocked() -> void:
	if not OS.has_feature("web"):
		return
	if _web_unlocked:
		_resume_web_audio_context()
		return
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
	# HTML5 Audio 는 제스처 안에서 play() 해야 함
	play_bgm(_pending_bgm if _pending_bgm != "" else "lobby", true)
	_web_unlocked = true
	set_process_input(false)
	set_process_unhandled_input(false)
	_alog("fully unlocked (html5 bgm)")


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
				if (ctx.state === 'suspended' && ctx.resume) ctx.resume();
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


func _html_bgm_preload() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			window.__cdBgm = window.__cdBgm || {};
			window.__cdBgmId = window.__cdBgmId || '';
			['lobby','shop','stage_easy','stage_hard','clear','defeated'].forEach(function (id) {
				if (window.__cdBgm[id]) return;
				var a = new Audio('bgm/' + id + '.wav');
				a.preload = 'auto';
				a.loop = (id !== 'clear' && id !== 'defeated');
				window.__cdBgm[id] = a;
			});
			console.log('[Audio/html] preload bgm elements');
		})();
	""")


func _html_bgm_play(id: String, loop: bool) -> void:
	if not OS.has_feature("web"):
		return
	var vol := clampf(Save.volume_bgm() * Save.volume_master(), 0.0, 1.0)
	var js := """
		(function () {
			try {
				window.__cdBgm = window.__cdBgm || {};
				var id = %s;
				var vol = %s;
				var loop = %s;
				Object.keys(window.__cdBgm).forEach(function (k) {
					var el = window.__cdBgm[k];
					if (!el) return;
					if (k === id) return;
					el.pause();
					try { el.currentTime = 0; } catch (e) {}
				});
				var a = window.__cdBgm[id];
				if (!a) {
					a = new Audio('bgm/' + id + '.wav');
					a.preload = 'auto';
					window.__cdBgm[id] = a;
				}
				a.loop = !!loop;
				a.volume = Math.max(0, Math.min(1, vol));
				var p = a.play();
				if (p && p.then) {
					p.then(function () {
						console.log('[Audio/html] playing', id, 'vol=' + a.volume, 't=' + a.currentTime);
					}).catch(function (e) {
						console.warn('[Audio/html] play fail', id, String(e));
					});
				} else {
					console.log('[Audio/html] play sync', id, 'paused=' + a.paused);
				}
				window.__cdBgmId = id;
			} catch (e) {
				console.warn('[Audio/html] play error', e);
			}
		})();
	""" % [JSON.stringify(id), JSON.stringify(vol), "true" if loop else "false"]
	JavaScriptBridge.eval(js)
	_alog("html5 play_bgm(%s) vol=%.2f loop=%s" % [id, vol, loop])


func _html_bgm_stop() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			var m = window.__cdBgm || {};
			Object.keys(m).forEach(function (k) {
				if (!m[k]) return;
				m[k].pause();
				try { m[k].currentTime = 0; } catch (e) {}
			});
			window.__cdBgmId = '';
		})();
	""")


func _html_bgm_set_volume() -> void:
	if not OS.has_feature("web"):
		return
	var vol := clampf(Save.volume_bgm() * Save.volume_master(), 0.0, 1.0)
	JavaScriptBridge.eval("""
		(function () {
			var vol = %s;
			var m = window.__cdBgm || {};
			Object.keys(m).forEach(function (k) {
				if (m[k]) m[k].volume = Math.max(0, Math.min(1, vol));
			});
		})();
	""" % JSON.stringify(vol))


func _ensure_buses() -> void:
	_ensure_bus(BUS_BGM)
	_ensure_bus(BUS_SFX)


func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.bus_count = idx + 1
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, BUS_MASTER)


func apply_volumes() -> void:
	_set_bus_linear(BUS_MASTER, Save.volume_master())
	_set_bus_linear(BUS_BGM, Save.volume_bgm())
	_set_bus_linear(BUS_SFX, 0.0 if Save.sfx_muted() else Save.volume_sfx())
	if OS.has_feature("web"):
		_html_bgm_set_volume()


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
		if OS.has_feature("web") and AudioServer.has_method("register_stream_as_sample"):
			AudioServer.register_stream_as_sample(stream)
			_alog("registered sample: %s" % id)
		_streams[id] = stream
	# 네이티브만 Godot 쪽으로 BGM 로드. 웹은 HTML5.
	if not OS.has_feature("web"):
		for id in BGM_LOOP_IDS:
			_load_bgm_native(id, true)
		for id in BGM_STING_IDS:
			_load_bgm_native(id, false)
		if _streams.has("lobby"):
			_streams["office"] = _streams["lobby"]
	_alog("loaded sfx/native-bgm count=%d" % _streams.size())


func _load_bgm_native(id: String, loop: bool) -> void:
	var path := BGM_DIR + id + ".wav"
	if not ResourceLoader.exists(path):
		path = BGM_DIR + "office.wav"
		if not ResourceLoader.exists(path):
			return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
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


func play_bgm(id: String = "lobby", force := false) -> void:
	if id == "office":
		id = "lobby"
	_pending_bgm = id
	if OS.has_feature("web"):
		if not force and not _web_unlocked:
			_alog("play_bgm(%s) deferred (html5)" % id)
			return
		if Save.volume_master() <= 0.001 or Save.volume_bgm() <= 0.001:
			_alog("play_bgm(%s) volume blocked" % id)
			_html_bgm_stop()
			return
		if not force and _bgm_id == id:
			return
		_bgm_id = id
		_html_bgm_play(id, id in BGM_LOOP_IDS)
		return
	# 네이티브
	if _bgm == null or not _streams.has(id):
		if _streams.has("lobby"):
			id = "lobby"
		else:
			return
	if Save.volume_master() <= 0.001 or Save.volume_bgm() <= 0.001:
		return
	if _bgm_id == id and _bgm.playing:
		return
	_bgm_id = id
	_bgm.stream = _streams[id]
	_bgm.play()


func play_stage_bgm(stage_id: int) -> void:
	var diff := "보통"
	if StageDefs.STAGES.has(stage_id):
		diff = str(StageDefs.STAGES[stage_id].get("difficulty", "보통"))
	play_bgm("stage_easy" if diff == "쉬움" else "stage_hard")


func play_sting(id: String) -> void:
	_pending_bgm = ""
	if OS.has_feature("web"):
		if not _web_unlocked:
			return
		_bgm_id = id
		_html_bgm_play(id, false)
		return
	if not _streams.has(id) or _bgm == null:
		return
	_bgm_id = id
	_bgm.stream = _streams[id]
	_bgm.play()


func stop_bgm() -> void:
	_bgm_id = ""
	_pending_bgm = ""
	if OS.has_feature("web"):
		_html_bgm_stop()
	elif _bgm:
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
	if OS.has_feature("web") or _streams.has("clear"):
		play_sting("clear")
	else:
		play("win", 1.0, 300)


func lose() -> void:
	if OS.has_feature("web") or _streams.has("defeated"):
		play_sting("defeated")
	else:
		play("lose", 1.0, 300)

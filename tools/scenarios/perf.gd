# 렉 확인용: 무한 야근 맵의 책상을 3~5성 직원으로 채우고 적 120마리를 계속 보충하며 프레임당 처리 시간을 잰다.
# godot --path . --resolution 720x1280 -- --dev-script=res://tools/scenarios/perf.gd --dev-out=<dir>
extends Node

const ENEMY_COUNT := 120
const MEASURE_SEC := 8.0

var dev
var battle: Battle
var _measuring := false
var _samples: Array[float] = []
var _projectiles := 0
var _battle_ms := 0.0
var _draw_ms := 0.0
var _fx_ms := 0.0
var _labels := 0
var _parts := [0.0, 0.0, 0.0, 0.0, 0.0]  # 직원, 적, 직원 표시, 적 표시, 연출
var _render_cpu := 0.0
var _render_gpu := 0.0
var _view: BattleView
var _bench := false


## 그리기 도우미 하나를 1000번씩 불러 걸린 시간을 찍는다 (그리기 콜백 안에서만 부를 수 있다)
func _microbench(view: BattleView) -> void:
	var t: Tower = battle.towers[0]
	var at := t.center()
	var cases := {
		"draw_tower": func(): view._draw_tower(t),
		"tower_hud": func(): view._draw_tower_hud(t),
		"enemy_hud": func(): view._draw_enemy_hud(battle.enemies[0]),
		"ellipse": func(): view._ellipse(at, 20.0, 0.38, Color.RED),
		"ellipse_ring": func(): view._ellipse_ring(at, 25.0, Color.RED, 3.0),
		"rounded": func(): view._rounded(Rect2(at, Vector2(40, 20)), Color.RED, 10),
		"box_only": func(): view._box(Color.RED, 10),
		"star": func(): view._star(at, 5.0, Color.RED),
		"tex": func(): view.tex(GameData.asset(t.data.towerSpritePath)),
		"tower_color": func(): GameData.tower_color(t.data),
		"texture_rect": func(): view.ci.draw_texture_rect(view._bg, Rect2(at, Vector2(50, 50)), false),
		"text": func(): view._text(at, "123", 20),
		"empty": func(): pass,
		"circle_engine": func(): view.ci.draw_circle(at, 20.0, Color.RED),
	}
	for name in cases:
		var fn: Callable = cases[name]
		var t0 := Time.get_ticks_usec()
		for i in 1000:
			fn.call()
		dev.say("bench %s: %.1f us" % [name, (Time.get_ticks_usec() - t0) / 1000.0])


func run(p_dev) -> void:
	dev = p_dev
	seed(1)
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 3
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 4)
	await dev.wait(2.6)
	battle = get_tree().current_scene.battle
	battle.max_enemies = 100000
	var ids := GameData.tower_ids.filter(func(id):
		var g := int(GameData.towers[id].towerGrade)
		return g >= 3 and g <= 5 and not GameData.is_special(GameData.towers[id]))
	for c in battle.desk_cells:
		battle._place(ids.pick_random(), c).spawn_anim = 0.0
	battle.start_wave()
	battle.set_speed(2.0)
	# 전투 계산 시간을 따로 재기 위해 이 노드가 직접 돌린다
	battle.set_process(false)
	# 맵 그리기 시간도 따로 잰다
	var view: BattleView = get_tree().current_scene.view
	_view = view
	view.set_process(false)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	view._dyn.draw.disconnect(view._draw_dynamic)
	view._dyn.draw.connect(func():
		var t0 := Time.get_ticks_usec()
		view.ci = view._dyn
		if _bench:
			_bench = false
			_microbench(view)
		view._draw_flow()
		var marks := [Time.get_ticks_usec()]
		for t: Tower in battle.towers:
			view._draw_tower(t)
		marks.append(Time.get_ticks_usec())
		for e: Enemy in battle.enemies:
			view._draw_enemy(e)
		marks.append(Time.get_ticks_usec())
		for t: Tower in battle.towers:
			view._draw_tower_hud(t)
		marks.append(Time.get_ticks_usec())
		for e: Enemy in battle.enemies:
			view._draw_enemy_hud(e)
		marks.append(Time.get_ticks_usec())
		for p in battle.projectiles:
			view._draw_projectile(p)
		for fx in battle.effects:
			view._draw_effect(fx)
		view._draw_fx()
		marks.append(Time.get_ticks_usec())
		if _measuring:
			_draw_ms += (Time.get_ticks_usec() - t0) / 1000.0
			for i in 5:
				_parts[i] += (marks[i + 1] - marks[i]) / 1000.0)
	await dev.wait(3.0)
	_bench = true
	await dev.wait(0.5)
	_measuring = true
	await dev.wait(MEASURE_SEC)
	_measuring = false
	await dev.shot("perf")
	_samples.sort()
	var total := 0.0
	for s in _samples:
		total += s
	dev.say("fps=%.1f" % (_samples.size() / MEASURE_SEC))
	dev.say("towers=%d frames=%d avg=%.2fms p95=%.2fms max=%.2fms battle_avg=%.2fms draw_avg=%.2fms fx_avg=%.2fms avg_labels=%.0f render_cpu=%.2fms render_gpu=%.2fms avg_projectiles=%.0f kills=%d" % [
			battle.towers.size(), _samples.size(), total / _samples.size(),
			_samples[int(_samples.size() * 0.95)], _samples[-1], _battle_ms / _samples.size(), _draw_ms / _samples.size(),
			_fx_ms / _samples.size(), float(_labels) / _samples.size(),
			_render_cpu / _samples.size(), _render_gpu / _samples.size(), float(_projectiles) / _samples.size(), battle.kills])
	dev.say("draw parts: towers=%.2f enemies=%.2f tower_hud=%.2f enemy_hud=%.2f fx=%.2f (ms)" % [
			_parts[0] / _samples.size(), _parts[1] / _samples.size(), _parts[2] / _samples.size(),
			_parts[3] / _samples.size(), _parts[4] / _samples.size()])
	dev.finish()


func _process(delta: float) -> void:
	if battle == null or battle.finished:
		return
	# 적이 줄면 입구에 다시 채워 계속 싸우게 한다
	while battle.enemies.size() < ENEMY_COUNT:
		var e := Enemy.new(["printer", "fax", "copier", "server"].pick_random(), 3000.0, battle)
		battle.enemies.append(e)
	if not battle.is_processing():
		var t0 := Time.get_ticks_usec()
		battle._process(delta)
		var t1 := Time.get_ticks_usec()
		_view._process(delta)
		if _measuring:
			_battle_ms += (t1 - t0) / 1000.0
			_fx_ms += (Time.get_ticks_usec() - t1) / 1000.0
			_labels += get_tree().current_scene._float_layer.get_child_count()
			var vp := get_viewport().get_viewport_rid()
			_render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			_render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	if _measuring:
		_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_projectiles += battle.projectiles.size()

# 한 판의 전투 상태와 규칙. 그리기와 UI 는 BattleView / StageScreen 이 맡는다.
class_name Battle
extends Node

signal hud_changed
signal message(text: String, color: Color)
signal floating(text: String, at: Vector2, color: Color)
signal tower_selected(tower: Tower)
signal wave_started(index: int)
signal game_over(won: bool, summary: Dictionary)
# 연출용 신호 (BattleView 가 받는다. 시뮬레이션에서는 아무도 듣지 않는다)
signal enemy_spawned(e: Enemy)
signal enemy_damaged(e: Enemy, amount: float, magic_share: float)
signal enemy_died(e: Enemy)
signal enemy_escaped(e: Enemy)
signal enemy_ability(e: Enemy)  # 정수기 회복, 전화벨
signal enemy_split(parent: Enemy, children: Array)
signal tower_placed(t: Tower, promoted: bool)
signal tower_attacked(t: Tower, target: Enemy, melee: bool)
signal skill_cast(t: Tower)
signal projectile_hit(p: Dictionary)

const SPAWN_COST := 100
const TRADE_CHANCE := 0.3
const MAX_LIFE := 8
const DT_CLAMP := 0.1

var stage_id: int
var def: Dictionary
var cell := 72.0
var map: Array
var path: Array[Vector2] = []
var desk_cells: Array[Vector2i] = []
var boss_cells: Array[Vector2i] = []

var enemies: Array = []    # Array[Enemy]
var towers: Array = []     # Array[Tower]
var projectiles: Array = []
var effects: Array = []
var templates := {}        # towerId -> 능력치 템플릿
var team_level := {"hr": 1, "dv": 1, "sl": 1}

var life := MAX_LIFE
var coins := 0
var kills := 0
var score := 0
var speed := 1.0
var paused := false
var finished := false
var won := false
var endless := false  # 무한 모드: 웨이브가 끝나지 않고, 목숨이 다하면 끝
var loop := false     # 고리 맵 서바이벌: 적이 계속 돌고, 라운드는 시간이 지나면 넘어가며, 적이 max_enemies 마리면 끝
var max_enemies := 0
var round_sec := 0.0
var round_left := 0.0      # 다음 라운드까지 남은 시간
var _crowd_warned := false
var boss_room := Vector2.ZERO  # 보스방 가운데 (고리 맵에 보스방이 있으면)
var has_boss_room := false
var boss_blocking := false  # 보스방 보스가 살아 있음 → 직원은 보스만 공격
var selected: Tower

var wave_index := 0          # 진행 중이거나 다음에 시작할 웨이브
var wave_running := false
var _pending: Array = []     # 이번 웨이브에서 아직 안 나온 적 [[type, hp], ...]
var _spawn_delay := 1.0
var _since_spawn := 0.0
var _tasks: Array = []       # [{left, interval, repeats, fn}]
var _time := 0.0


func setup(p_stage_id: int, cell_size: float) -> void:
	stage_id = p_stage_id
	def = StageDefs.STAGES[stage_id]
	endless = StageDefs.is_endless(stage_id)
	loop = def.get("loop", false)
	max_enemies = int(def.get("max_enemies", 0))
	round_sec = float(def.get("round_sec", 0.0))
	cell = cell_size
	map = def.map
	for wp in StageDefs.waypoints(map):
		path.append(cell_center(wp))
	for row in map.size():
		for col in map[row].size():
			if float(map[row][col]) == 0.0:
				desk_cells.append(Vector2i(col, row))
			elif float(map[row][col]) == StageDefs.BOSS_ROOM:
				boss_cells.append(Vector2i(col, row))
	if not boss_cells.is_empty():
		has_boss_room = true
		for c in boss_cells:
			boss_room += cell_center(c) / boss_cells.size()
	var user: Dictionary = Save.user
	coins = int(def.start_coins) + GameData.start_coin_bonus(user)
	speed = Save.game_speed()
	for tower_id in GameData.tower_ids:
		var level: int = user.get("towers", {}).get(tower_id, 1)
		var team: String = GameData.towers[tower_id].team
		templates[tower_id] = Tower.make_template(tower_id, level, GameData.stat_bonus(user, team))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * cell, (c.y + 0.5) * cell)


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))


## 무한 모드는 0
func wave_count() -> int:
	return 0 if endless else def.waves.size()


## index 번째 웨이브 정의 [생성 간격, [[적, 기본 체력, 마리 수], ...]]
func wave_def(index: int) -> Array:
	return StageDefs.endless_wave(index) if endless else def.waves[index]


func display_wave() -> int:
	var shown := wave_index + 1 if wave_running else wave_index
	return shown if endless else mini(wave_count(), shown)


func has_wave(index: int) -> bool:
	return endless or index < wave_count()


func can_start_wave() -> bool:
	return not finished and not wave_running and has_wave(wave_index)


func next_wave_has_boss() -> bool:
	return has_wave(wave_index) and wave_has_boss(wave_index)


func wave_has_boss(index: int) -> bool:
	for group in wave_def(index)[1]:
		if StageDefs.ENEMIES[group[0]].boss:
			return true
	return false


# ------------------------------------------------------------------ 루프

func _process(delta: float) -> void:
	if paused or finished:
		return
	var dt := minf(delta, DT_CLAMP) * speed
	_time += dt
	_run_tasks(dt)
	_update_wave(dt)
	for e: Enemy in enemies.duplicate():
		e.update(dt)
	if loop:
		_check_crowd()
	_update_blocking()
	for t: Tower in towers.duplicate():
		t.update(dt)
	_update_projectiles(dt)
	_update_effects(dt)


func game_time() -> float:
	return _time


func _update_wave(dt: float) -> void:
	if not wave_running:
		return
	if loop:
		var shown := ceili(round_left)
		round_left -= dt
		if round_left <= 0:
			_next_round()
		elif ceili(round_left) != shown:
			hud_changed.emit()  # 남은 시간 표시
	if not _pending.is_empty():
		_since_spawn += dt
		if _since_spawn >= _spawn_delay:
			var spawn: Array = _pending.pop_front()
			var e := Enemy.new(spawn[0], spawn[1], self)
			if has_boss_room and e.is_boss():
				e.anchor(boss_room)
				message.emit("보스 등장! 보스를 잡기 전엔
일반 적을 공격할 수 없어요", UI.DANGER)
			enemies.append(e)
			enemy_spawned.emit(e)
			_since_spawn = 0.0
			if loop:
				hud_changed.emit()  # 적 수 표시
			if e.type.has("desc") and Save.mark_enemy_seen(e.type_id):
				message.emit("새로운 적: %s\n%s" % [e.type.name, e.type.desc], UI.WARN)
	elif enemies.is_empty() and not loop:
		_on_wave_cleared()


func start_wave() -> void:
	if not can_start_wave():
		return
	_pending.clear()
	_queue_wave(wave_index)
	_since_spawn = _spawn_delay  # 첫 적은 바로 나온다
	round_left = round_sec
	wave_running = true
	wave_started.emit(wave_index)
	hud_changed.emit()


## index 번째 웨이브의 적을 대기열에 붙인다. 고리 맵은 라운드 시간의 80% 안에 다 나오도록 간격을 줄인다
func _queue_wave(index: int) -> void:
	var wave: Array = wave_def(index)
	var count := 0
	for group in wave[1]:
		var hp: float = float(group[1]) * StageDefs.ENEMIES[group[0]].hp_mult * float(def.get("hp_scale", 1.0))
		for i in int(group[2]):
			_pending.append([group[0], hp])
			count += 1
	_spawn_delay = wave[0]
	if loop and count > 0:
		_spawn_delay = minf(_spawn_delay, round_sec * 0.8 / count)


## 고리 맵: 시간이 다 되면 남은 적과 상관없이 다음 라운드
func _next_round() -> void:
	wave_index += 1
	score += 100
	var bonus := 30 + 10 * wave_index
	coins += bonus
	_queue_wave(wave_index)
	round_left += round_sec
	message.emit("라운드 보너스 +%d" % bonus, UI.GOLD)
	wave_started.emit(wave_index)
	hud_changed.emit()


func alive_count() -> int:
	return enemies.size()


## 고리 맵: 적이 너무 많아지면 경고, max_enemies 마리면 끝
func _check_crowd() -> void:
	var n := alive_count()
	if n >= max_enemies:
		_end(false)
	elif n >= max_enemies * 0.8 and not _crowd_warned:
		_crowd_warned = true
		message.emit("적이 너무 많아요! %d/%d" % [n, max_enemies], UI.DANGER)
	elif n < max_enemies * 0.7:
		_crowd_warned = false


func _on_wave_cleared() -> void:
	wave_running = false
	wave_index += 1
	score += 100
	var bonus := 50 + 25 * wave_index
	coins += bonus
	if not has_wave(wave_index):
		_end(true)
		return
	var text := "웨이브 클리어! +%d" % bonus
	if next_wave_has_boss():
		text += "\n다음 웨이브: 보스 등장!"
	message.emit(text, UI.GOLD)
	hud_changed.emit()


# ------------------------------------------------------------------ 적

func on_enemy_damaged(e: Enemy, amount: float, magic_share: float) -> void:
	enemy_damaged.emit(e, amount, magic_share)


func on_enemy_killed(e: Enemy) -> void:
	enemies.erase(e)
	if e.anchored:
		_update_blocking()
	enemy_died.emit(e)
	kills += 1
	coins += int(e.type.reward)
	score += 200 if e.is_boss() else 10
	floating.emit("+%d" % int(e.type.reward), e.pos, UI.GOLD)
	if e.type.has("split"):
		_split(e)
	hud_changed.emit()


## 택배 상자: 부모 자리에서 작은 적들이 조금씩 시차를 두고 출발한다
func _split(parent: Enemy) -> void:
	var rule: Array = parent.type.split
	var children := []
	for i in int(rule[2]):
		var child := Enemy.new(rule[0], parent.max_hp * float(rule[1]), self)
		child.follow(parent, i * 0.3)
		enemies.append(child)
		children.append(child)
	enemy_split.emit(parent, children)


func on_enemy_ability(e: Enemy) -> void:
	enemy_ability.emit(e)


func on_enemy_leaked(e: Enemy) -> void:
	enemies.erase(e)
	enemy_escaped.emit(e)
	life = 0 if e.is_boss() else life - 1
	floating.emit("보스 탈출!" if e.is_boss() else "-1", path[path.size() - 1], UI.DANGER)
	hud_changed.emit()
	if life <= 0:
		life = 0
		_end(false)


# ------------------------------------------------------------------ 직원

func tower_at_cell(c: Vector2i) -> Tower:
	for t: Tower in towers:
		if t.cell == c:
			return t
	return null


func _free_desks() -> Array:
	return desk_cells.filter(func(c): return tower_at_cell(c) == null)


func _place(tower_id: String, c: Vector2i) -> Tower:
	var t := Tower.new(tower_id, templates[tower_id], self, c)
	towers.append(t)
	return t


func _remove(t: Tower) -> void:
	towers.erase(t)
	if selected == t:
		select(null)


func hire() -> void:
	if finished:
		return
	if coins < SPAWN_COST:
		message.emit("코인이 부족합니다", UI.DANGER)
		return
	var free := _free_desks()
	if free.is_empty():
		message.emit("빈 자리가 없습니다", UI.DANGER)
		return
	var candidates := GameData.towers_of_grade(1)
	if candidates.is_empty():
		message.emit("소환할 수 있는 직원이 없습니다", UI.DANGER)
		return
	coins -= SPAWN_COST
	tower_placed.emit(_place(candidates.pick_random(), free.pick_random()), false)
	hud_changed.emit()


## dragged 를 target 위에 놓았을 때: 둘을 합쳐 한 등급 높은 무작위 직원으로
func merge(dragged: Tower, target: Tower) -> void:
	if finished or not dragged.can_merge_with(target):
		return
	var upgrades := GameData.towers_of_grade(target.grade + 1)
	if upgrades.is_empty():
		return
	var c := target.cell
	_remove(dragged)
	_remove(target)
	var merged := _place(upgrades.pick_random(), c)
	tower_placed.emit(merged, true)
	floating.emit("승진!", merged.center() + Vector2(0, -cell * 0.5), GameData.grade_color(merged.grade))
	select(merged)
	hud_changed.emit()


static func sell_price(t: Tower) -> int:
	return 50 * (1 << (t.grade - 1))


static func trade_cost(t: Tower) -> int:
	return 50 * t.grade


func sell(t: Tower) -> void:
	if finished:
		return
	coins += sell_price(t)
	floating.emit("+%d" % sell_price(t), t.center(), UI.GOLD)
	_remove(t)
	hud_changed.emit()


## 협상: 비용을 내고 30% 확률로 같은 등급의 다른 직원으로 교체, 실패하면 퇴사
func trade(t: Tower) -> void:
	if finished:
		return
	var cost := trade_cost(t)
	if coins < cost:
		message.emit("코인이 부족합니다", UI.DANGER)
		return
	coins -= cost
	var c := t.cell
	_remove(t)
	if randf() < TRADE_CHANCE:
		var candidates := GameData.towers_of_grade(t.grade).filter(func(id): return id != t.id)
		if candidates.is_empty():
			candidates = GameData.towers_of_grade(t.grade)
		var swapped := _place(candidates.pick_random(), c)
		tower_placed.emit(swapped, false)
		floating.emit("협상 성공!", swapped.center() + Vector2(0, -cell * 0.5), UI.SUCCESS)
		select(swapped)
	else:
		floating.emit("퇴사...", cell_center(c), UI.DANGER)
	hud_changed.emit()


func select(t: Tower) -> void:
	selected = t
	tower_selected.emit(t)


# ------------------------------------------------------------------ 팀 업그레이드

func team_multiplier(team: String) -> float:
	return 1.0 + 0.1 * (team_level.get(team, 1) - 1)


func upgrade_cost(team: String) -> int:
	return 50 * team_level[team]


func upgrade_team(team: String) -> void:
	if finished:
		return
	var cost := upgrade_cost(team)
	if coins < cost:
		message.emit("코인이 부족합니다", UI.DANGER)
		return
	coins -= cost
	team_level[team] += 1
	for t: Tower in towers:
		if t.team == team:
			t.recalculate()
	hud_changed.emit()
	if selected:
		tower_selected.emit(selected)


# ------------------------------------------------------------------ 재화 / 효과

func add_coins(amount: int) -> void:
	coins += amount
	hud_changed.emit()


func floating_text(text: String, at: Vector2, color: Color) -> void:
	floating.emit(text, at, color)


func on_skill_used(t: Tower) -> void:
	skill_cast.emit(t)


## 투사체. sheet 가 null 이면 기본 공격 (team 모양, grade 가 높을수록 크게), 아니면 스킬 스프라이트 시트의 가운데 프레임
func add_projectile(from: Vector2, target: Enemy, physical: float, magic: float, sheet, size: float, lifetime: float, team := "", grade := 1) -> void:
	var life_time := maxf(0.2, lifetime)
	projectiles.append({
		"pos": from, "target": target, "physical": physical, "magic": magic,
		"sheet": sheet, "size": size, "life": life_time, "age": 0.0, "team": team, "grade": grade,
		"speed": maxf(cell * 8.0, from.distance_to(target.pos) / (life_time * 0.8)),
		"dir": (target.pos - from).normalized(),
	})


func _update_projectiles(dt: float) -> void:
	for p in projectiles.duplicate():
		var target: Enemy = p.target
		if target.dead:
			projectiles.erase(p)
			continue
		p.age += dt
		var distance: float = p.pos.distance_to(target.pos)
		var step: float = p.speed * dt
		if distance <= maxf(step, p.size * 0.5) or p.age >= p.life:
			projectile_hit.emit(p)
			target.damage(p.physical, p.magic)
			projectiles.erase(p)
			continue
		p.dir = (target.pos - p.pos).normalized()
		p.pos += p.dir * step


## 스킬 이펙트 애니메이션 (게임 시간 기준으로 재생/삭제)
func add_effect(sheet: String, at: Vector2, size: float, lifetime: float) -> void:
	effects.append({"sheet": sheet, "pos": at, "size": size, "life": lifetime, "age": 0.0})


func _update_effects(dt: float) -> void:
	for fx in effects.duplicate():
		fx.age += dt
		if fx.age >= fx.life:
			effects.erase(fx)


# ------------------------------------------------------------------ 스케줄러 (게임 시간 기준)

func schedule(delay: float, fn: Callable) -> void:
	_tasks.append({"left": delay, "interval": 0.0, "repeats": 1, "fn": fn})


## interval 초마다 times 번 실행 (첫 실행은 interval 뒤)
func schedule_repeating(interval: float, times: int, fn: Callable) -> void:
	if times > 0:
		_tasks.append({"left": interval, "interval": interval, "repeats": times, "fn": fn})


func _run_tasks(dt: float) -> void:
	for task in _tasks.duplicate():
		task.left -= dt
		if task.left <= 0:
			task.fn.call()
			task.repeats -= 1
			if task.repeats > 0:
				task.left += task.interval
			else:
				_tasks.erase(task)


# ------------------------------------------------------------------ 종료

const ENDLESS_GOLD_PER_WAVE := 150


func _gold_reward(p_won: bool) -> int:
	if endless:
		return wave_index * ENDLESS_GOLD_PER_WAVE
	var reward := wave_index * 100 * (1 + 0.5 * (stage_id - 1))
	return roundi(reward * 1.5 if p_won else reward)


func _end(p_won: bool) -> void:
	if finished:
		return
	finished = true
	won = p_won
	wave_running = false
	select(null)
	# 게임이 끝나면 남은 이펙트와 투사체를 치운다
	projectiles.clear()
	effects.clear()
	if p_won:
		score += life * 50
	var gold := _gold_reward(p_won)
	var new_record := endless and Save.record_endless_round(wave_index)
	var first_clear := Save.record_stage_result(stage_id, p_won, score, gold)
	hud_changed.emit()
	game_over.emit(p_won, {"kills": kills, "gold": gold, "score": score, "first_clear": first_clear,
			"wave": wave_index, "new_record": new_record})


func set_speed(value: float) -> void:
	speed = value
	Save.set_game_speed(value)


# ------------------------------------------------------------------ 보스방 (고리 맵)

## 보스방에 보스가 버티고 있는 동안에는 보스만 공격할 수 있다 (프레임마다 한 번 계산해 둔다)
func _update_blocking() -> void:
	boss_blocking = false
	if has_boss_room:
		for e: Enemy in enemies:
			if not e.dead and e.anchored:
				boss_blocking = true
				return


func can_target(e: Enemy) -> bool:
	return not e.dead and (e.anchored or not boss_blocking)

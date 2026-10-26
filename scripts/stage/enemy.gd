# 적 한 마리. 경로(칸 중심 좌표 목록)를 따라 이동하고, 끝에 닿으면 battle 에 알린다.
class_name Enemy
extends RefCounted

var type_id: String
var type: Dictionary
var battle  # Battle
var pos: Vector2
var max_hp: float
var hp: float
var pdef: float
var mdef: float
var speed_px: float
var size: float
var dead := false
var progress := 0.0  # 이동한 거리 (클수록 출구에 가깝다)
var stun_left := 0.0
var slow_left := 0.0
var slow_factor := 0.0
var hit_flash := 0.0
var _path_index := 0
var _bob := randf() * TAU


func _init(p_type_id: String, health: float, p_battle) -> void:
	type_id = p_type_id
	type = StageDefs.ENEMIES[type_id]
	battle = p_battle
	pos = battle.path[0]
	max_hp = health
	hp = health
	pdef = type.pdef
	mdef = type.mdef
	speed_px = type.speed * battle.cell
	size = battle.cell * 0.62 * type.scale


func is_boss() -> bool:
	return type.boss


func hp_ratio() -> float:
	return hp / max_hp


func stun(duration: float) -> void:
	stun_left = maxf(stun_left, duration)


## factor 만큼 느리게 (0.4 = 40% 감속). 더 강한 감속이 우선한다
func slow(factor: float, duration: float) -> void:
	if factor >= slow_factor or slow_left <= 0:
		slow_factor = minf(factor, 0.9)
	slow_left = maxf(slow_left, duration)


func update(delta: float) -> void:
	if dead:
		return
	_bob += delta * 8.0
	hit_flash = maxf(0.0, hit_flash - delta)
	if slow_left > 0:
		slow_left -= delta
		if slow_left <= 0:
			slow_factor = 0.0
	if stun_left > 0:
		stun_left -= delta
		return
	var step := speed_px * (1.0 - slow_factor) * delta
	while step > 0 and not dead:
		var target: Vector2 = battle.path[_path_index]
		var distance := pos.distance_to(target)
		if distance <= step:
			pos = target
			progress += distance
			step -= distance
			_path_index += 1
			if _path_index >= battle.path.size():
				dead = true
				battle.on_enemy_leaked(self)
		else:
			pos += (target - pos).normalized() * step
			progress += step
			step = 0


## 물리/마법 피해에 방어력 적용: 피해 × (1 − 방어/(방어+100))
func damage(physical: float, magic: float) -> void:
	if dead:
		return
	var total := physical * (1.0 - pdef / (pdef + 100.0)) + magic * (1.0 - mdef / (mdef + 100.0))
	hp = maxf(0.0, hp - total)
	hit_flash = 0.12
	if hp <= 0:
		kill()


func kill() -> void:
	if dead:
		return
	dead = true
	hp = 0
	battle.on_enemy_killed(self)


func reduce_defense(physical_reduction: float, magic_reduction: float, duration: float) -> void:
	if dead:
		return
	# 실제로 깎인 양만 나중에 되돌린다
	var p := minf(physical_reduction, pdef)
	var m := minf(magic_reduction, mdef)
	pdef -= p
	mdef -= m
	battle.schedule(duration, func():
		pdef += p
		mdef += m)


## 그릴 때 쓰는 살짝 통통 튀는 오프셋
func bob_offset() -> float:
	return 0.0 if stun_left > 0 else sin(_bob) * size * 0.04

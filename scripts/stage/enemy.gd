# 적 한 마리. 경로(칸 중심 좌표 목록)를 따라 이동하고, 끝에 닿으면 battle 에 알린다.
# 특수 능력 (StageDefs.ENEMIES 의 키): split 분열, heal 주변 회복, cc_immune 기절/감속 면역,
# shield 보호막, ring 주변 직원 기절.
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
var hp_trail := 1.0  # 체력바에서 하얗게 남았다가 천천히 줄어드는 부분 (그리기 전용)
var max_shield := 0.0
var shield := 0.0
var ability_timer := 0.0  # 회복/전화벨 주기
var ability_flash := 0.0  # 능력을 쓴 직후 연출용 (그리기 전용)
var hold := 0.0           # 분열로 태어난 적이 겹치지 않게 잠깐 멈춰 있는 시간
var _since_hit := 0.0
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
	max_shield = health * type.get("shield", 0.0)
	shield = max_shield
	ability_timer = type.get("interval", 0.0) * randf_range(0.5, 1.0)


## 분열로 생긴 적: 부모 자리에서 이어서 출발한다
func follow(parent: Enemy, delay: float) -> void:
	pos = parent.pos
	progress = parent.progress
	_path_index = parent._path_index
	hold = delay


func is_boss() -> bool:
	return type.boss


func is_cc_immune() -> bool:
	return type.get("cc_immune", false)


func hp_ratio() -> float:
	return hp / max_hp


func shield_ratio() -> float:
	return shield / max_shield if max_shield > 0 else 0.0


func stun(duration: float) -> void:
	if is_cc_immune():
		return
	stun_left = maxf(stun_left, duration)


## factor 만큼 느리게 (0.4 = 40% 감속). 더 강한 감속이 우선한다
func slow(factor: float, duration: float) -> void:
	if is_cc_immune():
		return
	if factor >= slow_factor or slow_left <= 0:
		slow_factor = minf(factor, 0.9)
	slow_left = maxf(slow_left, duration)


func update(delta: float) -> void:
	if dead:
		return
	_bob += delta * 8.0
	hit_flash = maxf(0.0, hit_flash - delta)
	ability_flash = maxf(0.0, ability_flash - delta)
	_since_hit += delta
	if max_shield > 0 and shield < max_shield and _since_hit >= type.shield_delay:
		shield = minf(max_shield, shield + max_shield * type.shield_regen * delta)
	if slow_left > 0:
		slow_left -= delta
		if slow_left <= 0:
			slow_factor = 0.0
	if stun_left > 0:
		stun_left -= delta
		return
	_update_ability(delta)
	if hold > 0:
		hold -= delta
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


func _update_ability(delta: float) -> void:
	if not type.has("interval"):
		return
	ability_timer -= delta
	if ability_timer > 0:
		return
	ability_timer += type.interval
	ability_flash = 0.6
	var radius: float = type.radius * battle.cell
	if type.has("heal"):
		# 자기 최대 체력의 일정 비율만큼 주변 적을 회복 (보스도 같은 양이라 보스를 과하게 살리지 않는다)
		var amount: float = max_hp * type.heal
		for e: Enemy in battle.enemies:
			if not e.dead and e.pos.distance_to(pos) <= radius and e.hp < e.max_hp:
				e.hp = minf(e.max_hp, e.hp + amount)
		battle.on_enemy_ability(self)
	elif type.has("ring"):
		for t: Tower in battle.towers:
			if t.center().distance_to(pos) <= radius:
				t.stun(type.ring)
		battle.on_enemy_ability(self)


## 물리/마법 피해에 방어력 적용: 피해 × (1 − 방어/(방어+100)). 보호막이 먼저 막는다
func damage(physical: float, magic: float) -> void:
	if dead:
		return
	var p := physical * (1.0 - pdef / (pdef + 100.0))
	var m := magic * (1.0 - mdef / (mdef + 100.0))
	var raw := p + m
	hit_flash = 0.12
	_since_hit = 0.0
	if raw <= 0:
		return
	var absorbed := minf(shield, raw)
	shield -= absorbed
	var total := minf(raw - absorbed, hp) + absorbed
	hp = maxf(0.0, hp - (raw - absorbed))
	if total > 0:
		battle.on_enemy_damaged(self, total, m / raw)
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

# 배치된 직원(타워) 한 명. 공격 대상 찾기, 공격 모션, 스킬, 버프를 관리한다.
class_name Tower
extends RefCounted

## 이 사거리(칸) 이상이면 원거리(투사체) 공격
const RANGED_THRESHOLD := 4.0

var id: String          # tower_dv1
var data: Dictionary    # gamedata 의 타워 정보
var battle              # Battle
var cell: Vector2i
var name: String
var team: String
var grade: int
var attack_type: String

# 레벨/취미/장비가 반영된 기본 능력치 (팀 업그레이드, 버프 제외)
var base_physical: float
var base_magic: float
var base_speed: float
var range_px: float
# 현재 능력치
var physical := 0.0
var magic := 0.0
var attack_speed := 1.0
var attack_buff := 0.0
var speed_buff := 0.0
var cooldown_reduction := 0.0

var target: Enemy
var skill: Skill
var attack_cooldown := 0.0
var attacking := false
var attack_elapsed := 0.0
var attack_duration := 0.0
var spawn_anim := 0.0   # 배치 직후 튀어나오는 연출
var buff_glow := 0.0


func _init(p_id: String, template: Dictionary, p_battle, p_cell: Vector2i) -> void:
	id = p_id
	data = GameData.towers[id]
	battle = p_battle
	cell = p_cell
	name = data.towerName
	team = data.team
	grade = int(data.towerGrade)
	attack_type = data.attackType
	base_physical = template.physical
	base_magic = template.magic
	base_speed = template.speed
	range_px = float(data.towerAttackRange) * battle.cell
	skill = Skill.new(GameData.skill_for_tower(data), battle, template.cooldown_mult)
	spawn_anim = 1.0
	recalculate()


## 레벨, 취미/장비 보너스가 반영된 기본 능력치 (스테이지 시작 시 직원별로 한 번 계산)
static func make_template(tower_id: String, level: int, bonus: Dictionary) -> Dictionary:
	var d: Dictionary = GameData.towers[tower_id]
	var level_mult := 1.0 + float(d.towerAttackMult) * (level - 1)
	return {
		"physical": float(d.towerPhysicalAttack) * level_mult * bonus.physical,
		"magic": float(d.towerMagicAttack) * level_mult * bonus.magic,
		"speed": float(d.towerAttackSpeed) * bonus.speed,
		"cooldown_mult": bonus.cooldown,
	}


func center() -> Vector2:
	return battle.cell_center(cell)


func can_merge_with(other: Tower) -> bool:
	return other != null and other != self and grade < GameData.MAX_GRADE \
			and other.id == id and other.grade == grade


## 팀 업그레이드와 버프를 반영해 현재 능력치를 다시 계산
func recalculate() -> void:
	var team_mult: float = battle.team_multiplier(team)
	physical = base_physical * team_mult * (1.0 + attack_buff)
	magic = base_magic * team_mult * (1.0 + attack_buff)
	attack_speed = base_speed * (1.0 + speed_buff)
	skill.cooldown = skill.base_cooldown * maxf(0.3, 1.0 - cooldown_reduction)


func buff_attack(mult: float, duration: float) -> void:
	attack_buff += mult
	buff_glow = maxf(buff_glow, duration)
	recalculate()
	battle.schedule(duration, func():
		attack_buff -= mult
		recalculate())


func buff_speed(mult: float, duration: float) -> void:
	speed_buff += mult
	buff_glow = maxf(buff_glow, duration)
	recalculate()
	battle.schedule(duration, func():
		speed_buff -= mult
		recalculate())


func buff_cooldown(mult: float, duration: float) -> void:
	cooldown_reduction += mult
	recalculate()
	battle.schedule(duration, func():
		cooldown_reduction -= mult
		recalculate())


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_value := 0.0
	var c := center()
	for enemy: Enemy in battle.enemies:
		if enemy.dead:
			continue
		var distance := enemy.pos.distance_to(c)
		if distance > range_px:
			continue
		var value: float
		match attack_type:
			"furthest": value = enemy.progress   # 출구에 가장 가까운 적
			"strongest": value = enemy.hp        # 체력이 가장 많은 적
			_: value = -distance                 # 가장 가까운 적
		if best == null or value > best_value:
			best_value = value
			best = enemy
	return best


func _in_range(enemy: Enemy) -> bool:
	return enemy != null and not enemy.dead and enemy.pos.distance_to(center()) <= range_px


func update(delta: float) -> void:
	spawn_anim = maxf(0.0, spawn_anim - delta * 4.0)
	buff_glow = maxf(0.0, buff_glow - delta)
	attack_cooldown -= delta
	skill.update(delta)
	if attacking:
		attack_elapsed += delta
		if attack_elapsed >= attack_duration:
			attacking = false
			_resolve_attack()
	elif attack_cooldown <= 0:
		target = _find_target()
		if target != null:
			attack_cooldown = 1.0 / attack_speed
			attack_duration = attack_cooldown * 0.5
			attack_elapsed = 0.0
			attacking = true
	if not _in_range(target):
		target = _find_target()
	if target != null:
		skill.use(self)


## 공격 모션이 끝났을 때 실제 피해를 준다
func _resolve_attack() -> void:
	if not _in_range(target):
		target = _find_target()
		if target == null:
			return
	var melee: bool = range_px < RANGED_THRESHOLD * battle.cell
	battle.tower_attacked.emit(self, target, melee)
	if melee:
		target.damage(physical, magic)
	else:
		battle.add_projectile(center(), target, physical, magic, null, battle.cell * 0.4, 0.5)


func attack_progress() -> float:
	return clampf(attack_elapsed / attack_duration, 0.0, 0.999) if attacking and attack_duration > 0 else -1.0

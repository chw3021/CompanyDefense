# 직원 스킬. 쿨타임이 차 있고 공격 대상이 있을 때 발동한다.
# 효과가 실제로 발동했을 때만 쿨타임이 돌아간다.
class_name Skill
extends RefCounted

var data: Dictionary
var battle
var id: String
var name: String
var mult: float
var duration: float
var cooldown: float
var base_cooldown: float
var range_px: float
var effect_path: String  # 이펙트 스프라이트 시트 (128px 프레임)
var _elapsed := 0.0


func _init(p_data: Dictionary, p_battle, cooldown_mult: float) -> void:
	data = p_data
	battle = p_battle
	id = data.skillId
	name = data.skillName
	mult = float(data.mult)
	duration = float(data.duration)
	cooldown = float(data.cooldown) * cooldown_mult
	base_cooldown = cooldown
	range_px = float(data.range) * battle.cell
	var summon: String = data.get("summoneeImagePath", "")
	effect_path = GameData.asset(summon) if summon != "" else ""


func ready_ratio() -> float:
	return clampf(_elapsed / cooldown, 0.0, 1.0) if cooldown > 0 else 1.0


func update(delta: float) -> void:
	_elapsed += delta


func use(tower: Tower) -> void:
	if _elapsed < cooldown:
		return
	if _apply(tower):
		_elapsed = 0.0
		tower.battle.on_skill_used(tower)


# ------------------------------------------------------------------ 도우미

func _in_range(tower: Tower, radius: float) -> Array:
	var c := tower.center()
	return battle.enemies.filter(func(e: Enemy): return battle.can_target(e) and e.pos.distance_to(c) <= radius)


func _alive() -> Array:
	return battle.enemies.filter(func(e: Enemy): return battle.can_target(e))


func _effect(at: Vector2, size: float) -> void:
	if effect_path != "":
		battle.add_effect(effect_path, at, size, maxf(0.6, duration))


func _shot(tower: Tower, target: Enemy, physical: float, magic: float) -> void:
	if effect_path != "":
		battle.add_projectile(tower.center(), target, physical, magic, effect_path, battle.cell * 0.5, 0.6)


## interval 초마다 times 번 피해 (도트 피해)
func _dot(targets: Array, interval: float, times: int, physical: float, magic: float) -> void:
	battle.schedule_repeating(interval, times, func():
		for e: Enemy in targets:
			e.damage(physical, magic))


func _ally_effect(ally: Tower, scale: float) -> void:
	_effect(ally.center() + Vector2(0, -battle.cell * 0.3), battle.cell * scale)


# ------------------------------------------------------------------ 스킬별 효과

func _apply(t: Tower) -> bool:
	var cell: float = battle.cell
	match id:
		# ---- 개발팀: 마법 피해
		"dv1":  # 디버깅: 대상에게 마법 투사체
			if t.target == null or t.target.dead:
				return false
			_shot(t, t.target, 0, t.magic * mult)
			return true
		"dv2":  # 코드 실행: 범위 내 모든 적에게 투사체
			var targets := _in_range(t, range_px)
			for e in targets:
				_shot(t, e, 0, t.magic * mult)
			return not targets.is_empty()
		"dv3":  # 서버 안정화: 범위 내 적에게 지속 피해
			var targets := _in_range(t, range_px)
			if targets.is_empty():
				return false
			_dot(targets, 0.1, roundi(duration * 10), 0, t.magic * mult)
			_effect(t.center(), cell * 0.8 * 1.6)
			return true
		"dv4":  # 알고리즘 창조: 선두 적에게 지속 피해
			var leader: Enemy = null
			for e: Enemy in _alive():
				if leader == null or e.progress > leader.progress:
					leader = e
			if leader == null:
				return false
			_dot([leader], 1.0, roundi(duration), 0, t.magic * mult)
			_effect(t.center(), cell * 0.8 * 1.4)
			return true
		"dv5_1":  # 코드 해석: 맵 전체 마법 피해
			var targets := _alive()
			for e: Enemy in targets:
				e.damage(0, t.magic * mult)
			if not targets.is_empty():
				_effect(t.center(), cell * 1.6)
			return not targets.is_empty()
		"dv5_2":  # 해킹 방어: 맵 전체 지속 피해
			var targets := _alive()
			if targets.is_empty():
				return false
			_dot(targets, 0.1, roundi(duration * 10), 0, t.magic * mult)
			_effect(t.center(), cell * 1.6)
			return true
		# ---- 인사팀: 지원 / 방해
		"hr1":  # 커피 수혈: 주변 직원 공격 속도 증가
			for ally: Tower in battle.towers:
				if ally.center().distance_to(t.center()) <= range_px:
					ally.buff_speed(mult, duration)
					_ally_effect(ally, 0.6)
			return true
		"hr2":  # 사무 지원: 범위 내 적 방어력 감소
			var targets := _in_range(t, range_px)
			for e: Enemy in targets:
				e.reduce_defense(mult, mult, duration)
				_effect(e.pos, cell * 0.6)
			return not targets.is_empty()
		"hr3":  # 참을 수 없는 가십: 확률적으로 대상 기절
			var e := t.target
			if e == null or e.dead:
				return false
			if randf() <= mult:
				e.stun(duration)
				_effect(e.pos, cell * 0.6)
			return true
		"hr4":  # 휴식 시간: 범위 내 적 기절
			var targets := _in_range(t, range_px)
			for e: Enemy in targets:
				e.stun(duration)
				_effect(e.pos, cell * 0.6)
			return not targets.is_empty()
		"hr5_1":  # 성과 압박: 가장 강한 직원 강화
			var strongest: Tower = null
			for ally: Tower in battle.towers:
				if strongest == null or ally.physical + ally.magic > strongest.physical + strongest.magic:
					strongest = ally
			if strongest == null:
				return false
			strongest.buff_attack(mult, duration)
			strongest.buff_speed(mult, duration)
			strongest.buff_cooldown(mult, duration)
			_ally_effect(strongest, 0.6)
			return true
		"hr5_2":  # 복지 캠페인: 모든 직원 강화
			for ally: Tower in battle.towers:
				ally.buff_attack(mult, duration)
				ally.buff_speed(mult, duration)
				_ally_effect(ally, 0.5)
			return true
		# ---- 영업팀: 물리 피해 / 경제
		"sl1":  # 콜드 콜: 대상에게 강한 물리 피해
			var e := t.target
			if e == null or e.dead:
				return false
			_effect(e.pos, cell * 0.7)
			e.damage(t.physical * mult, 0)
			return true
		"sl2":  # 가격 협상: 범위 내 적 감속
			var targets := _in_range(t, range_px)
			for e: Enemy in targets:
				e.slow(mult, duration)
				_effect(e.pos, cell * 0.5)
			return not targets.is_empty()
		"sl3":  # 판매 할당량: 코인 획득
			var coins := roundi(mult)
			battle.add_coins(coins)
			battle.floating_text("+%d" % coins, t.center() + Vector2(0, -cell * 0.5), UI.GOLD)
			_effect(t.center(), cell * 0.7)
			return true
		"sl4":  # 프레젠테이션: 범위 물리 피해
			var targets := _in_range(t, range_px)
			for e: Enemy in targets:
				e.damage(t.physical * mult, 0)
			if not targets.is_empty():
				_effect(t.center(), range_px * 1.2)
			return not targets.is_empty()
		"sl5_1":  # 대형 계약: 체력이 낮은 일반 적 즉시 처치, 아니면 큰 피해
			var e := t.target
			if e == null or e.dead:
				return false
			_effect(e.pos, cell * 0.8)
			if not e.is_boss() and e.hp_ratio() <= mult:
				e.kill()
			else:
				e.damage(t.physical * 5.0, 0)
			return true
		"sl5_2":  # VIP 접대: 범위 물리 피해 + 감속
			var targets := _in_range(t, range_px)
			for e: Enemy in targets:
				e.damage(t.physical * mult, 0)
				e.slow(0.5, duration)
			if not targets.is_empty():
				_effect(t.center(), range_px * 1.2)
			return not targets.is_empty()
	push_warning("unknown skill " + id)
	return false

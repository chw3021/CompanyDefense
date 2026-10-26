# 스테이지 정의: 맵, 웨이브, 적 종류.
# 맵 값 규칙: 0 = 책상(직원 배치 칸), 1.0 = 통로, 1.1 / 1.2 / 1.3 ... = 경유지 순서.
# 1.1 이 입구이고 0.1 씩 증가하는 값을 끝까지 따라간다 (마지막 경유지가 출구).
# 모든 맵은 위쪽 줄부터 적는다 (map[row][col], row 0 = 화면 맨 위).
class_name StageDefs

const COUNT := 4
const BASE_START_COINS := 300

## 적 종류. hp_mult 는 웨이브 기본 체력에 곱해지고 speed 는 초당 칸 수
const ENEMIES := {
	"printer": {"name": "프린터", "hp_mult": 1.0, "speed": 2.0, "pdef": 5, "mdef": 5, "scale": 1.0, "tint": Color(1, 1, 1), "reward": 8, "boss": false},
	"fax": {"name": "팩스", "hp_mult": 0.6, "speed": 3.5, "pdef": 0, "mdef": 10, "scale": 0.8, "tint": Color(0.55, 0.85, 1), "reward": 6, "boss": false},
	"copier": {"name": "복합기", "hp_mult": 2.5, "speed": 1.3, "pdef": 40, "mdef": 5, "scale": 1.25, "tint": Color(0.75, 0.6, 0.95), "reward": 15, "boss": false},
	"server": {"name": "서버", "hp_mult": 1.6, "speed": 1.8, "pdef": 5, "mdef": 45, "scale": 1.1, "tint": Color(0.55, 1, 0.55), "reward": 12, "boss": false},
	"boss": {"name": "부장님 프린터", "hp_mult": 12.0, "speed": 1.0, "pdef": 20, "mdef": 20, "scale": 1.6, "tint": Color(1, 0.45, 0.45), "reward": 100, "boss": true},
	# 특수 능력이 있는 적. desc 는 처음 만났을 때 한 번 보여 준다
	# split: 죽으면 [적, 부모 최대 체력 대비 비율, 마리 수]로 나뉜다
	"parcel": {"name": "택배 상자", "hp_mult": 1.0, "speed": 1.8, "pdef": 10, "mdef": 0, "scale": 1.1, "tint": Color(0.85, 0.62, 0.38), "reward": 8, "boss": false,
			"split": ["parcel_mini", 0.25, 3], "desc": "부수면 작은 상자 3개로 나뉩니다"},
	"parcel_mini": {"name": "작은 상자", "hp_mult": 0.3, "speed": 2.6, "pdef": 5, "mdef": 0, "scale": 0.65, "tint": Color(0.9, 0.7, 0.45), "reward": 2, "boss": false},
	# heal: interval 초마다 radius 칸 안의 적을 자기 최대 체력 × heal 만큼 회복
	"water": {"name": "정수기", "hp_mult": 1.4, "speed": 1.6, "pdef": 10, "mdef": 20, "scale": 1.15, "tint": Color(0.5, 0.8, 1), "reward": 14, "boss": false,
			"interval": 3.0, "radius": 1.6, "heal": 0.18, "desc": "주변 적의 체력을 회복시킵니다. 먼저 노리세요!"},
	"vacuum": {"name": "로봇청소기", "hp_mult": 0.9, "speed": 2.8, "pdef": 15, "mdef": 15, "scale": 1.05, "tint": Color(0.45, 0.47, 0.55), "reward": 10, "boss": false,
			"cc_immune": true, "desc": "빠르고, 기절과 감속에 걸리지 않습니다"},
	# shield: 최대 체력 대비 보호막. shield_delay 초 동안 안 맞으면 초당 shield_regen 비율씩 다시 찬다
	"laptop": {"name": "노트북", "hp_mult": 0.9, "speed": 2.0, "pdef": 0, "mdef": 0, "scale": 1.1, "tint": Color(0.6, 0.9, 1), "reward": 12, "boss": false,
			"shield": 0.6, "shield_delay": 2.5, "shield_regen": 0.3, "desc": "보호막이 있고, 한동안 안 맞으면 다시 채웁니다"},
	# ring: interval 초마다 radius 칸 안의 직원을 ring 초 동안 기절 (통화 중)
	"phone": {"name": "전화기", "hp_mult": 1.3, "speed": 1.7, "pdef": 15, "mdef": 10, "scale": 1.1, "tint": Color(1, 0.55, 0.45), "reward": 12, "boss": false,
			"interval": 5.0, "radius": 1.5, "ring": 1.5, "desc": "벨이 울리면 근처 직원이 통화하느라 잠시 멈춥니다"},
}

const STAGES := {
	1: {
		"name": "입사 첫 주",
		"difficulty": "쉬움",
		"start_coins": 300,
		"hp_scale": 1.6,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(1, 1, 1),
		"map": [
			[1.1, 0, 0, 2.2, 0, 0, 1.5, 1.0, 1.0, 1.4],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3],
			[0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 0],
			[0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 0],
			[1.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.8],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[2.0, 1.0, 1.0, 2.1, 0, 0, 1.6, 1.0, 1.0, 1.7],
		],
		# [생성 간격(초), [[적, 기본 체력, 마리 수], ...]]
		"waves": [
			[1.0, [["printer", 30, 8]]],
			[0.9, [["printer", 40, 10]]],
			[0.8, [["printer", 50, 8], ["fax", 50, 6]]],
			[0.8, [["printer", 65, 7], ["parcel", 65, 3], ["copier", 65, 3]]],
			[0.7, [["fax", 80, 8], ["server", 80, 6], ["copier", 80, 3]]],
			[1.5, [["printer", 90, 6], ["boss", 90, 1]]],
		],
	},
	2: {
		"name": "분기 마감",
		"difficulty": "보통",
		"start_coins": 500,
		"hp_scale": 1.5,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(1, 0.9, 0.75),
		"map": [
			[1.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.2, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.4, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 1.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.6, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[1.8, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.7, 0],
		],
		"waves": [
			[1.0, [["printer", 45, 10]]],
			[0.7, [["fax", 55, 12]]],
			[0.9, [["printer", 65, 8], ["copier", 65, 4]]],
			[0.8, [["server", 70, 8], ["laptop", 70, 2]]],
			[0.7, [["fax", 85, 10], ["copier", 85, 5]]],
			[0.8, [["server", 95, 6], ["water", 95, 2], ["copier", 95, 6]]],
			[0.6, [["printer", 110, 9], ["parcel", 110, 3], ["fax", 110, 8]]],
			[1.0, [["copier", 125, 6], ["server", 125, 6], ["boss", 125, 1]]],
		],
	},
	3: {
		"name": "연말 감사",
		"difficulty": "어려움",
		"start_coins": 800,
		"hp_scale": 1.4,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(0.72, 0.75, 0.95),
		"map": [
			[0, 1.1, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 1.0, 0, 0, 1.4, 1.0, 1.0, 1.5, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.2, 1.0, 1.0, 1.3, 0, 0, 1.0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 1.6, 0, 0],
		],
		"waves": [
			[1.0, [["printer", 55, 10]]],
			[0.7, [["fax", 65, 10], ["vacuum", 65, 4]]],
			[0.8, [["printer", 80, 10], ["copier", 80, 2], ["server", 80, 2]]],
			[0.8, [["printer", 90, 8], ["copier", 90, 3], ["server", 90, 3]]],
			[0.8, [["fax", 105, 10], ["boss", 105, 1]]],
			[0.8, [["server", 120, 6], ["phone", 120, 2], ["copier", 120, 4]]],
			[0.45, [["fax", 135, 14], ["vacuum", 135, 6]]],
			[0.9, [["copier", 150, 10]]],
			[0.6, [["printer", 170, 6], ["laptop", 170, 4], ["server", 170, 6], ["water", 170, 2], ["fax", 170, 8]]],
			[1.2, [["copier", 190, 6], ["server", 190, 6], ["boss", 200, 2]]],
		],
	},
	# 무한 모드 (서바이벌): 적이 출구 없이 고리를 계속 돌고, 라운드는 시간이 지나면 저절로 넘어간다.
	# 살아 있는 적이 max_enemies 마리가 되면 끝 (endless_wave 가 라운드마다 적을 만든다)
	4: {
		"name": "무한 야근",
		"difficulty": "무한",
		"start_coins": 600,
		"hp_scale": 1.0,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(0.8, 0.68, 0.95),
		"endless": true,
		"loop": true,
		"max_enemies": 100,
		"round_sec": 20.0,
		# 사무실 한가운데를 도는 고리. 책상은 고리 안쪽과 바깥쪽에 있다
		"map": [
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 1.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.2, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.4, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		],
		"waves": [],
	},
}

## 무한 모드 난이도: 웨이브마다 체력 x endless_hp_growth, 마리 수와 생성 속도도 늘어난다
const ENDLESS_BASE_HP := 40.0
static var endless_hp_growth := 1.22  # 시뮬레이터가 --dev-growth 로 바꿔 볼 수 있게 var
const ENDLESS_MAX_COUNT := 36


static func is_endless(stage_id: int) -> bool:
	return STAGES[stage_id].get("endless", false)


## 무한 모드의 index 번째 웨이브 (0부터). 형식은 STAGES 의 waves 와 같다
## 10의 배수 = 보스 웨이브, 5의 배수 = 중간 보스, 나머지는 4가지 테마를 돌아가며
## 특수 적은 6웨이브부터 섞여 나온다
static func endless_wave(index: int) -> Array:
	var w := index + 1
	var hp := ENDLESS_BASE_HP * pow(endless_hp_growth, index)
	var count := mini(8 + int(index * 0.7), ENDLESS_MAX_COUNT)
	var interval := maxf(0.35, 1.0 - index * 0.02)
	var special := w > 5
	if w % 10 == 0:
		return [maxf(interval, 0.8), [["printer", hp, count / 2], ["phone", hp, w / 10], ["boss", hp, w / 10]]]
	if w % 5 == 0:
		var guard := "water" if special else "server"
		return [interval, [["copier", hp, count / 4], [guard, hp, maxi(1, count / 4)], ["boss", hp * 0.5, 1]]]
	match w % 4:
		1:  # 프린터 물량 (+ 택배 상자)
			if special:
				return [interval, [["printer", hp, count / 2], ["parcel", hp, count / 3]]]
			return [interval, [["printer", hp, count]]]
		2:  # 빠른 떼 (+ 로봇청소기)
			if special:
				return [interval * 0.6, [["fax", hp, count], ["vacuum", hp, count / 3]]]
			return [interval * 0.6, [["fax", hp, roundi(count * 1.4)]]]
		3:  # 단단한 기계 (물리/마법 방어, 보호막)
			var third := "laptop" if special else "printer"
			return [interval, [[third, hp, count / 3], ["copier", hp, maxi(1, count / 3)], ["server", hp, maxi(1, count / 3)]]]
	if special:  # 지원형이 섞인 혼합 부대
		return [interval * 0.8, [["printer", hp, count / 4], ["phone", hp, count / 6], ["water", hp, count / 6], ["laptop", hp, count / 4]]]
	return [interval * 0.8, [["printer", hp, count / 4], ["fax", hp, count / 4], ["copier", hp, count / 4], ["server", hp, count / 4]]]


static func description(stage_id: int) -> String:
	var s: Dictionary = STAGES[stage_id]
	if is_endless(stage_id):
		return "%s / 적 %d마리 버티기" % [s.difficulty, s.get("max_enemies", 100)]
	return "%s / 웨이브 %d" % [s.difficulty, s.waves.size()]


## 경유지 칸 목록 (Vector2i(열, 행)), 입구부터 출구까지
static func waypoints(map: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var i := 0
	while true:
		var value := 1.1 + i * 0.1
		var found := false
		for row in map.size():
			for col in map[row].size():
				if absf(float(map[row][col]) - value) < 0.001:
					result.append(Vector2i(col, row))
					found = true
					break
			if found:
				break
		if not found:
			break
		i += 1
	return result

extends RefCounted
## Данные уроков обучения (песочница). Один урок = одна механика (progressive
## disclosure, §6). Координаты пишутся как [x, y]; compiled() переводит их в idx.
## Эталонный ход `solution` — он же подсветка-цель `hint_to` и проверяется тестами
## (каждый урок обязан быть решаем: solution достигает goal).

## Флаги «тренировочного» варианта: слабый король (custodial2 — взятие в 1 ход),
## трон не враждебен, побег в угол.
const DRILL := {"king_capture": "custodial2", "throne_hostile": false,
	"king_armed": true, "escape": "corner"}


## Все уроки по порядку. track: "both" | "defenders" | "attackers" (для будущего
## разделения на треки — сейчас идут единым потоком).
static func all() -> Array:
	return [
		{
			"id": "move", "track": "both", "variant": DRILL, "size": 7, "turn": "defenders",
			"title": "Движение",
			"text": "Фигуры ходят по прямой на любое число клеток, как ладья, и не перепрыгивают через другие. Передвинь подсвеченную фигуру на отмеченную клетку.",
			"defenders": [[5, 6]],
			"hint_from": [5, 6],
			"solution": {"from": [5, 6], "to": [5, 2]},
			"goal": {"type": "reach", "cell": [5, 2]},
		},
		{
			"id": "capture", "track": "both", "variant": DRILL, "size": 7, "turn": "defenders",
			"title": "Взятие",
			"text": "Зажми вражескую фигуру с двух противоположных сторон своими — и она снята. Сделай ход на подсвеченную клетку, чтобы взять чёрную фигуру.",
			"attackers": [[2, 5]],
			"defenders": [[1, 5], [3, 2]],
			"hint_from": [3, 2],
			"solution": {"from": [3, 2], "to": [3, 5]},
			"goal": {"type": "capture"},
		},
		{
			"id": "corner", "track": "both", "variant": DRILL, "size": 7, "turn": "defenders",
			"title": "Углы помогают",
			"text": "Углы доски враждебны: угол заменяет вторую фигуру при взятии. Прижми чёрную фигуру к углу.",
			"attackers": [[1, 0]],
			"defenders": [[2, 3]],
			"hint_from": [2, 3],
			"solution": {"from": [2, 3], "to": [2, 0]},
			"goal": {"type": "capture"},
		},
		{
			"id": "escape", "track": "defenders", "variant": DRILL, "size": 7, "turn": "defenders",
			"title": "Побег короля",
			"text": "Защитники побеждают, когда король доходит до углового поля. Уведи короля в угол.",
			"king": [3, 0],
			"attackers": [[6, 5]],
			"hint_from": [3, 0],
			"solution": {"from": [3, 0], "to": [0, 0]},
			"goal": {"type": "king_escape"},
		},
		{
			"id": "capture_king", "track": "attackers", "variant": DRILL, "size": 7, "turn": "attackers",
			"title": "Поимка короля",
			"text": "Осаждающие побеждают, окружив короля. Зажми короля с двух противоположных сторон, чтобы выиграть.",
			"king": [3, 5],
			"attackers": [[2, 5], [4, 2]],
			"hint_from": [4, 2],
			"solution": {"from": [4, 2], "to": [4, 5]},
			"goal": {"type": "capture_king"},
		},
	]


## Переводит координаты урока в idx-форму (целые индексы клеток) для движка/UI.
static func compiled(L: Dictionary) -> Dictionary:
	var n := int(L.size)
	var c := {
		"size": n, "variant": L.variant, "turn": String(L.turn),
		"title": L.title, "text": L.text,
		"king": (_ci(n, L.king) if (L.has("king") and typeof(L.king) == TYPE_ARRAY) else -1),
		"attackers": [], "defenders": [],
		"hint_from": _ci(n, L.hint_from),
		"solution": {"from": _ci(n, L.solution.from), "to": _ci(n, L.solution.to)},
		"goal": {"type": String(L.goal.type)},
	}
	for a in L.get("attackers", []):
		c.attackers.append(_ci(n, a))
	for d in L.get("defenders", []):
		c.defenders.append(_ci(n, d))
	c.hint_to = [c.solution.to]
	if L.goal.has("cell"):
		c.goal.cell = _ci(n, L.goal.cell)
	return c


## Строит GameState из компилированного (idx-форма) урока.
static func build_state(c: Dictionary):
	var GameState = load("res://scripts/core/GameState.gd")
	var s = GameState.new()
	s.king = int(c.get("king", -1))
	for a in c.attackers:
		s.attackers[int(a)] = true
	for d in c.defenders:
		s.defenders[int(d)] = true
	s.turn = String(c.turn)
	return s


## Достигнута ли цель урока? Единый источник правды для контроллера и тестов.
## last_to — клетка, куда сходил игрок; caps — список взятых этим ходом.
static func goal_met(rules, state, c: Dictionary, last_to: int, caps: Array) -> bool:
	match String(c.goal.type):
		"reach":
			return last_to == int(c.goal.cell)
		"capture":
			return not caps.is_empty()
		"king_escape":
			return rules.check_winner(state) == "defenders"
		"capture_king":
			return state.king == -1
	return false


static func _ci(n: int, p) -> int:
	return int(p[1]) * n + int(p[0])

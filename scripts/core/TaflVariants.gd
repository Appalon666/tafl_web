extends RefCounted
## Данные трёх вариантов Тафла + сборка стартовой расстановки.
## Размеры и флаги — конфиг-управляемые, чтобы тюнить баланс по итогам ресёрча
## (Copenhagen edge/exit-fort, shieldwall, weaponless king и т.п.) без переписи кода.
##
## ⚠️ Правила и расстановки — каноничные стартовые; тонкие моменты (взятие короля
## у трона, fort/shieldwall) будут уточнены по результатам анализа предметной области.

const GameStateScript = preload("res://scripts/core/GameState.gd")

# escape:        "corner" — король бежит в угол | "edge" — на любую кромку.
# king_armed:    участвует ли король во взятии (как «молот»).
# throne_hostile:трон является «наковальней» (помогает взятию) когда пуст.
# king_capture:  как берётся король (реализация — RulesEngine._king_captured):
#                  "surround4"  — сильный король: окружить со всех 4 сторон,
#                                 у кромки взять нельзя (Fetlar/Copenhagen);
#                  "custodial2" — слабый король: зажать с 2 сторон, как фигуру;
#                                 при throne_hostile=true у трона нужно полное
#                                 окружение (Tablut 4/3/2; Brandubh — всегда 2).
const VARIANTS := {
	"brandubh": {
		# §1: углы враждебны, трон НЕ враждебен, король вооружён, берётся с 2 сторон.
		"size": 7, "escape": "corner", "king_armed": true,
		"throne_hostile": false, "king_capture": "custodial2",
		"label_ru": "Брандуб 7×7", "label_en": "Brandubh 7×7",
	},
	"tablut": {
		# §1: edge-escape, король вооружён; взятие локальное 4/3/2 (custodial2 +
		# эскалация у враждебного трона).
		"size": 9, "escape": "edge", "king_armed": true,
		"throne_hostile": true, "king_capture": "custodial2",
		"label_ru": "Таблут 9×9", "label_en": "Tablut 9×9",
	},
	"fetlar": {
		"size": 11, "escape": "corner", "king_armed": true,
		"throne_hostile": true, "king_capture": "surround4",
		"label_ru": "Фетлар 11×11", "label_en": "Fetlar 11×11",
	},
	"copenhagen": {
		# Современный турнирный стандарт (§9.3). Расстановка идентична Fetlar,
		# отличия — в правилах. repetition: вечный повтор = поражение белых
		# (защитников). shieldwall/exit_fort/encirclement активируются на Этапе 3.
		"size": 11, "escape": "corner", "king_armed": true,
		"throne_hostile": true, "king_capture": "surround4",
		"repetition": "white_loss",
		"shieldwall": true, "exit_fort": true, "encirclement": true,
		"label_ru": "Копенгаген 11×11", "label_en": "Copenhagen 11×11",
	},
}

# Стартовые расстановки (x, y). Король всегда в центре.
const SETUP := {
	"brandubh": {
		"defenders": [[3,2],[3,4],[2,3],[4,3]],
		"attackers": [[3,0],[3,1],[3,5],[3,6],[0,3],[1,3],[5,3],[6,3]],
	},
	"tablut": {
		"defenders": [[4,2],[4,3],[4,5],[4,6],[2,4],[3,4],[5,4],[6,4]],
		"attackers": [
			[3,0],[4,0],[5,0],[4,1], [3,8],[4,8],[5,8],[4,7],
			[0,3],[0,4],[0,5],[1,4], [8,3],[8,4],[8,5],[7,4],
		],
	},
	"fetlar": {
		"defenders": [[5,3],[5,4],[5,6],[5,7],[3,5],[4,5],[6,5],[7,5],[4,4],[6,4],[4,6],[6,6]],
		"attackers": [
			[3,0],[4,0],[5,0],[6,0],[7,0],[5,1],
			[3,10],[4,10],[5,10],[6,10],[7,10],[5,9],
			[0,3],[0,4],[0,5],[0,6],[0,7],[1,5],
			[10,3],[10,4],[10,5],[10,6],[10,7],[9,5],
		],
	},
}


static func get_variant(id: String) -> Dictionary:
	return VARIANTS.get(id, VARIANTS["fetlar"])


static func size_of(id: String) -> int:
	return int(get_variant(id).size)


## Собирает стартовое GameState для варианта. Осаждающие ходят первыми.
static func build_state(id: String) -> Object:
	var v: Dictionary = get_variant(id)
	var size: int = int(v.size)
	# Copenhagen использует ту же стартовую позицию, что и Fetlar (§9.1).
	var setup_id: String = "fetlar" if id == "copenhagen" else id
	var s = GameStateScript.new()
	s.king = (size / 2) * size + (size / 2)
	for p in SETUP[setup_id]["defenders"]:
		s.defenders[p[1] * size + p[0]] = true
	for p in SETUP[setup_id]["attackers"]:
		s.attackers[p[1] * size + p[0]] = true
	s.turn = "attackers"
	return s

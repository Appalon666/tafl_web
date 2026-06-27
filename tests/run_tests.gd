extends SceneTree
## Headless-тесты движка Тафла. Запуск:
##   godot --headless --script res://tests/run_tests.gd
## Растёт по мере этапов разработки. Каждый этап — своя секция тестов.

const TaflBoard = preload("res://scripts/core/TaflBoard.gd")
const TaflVariants = preload("res://scripts/core/TaflVariants.gd")
const RulesEngine = preload("res://scripts/core/RulesEngine.gd")
const GameState = preload("res://scripts/core/GameState.gd")
const TaflAI = preload("res://scripts/ai/TaflAI.gd")

var _passed := 0
var _failed := 0
var _section := ""


func _init() -> void:
	test_stage0_king_capture()
	test_stage1_variants()
	test_stage2_copenhagen()
	test_stage3_advanced()
	test_stage4_ai()
	_summary()
	quit(0 if _failed == 0 else 1)


# ---------------------------------------------------------------- утилиты

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_section, msg])


func _section_begin(name: String) -> void:
	_section = name
	print("== %s ==" % name)


func _summary() -> void:
	print("\n---- %d passed, %d failed ----" % [_passed, _failed])
	if _failed == 0:
		print("ALL_TESTS_OK")


## Строит state с королём и фигурами на доске size×size (idx = y*size + x).
func _mk_state(size: int, king_xy: Array, attackers: Array, defenders: Array) -> Object:
	var s = GameState.new()
	s.king = king_xy[1] * size + king_xy[0]
	for p in attackers:
		s.attackers[p[1] * size + p[0]] = true
	for p in defenders:
		s.defenders[p[1] * size + p[0]] = true
	s.turn = "attackers"
	return s


## Создаёт RulesEngine для произвольного варианта-словаря на доске size.
func _mk_rules(size: int, variant: Dictionary):
	var b = TaflBoard.new(size)
	return RulesEngine.new(b, variant)


# ---------------------------------------------------------------- ЭТАП 0

func test_stage0_king_capture() -> void:
	_section_begin("Этап 0: king_capture конфиг-управляем")

	# --- surround4 (сильный король, Fetlar/Copenhagen) ---
	var v_s4 := {"king_capture": "surround4", "throne_hostile": true, "king_armed": true}

	# Король в центре 7×7 (3,3), окружён 4 осаждающими → взят.
	var r = _mk_rules(7, v_s4)
	var s = _mk_state(7, [3, 3], [[2, 3], [4, 3], [3, 2], [3, 4]], [])
	_ok(r._king_captured(s), "surround4: 4 осаждающих вокруг центра → взят")

	# Только 3 осаждающих → НЕ взят.
	s = _mk_state(7, [3, 3], [[2, 3], [4, 3], [3, 2]], [])
	_ok(not r._king_captured(s), "surround4: 3 осаждающих → НЕ взят")

	# Король у кромки (3,0), окружён с доступных сторон → НЕ взят (иммунитет кромки).
	s = _mk_state(7, [3, 0], [[2, 0], [4, 0], [3, 1]], [])
	_ok(not r._king_captured(s), "surround4: король у кромки → НЕ взят")

	# Король рядом с троном (центр 7×7 = (3,3)); король на (3,2), трон пуст снизу,
	# 3 осаждающих с других сторон → трон закрывает 4-ю → взят (правило «3+трон»).
	s = _mk_state(7, [3, 2], [[2, 2], [4, 2], [3, 1]], [])
	_ok(r._king_captured(s), "surround4: 3 осаждающих + пустой трон → взят")

	# --- custodial2 (слабый король, Brandubh / Tablut в поле) ---
	var v_c2 := {"king_capture": "custodial2", "throne_hostile": false, "king_armed": true}
	r = _mk_rules(7, v_c2)

	# Король в поле (2,2), зажат слева/справа → взят (2 стороны).
	s = _mk_state(7, [2, 2], [[1, 2], [3, 2]], [])
	_ok(r._king_captured(s), "custodial2: зажат с 2 противоположных сторон → взят")

	# Только перпендикулярные соседи (не противоположные) → НЕ взят.
	s = _mk_state(7, [2, 2], [[1, 2], [2, 1]], [])
	_ok(not r._king_captured(s), "custodial2: 2 соседа под углом → НЕ взят")

	# Один сосед → НЕ взят.
	s = _mk_state(7, [2, 2], [[1, 2]], [])
	_ok(not r._king_captured(s), "custodial2: 1 сосед → НЕ взят")

	# throne_hostile=false (Brandubh): король на троне (3,3), зажат с 2 сторон → взят
	# (без эскалации до 4, т.к. трон не враждебен).
	s = _mk_state(7, [3, 3], [[2, 3], [4, 3]], [])
	_ok(r._king_captured(s), "custodial2 (throne не враждебен): на троне 2 стороны → взят")

	# --- custodial2 c throne_hostile=true (Tablut): эскалация у трона ---
	var v_tab := {"king_capture": "custodial2", "throne_hostile": true, "king_armed": true}
	r = _mk_rules(9, v_tab)
	var tc := 4  # центр 9×9

	# Король рядом с троном (4,3): нужно полное окружение. Трон снизу пуст + 3
	# осаждающих → взят.
	s = _mk_state(9, [4, 3], [[3, 3], [5, 3], [4, 2]], [])
	_ok(r._king_captured(s), "Tablut: у трона 3 осаждающих + трон → взят")

	# Король рядом с троном (4,3), только 2 противоположных осаждающих → НЕ взят
	# (в поле хватило бы 2, но у трона нужно полное окружение).
	s = _mk_state(9, [4, 3], [[3, 3], [5, 3]], [])
	_ok(not r._king_captured(s), "Tablut: у трона 2 стороны → НЕ взят (нужно окружение)")

	# Король в чистом поле (2,2), 2 противоположных осаждающих → взят (custodial 2).
	s = _mk_state(9, [2, 2], [[1, 2], [3, 2]], [])
	_ok(r._king_captured(s), "Tablut: в поле 2 стороны → взят")

	# --- интеграция через apply(): король берётся только ходом осаждающих ---
	r = _mk_rules(7, v_s4)
	# Король (3,3)=idx24, 3 осаждающих на местах, 4-й заходит ходом снизу (3,5)->(3,4).
	s = _mk_state(7, [3, 3], [[2, 3], [4, 3], [3, 2], [3, 5]], [])
	s.turn = "attackers"
	var caps: Array = r.apply(s, {"from": 5 * 7 + 3, "to": 4 * 7 + 3})  # (3,5)->(3,4)
	_ok(s.king == -1 and caps.has(3 * 7 + 3), "apply: осаждающий замыкает окружение → король взят")
	_ok(r.check_winner(s) == "attackers", "apply: после взятия короля победа осаждающих")


# ---------------------------------------------------------------- ЭТАП 1

func test_stage1_variants() -> void:
	_section_begin("Этап 1: корректность вариантов")

	# --- расстановки и счёт фигур (§9.1) ---
	var brand = TaflVariants.build_state("brandubh")
	_ok(brand.defenders.size() == 4 and brand.attackers.size() == 8,
		"Brandubh: 4 защитника, 8 осаждающих")
	_ok(brand.king == 3 * 7 + 3, "Brandubh: король в центре (3,3)")
	_ok(brand.turn == "attackers", "Brandubh: осаждающие ходят первыми")

	var tab = TaflVariants.build_state("tablut")
	_ok(tab.defenders.size() == 8 and tab.attackers.size() == 16,
		"Tablut: 8 защитников, 16 осаждающих (исправлено: 4 группы по 4 — это осаждающие)")
	_ok(tab.king == 4 * 9 + 4, "Tablut: король в центре (4,4)")

	var fet = TaflVariants.build_state("fetlar")
	_ok(fet.defenders.size() == 12 and fet.attackers.size() == 24,
		"Fetlar: 12 защитников, 24 осаждающих")

	# --- Brandubh: флаги и взятие короля 2 стороны, трон НЕ враждебен ---
	var vb := TaflVariants.get_variant("brandubh")
	_ok(not bool(vb.throne_hostile), "Brandubh: трон НЕ враждебен")
	_ok(String(vb.king_capture) == "custodial2", "Brandubh: king_capture=custodial2")

	var rb = _mk_rules(7, vb)
	# Король на троне (3,3), зажат слева/справа → взят (2 стороны, без эскалации).
	var s = _mk_state(7, [3, 3], [[2, 3], [4, 3]], [])
	_ok(rb._king_captured(s), "Brandubh: король на троне зажат с 2 сторон → взят")
	# Пустой трон НЕ помогает взятию обычной фигуры (throne_hostile=false):
	# защитник у трона (3,2) зажат осаждающим сверху (3,1) и троном снизу — НЕ взят.
	s = _mk_state(7, [4, 4], [[3, 1]], [[3, 2]])  # король в стороне
	s.turn = "attackers"
	var caps2: Array = rb._captures_from(s, 3 * 7 + 1, "attackers")
	_ok(not caps2.has(2 * 7 + 3), "Brandubh: пустой трон НЕ наковальня (throne_hostile=false)")

	# --- Tablut: локальное 4/3/2 на реальном варианте ---
	var vt := TaflVariants.get_variant("tablut")
	_ok(String(vt.king_capture) == "custodial2" and bool(vt.throne_hostile),
		"Tablut: custodial2 + throne_hostile (даёт 4/3/2)")
	var rt = _mk_rules(9, vt)
	# Король в чистом поле (2,2) зажат с 2 сторон → взят.
	s = _mk_state(9, [2, 2], [[1, 2], [3, 2]], [])
	_ok(rt._king_captured(s), "Tablut: в поле 2 стороны → взят")
	# Король рядом с троном (центр (4,4)); на (4,3) с 2 сторонами → НЕ взят.
	s = _mk_state(9, [4, 3], [[3, 3], [5, 3]], [])
	_ok(not rt._king_captured(s), "Tablut: у трона 2 стороны мало → НЕ взят")
	# Tablut edge-escape сохранён.
	_ok(String(vt.escape) == "edge", "Tablut: edge-escape сохранён")


# ---------------------------------------------------------------- ЭТАП 2

func test_stage2_copenhagen() -> void:
	_section_begin("Этап 2: Copenhagen + дефолт 11×11 + запрет повторений")

	# --- вариант существует, флаги верны ---
	var vc := TaflVariants.get_variant("copenhagen")
	_ok(int(vc.size) == 11, "Copenhagen: доска 11×11")
	_ok(String(vc.king_capture) == "surround4", "Copenhagen: сильный король (surround4)")
	_ok(String(vc.get("repetition", "")) == "white_loss", "Copenhagen: repetition=white_loss")

	# --- стартовая позиция идентична Fetlar (§9.1) ---
	var cop = TaflVariants.build_state("copenhagen")
	var fet = TaflVariants.build_state("fetlar")
	_ok(cop.king == fet.king, "Copenhagen: король там же, что и в Fetlar")
	var ca: Array = cop.attackers.keys(); ca.sort()
	var fa: Array = fet.attackers.keys(); fa.sort()
	var cd: Array = cop.defenders.keys(); cd.sort()
	var fd: Array = fet.defenders.keys(); fd.sort()
	_ok(str(ca) == str(fa) and str(cd) == str(fd),
		"Copenhagen: стартовая расстановка == Fetlar (24 осаждающих / 12 защитников)")

	# --- дефолт 11×11 = copenhagen ---
	var gc = load("res://scripts/systems/GameConfig.gd").new()
	_ok(String(gc.variant) == "copenhagen", "GameConfig: дефолтный вариант = copenhagen")
	gc.free()

	# --- запрет повторений: вечный повтор → поражение белых (победа осаждающих) ---
	var rc = _mk_rules(11, vc)
	# Изолированные фигуры далеко друг от друга — челночат без взятий.
	var s = _mk_state(11, [5, 5], [[0, 5]], [[10, 5]])
	s.turn = "attackers"
	var cycle := [
		{"from": 5 * 11 + 0, "to": 6 * 11 + 0},    # осаждающий (0,5)->(0,6)
		{"from": 5 * 11 + 10, "to": 6 * 11 + 10},  # защитник   (10,5)->(10,6)
		{"from": 6 * 11 + 0, "to": 5 * 11 + 0},    # осаждающий (0,6)->(0,5)
		{"from": 6 * 11 + 10, "to": 5 * 11 + 10},  # защитник   (10,6)->(10,5)
	]
	var winner := ""
	for i in range(24):
		rc.apply(s, cycle[i % 4])
		winner = rc.check_winner(s)
		if winner != "":
			break
	_ok(winner == "attackers", "Copenhagen: троекратный повтор позиции → победа осаждающих")

	# --- у вариантов без repetition повтор НЕ карается ---
	var rf = _mk_rules(11, TaflVariants.get_variant("fetlar"))
	var s2 = _mk_state(11, [5, 5], [[0, 5]], [[10, 5]])
	s2.turn = "attackers"
	var w2 := ""
	for i in range(12):
		rf.apply(s2, cycle[i % 4])
		w2 = rf.check_winner(s2)
		if w2 != "":
			break
	_ok(w2 == "", "Fetlar: повтор позиции НЕ карается (нет repetition-флага)")


# ---------------------------------------------------------------- ЭТАП 3

func test_stage3_advanced() -> void:
	_section_begin("Этап 3: shieldwall / exit-fort / encirclement")

	var vc := TaflVariants.get_variant("copenhagen")
	var rc = _mk_rules(11, vc)

	# --- SHIELDWALL: ряд из 2 защитников вдоль нижней кромки, осаждающий замыкает ---
	# Защитники (3,0),(4,0); фронты-осаждающие (3,1),(4,1); левый торец (2,0);
	# осаждающий (6,0)->(5,0) замыкает правый торец.
	var s = _mk_state(11, [5, 5], [[2, 0], [3, 1], [4, 1], [6, 0]], [[3, 0], [4, 0]])
	s.turn = "attackers"
	var caps: Array = rc.apply(s, {"from": 0 * 11 + 6, "to": 0 * 11 + 5})  # (6,0)->(5,0)
	_ok(caps.has(3) and caps.has(4) and not s.defenders.has(3) and not s.defenders.has(4),
		"shieldwall: ряд защитников у кромки взят целиком")

	# Король в стене НЕ берётся, соседний защитник — берётся.
	s = _mk_state(11, [4, 0], [[2, 0], [3, 1], [4, 1], [6, 0]], [[3, 0]])
	s.turn = "attackers"
	caps = rc.apply(s, {"from": 0 * 11 + 6, "to": 0 * 11 + 5})
	_ok(s.king == 4 and caps.has(3) and not s.defenders.has(3),
		"shieldwall: король в ряду уцелел, защитник взят")

	# Дырка во фронте (нет (4,1)) → стена не срабатывает.
	s = _mk_state(11, [5, 5], [[2, 0], [3, 1], [6, 0]], [[3, 0], [4, 0]])
	s.turn = "attackers"
	caps = rc.apply(s, {"from": 0 * 11 + 6, "to": 0 * 11 + 5})
	_ok(not caps.has(3) and not caps.has(4) and s.defenders.has(3) and s.defenders.has(4),
		"shieldwall: дырка во фронте → нет взятия")

	# --- EXIT-FORT: непробиваемая крепость у левой кромки ---
	# Король (0,5) может ходить на (0,4); регион {(0,5),(0,4)} запечатан защитниками.
	s = _mk_state(11, [0, 5], [[8, 8], [9, 9]], [[0, 6], [1, 5], [0, 3], [1, 4]])
	s.turn = "defenders"
	_ok(rc.check_winner(s) == "defenders", "exit-fort: запечатанная крепость → победа защитников")

	# Дыра в стене (нет (0,6)) → крепость пробиваема → не победа.
	s = _mk_state(11, [0, 5], [[8, 8], [9, 9]], [[1, 5], [0, 3], [1, 4]])
	s.turn = "defenders"
	_ok(rc.check_winner(s) != "defenders", "exit-fort: дыра в стене → не победа")

	# --- ENCIRCLEMENT: кольцо осаждающих вокруг короля ---
	var ring: Array = []
	for x in range(3, 8):
		for y in range(3, 8):
			if x == 3 or x == 7 or y == 3 or y == 7:
				ring.append([x, y])
	s = _mk_state(11, [5, 5], ring, [])
	s.turn = "attackers"
	_ok(rc.check_winner(s) == "attackers", "encirclement: кольцо осады → победа осаждающих")
	# Король при этом НЕ окружён кустодиально (соседи пусты) — это именно кольцо.
	_ok(not rc._king_captured(s), "encirclement: король не зажат (это кольцо, а не surround)")

	# Стартовая позиция Copenhagen — НЕ окружена.
	var start = TaflVariants.build_state("copenhagen")
	_ok(rc.check_winner(start) == "", "encirclement: старт Copenhagen НЕ окружён, партия идёт")

	# --- Fetlar (без флагов) не реагирует на кольцо/стену/форт ---
	var rf = _mk_rules(11, TaflVariants.get_variant("fetlar"))
	_ok(rf.check_winner(s) != "attackers", "Fetlar: кольцо НЕ засчитывается (нет encirclement)")


# ---------------------------------------------------------------- ЭТАП 4

func test_stage4_ai() -> void:
	_section_begin("Этап 4: сильный ИИ (alpha-beta + эвристики)")

	# Вариант без тяжёлых флагов (быстрый перебор), слабый король custodial2.
	var v2 := {"king_capture": "custodial2", "throne_hostile": false,
		"king_armed": true, "escape": "corner"}
	var r = _mk_rules(7, v2)

	# --- мат в 1 за осаждающих: зажать короля ---
	# Король (2,2), осаждающий слева (1,2); ходящий (3,5)->(3,2) замыкает зажим.
	var ai = TaflAI.new(2, 2000)
	var s = _mk_state(7, [2, 2], [[1, 2], [3, 5]], [])
	s.turn = "attackers"
	var mv = ai.choose_move(r, s)
	var c = s.clone()
	r.apply(c, mv)
	_ok(c.king == -1, "ИИ (осада): находит взятие короля в 1 ход")

	# --- предпочтение взятия фигуры ---
	# Защитник (4,4), осаждающий (3,4); ход (5,6)->(5,4) бьёт защитника.
	s = _mk_state(7, [0, 4], [[3, 4], [5, 6]], [[4, 4]])  # король сбоку, в безопасности
	s.turn = "attackers"
	mv = ai.choose_move(r, s)
	c = s.clone()
	var caps: Array = r.apply(c, mv)
	_ok(caps.size() >= 1, "ИИ (осада): предпочитает взять свободную фигуру")

	# --- мат в 1 за защитников: увести короля в угол ---
	# Король (0,3) у левой кромки, путь к углу (0,0) свободен.
	s = _mk_state(7, [0, 3], [[6, 6]], [])
	s.turn = "defenders"
	mv = ai.choose_move(r, s)
	c = s.clone()
	r.apply(c, mv)
	_ok(r.check_winner(c) == "defenders", "ИИ (защита): уводит короля в угол → победа")

	# --- ИИ не «суицидит» королём под зажим (мат в 2) ---
	# Король (3,3); осаждающие (1,3) и (5,3) на линии. Глупый ход короля на (2,3)
	# или (4,3) даёт зажим на след. ходу. ИИ защиты должен этого избежать.
	s = _mk_state(7, [3, 3], [[1, 3], [5, 3], [3, 6]], [])
	s.turn = "defenders"
	var ai3 = TaflAI.new(3, 3000)
	mv = ai3.choose_move(r, s)
	_ok(mv != null and mv.to != 3 * 7 + 2 and mv.to != 3 * 7 + 4,
		"ИИ (защита): не подставляет короля под зажим")

	# --- возвращает легальный ход на старте Brandubh ---
	var rb = _mk_rules(7, TaflVariants.get_variant("brandubh"))
	var ai2 = TaflAI.new(2, 2000)
	var st = TaflVariants.build_state("brandubh")
	mv = ai2.choose_move(rb, st)
	var legal := false
	for lm in rb.moves_for_side(st, st.turn):
		if lm.from == mv.from and lm.to == mv.to:
			legal = true
			break
	_ok(mv != null and legal, "ИИ: возвращает легальный ход на старте Brandubh")

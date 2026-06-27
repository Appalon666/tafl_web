extends RefCounted
## Правила Тафла (универсальные, управляются флагами варианта).
## Не знает о визуале. Берёт TaflBoard и словарь варианта (см. TaflVariants).
##
## Базовые механики (общие для всех вариантов):
##  • Ход: ортогональный слайд на любое число клеток (как ладья), без прыжков.
##  • Солдаты не встают на трон/углы; король — может.
##  • Взятие: custodial — зажать врага между своей фигурой и своей фигурой/
##    враждебной клеткой (угол; пустой трон). За один ход можно взять несколько.
##  • Король берётся окружением с 4 ортогональных сторон (стена = осаждающий/трон).
##  • Победа: осаждающие — взять короля; защитники — увести короля (угол/кромка).

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DRAW_LIMIT := 100  # полуходов без взятия → ничья

var board                 # TaflBoard
var v: Dictionary         # словарь варианта


func _init(board_ref, variant: Dictionary) -> void:
	board = board_ref
	v = variant


# ---------------------------------------------------------------- ходы

func legal_moves(state, from_idx: int) -> Array:
	var out: Array = []
	var is_k: bool = state.is_king(from_idx)
	var c: Vector2i = board.xy(from_idx)
	for d in DIRS:
		var nx: int = c.x + d.x
		var ny: int = c.y + d.y
		while board.in_board(nx, ny):
			var nidx: int = board.index(nx, ny)
			if state.is_occupied(nidx):
				break  # путь блокирован — прыгать нельзя
			# Солдат не может встать на трон/угол; король — может.
			if is_k or not board.is_special(nidx):
				out.append(nidx)
			nx += d.x
			ny += d.y
	return out


func moves_for_side(state, side: String) -> Array:
	var out: Array = []
	for idx in _pieces_of(state, side):
		for to in legal_moves(state, idx):
			out.append({"from": idx, "to": to})
	return out


func _pieces_of(state, side: String) -> Array:
	var out: Array = []
	if side == "attackers":
		out = state.attackers.keys()
	else:
		out = state.defenders.keys()
		if state.king != -1:
			out.append(state.king)
	return out


# ---------------------------------------------------------------- применение хода

## Применяет ход (мутирует state), возвращает список взятых клеток. Переключает ход.
func apply(state, move) -> Array:
	var side: String = state.turn
	var from_idx: int = move.from
	var to: int = move.to
	# Передвигаем фигуру.
	if state.king == from_idx:
		state.king = to
	elif side == "attackers":
		state.attackers.erase(from_idx)
		state.attackers[to] = true
	else:
		state.defenders.erase(from_idx)
		state.defenders[to] = true

	var captured: Array = _captures_from(state, to, side)
	for cap in captured:
		state.attackers.erase(cap)
		state.defenders.erase(cap)

	# Shieldwall-взятие (Copenhagen): ряд вдоль кромки, зажатый с торцов.
	if bool(v.get("shieldwall", false)):
		for cap in _shieldwall_captures(state, to, side):
			if cap == state.king:
				continue  # король в стене не берётся
			state.attackers.erase(cap)
			state.defenders.erase(cap)
			if not captured.has(cap):
				captured.append(cap)

	# Король берётся только на ходу осаждающих.
	if side == "attackers" and state.king != -1 and _king_captured(state):
		captured.append(state.king)
		state.king = -1

	state.moves_no_capture = 0 if not captured.is_empty() else state.moves_no_capture + 1
	state.turn = "defenders" if side == "attackers" else "attackers"

	# Учёт повторений (Copenhagen): считаем получившуюся позицию.
	if String(v.get("repetition", "")) == "white_loss":
		var key: String = state.position_key()
		state.position_counts[key] = int(state.position_counts.get(key, 0)) + 1

	return captured


## Custodial-взятие: фигура на `to` — «молот», враг рядом, за ним «наковальня».
func _captures_from(state, to: int, side: String) -> Array:
	var out: Array = []
	var c: Vector2i = board.xy(to)
	for d in DIRS:
		var ax: int = c.x + d.x
		var ay: int = c.y + d.y
		if not board.in_board(ax, ay):
			continue
		var adj: int = board.index(ax, ay)
		# Враг рядом (короля так не берут — у него своё правило).
		if state.side_at(adj) == "" or state.side_at(adj) == side or adj == state.king:
			continue
		var bx: int = ax + d.x
		var by: int = ay + d.y
		if not board.in_board(bx, by):
			continue
		var beyond: int = board.index(bx, by)
		if _is_anvil(state, beyond, side):
			out.append(adj)
	return out


## «Наковальня»: своя фигура за врагом, либо враждебная клетка (угол / пустой трон).
func _is_anvil(state, idx: int, side: String) -> bool:
	if board.is_corner(idx):
		return true
	if board.is_throne(idx) and bool(v.get("throne_hostile", true)) and not state.is_occupied(idx):
		return true
	if side == "attackers":
		return state.attackers.has(idx)
	# Защитники: своя фигура или вооружённый король.
	if state.defenders.has(idx):
		return true
	return idx == state.king and bool(v.get("king_armed", true))


## Король взят? Зависит от флага варианта `king_capture`:
##  • "surround4" — сильный король (Fetlar/Copenhagen): окружён со ВСЕХ
##    ортогональных сторон (стена = осаждающий или враждебный пустой трон);
##    у кромки взять нельзя. Рядом с троном пустой трон закрывает одну сторону
##    → эффективно «3 осаждающих + трон».
##  • "custodial2" — слабый король (Brandubh/Tablut в поле): берётся
##    кустодиально, как обычная фигура (зажат с 2 противоположных сторон).
##    Если трон враждебен и король на троне/рядом — требуется полное окружение
##    (правило Tablut: трон 4 / у трона 3 / поле 2).
func _king_captured(state) -> bool:
	var mode: String = String(v.get("king_capture", "surround4"))
	if mode == "custodial2":
		if bool(v.get("throne_hostile", true)) and _king_near_throne(state):
			return _king_surrounded_full(state)
		return _king_custodial(state)
	return _king_surrounded_full(state)


## Король на троне или ортогонально рядом с ним.
func _king_near_throne(state) -> bool:
	if board.is_throne(state.king):
		return true
	var c: Vector2i = board.xy(state.king)
	for d in DIRS:
		if board.in_board(c.x + d.x, c.y + d.y) and board.is_throne(board.index(c.x + d.x, c.y + d.y)):
			return true
	return false


## Полное окружение: все ортогональные соседи — «стена»; у кромки невозможно.
func _king_surrounded_full(state) -> bool:
	if board.is_edge(state.king):
		return false  # короля у кромки взять нельзя (Copenhagen) / окружить (Fetlar)
	var c: Vector2i = board.xy(state.king)
	for d in DIRS:
		var nidx: int = board.index(c.x + d.x, c.y + d.y)
		if not _is_king_wall(state, nidx):
			return false
	return true


## Кустодиальное взятие короля: зажат с 2 противоположных сторон по одной оси.
func _king_custodial(state) -> bool:
	var c: Vector2i = board.xy(state.king)
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var a := Vector2i(c.x + axis.x, c.y + axis.y)
		var b := Vector2i(c.x - axis.x, c.y - axis.y)
		if board.in_board(a.x, a.y) and board.in_board(b.x, b.y) \
				and _is_king_wall(state, board.index(a.x, a.y)) \
				and _is_king_wall(state, board.index(b.x, b.y)):
			return true
	return false


## Клетка — «стена» для взятия короля: осаждающий, угол, либо враждебный пустой трон.
func _is_king_wall(state, idx: int) -> bool:
	if state.attackers.has(idx):
		return true
	if board.is_corner(idx):
		return true
	return board.is_throne(idx) and bool(v.get("throne_hostile", true)) and not state.is_occupied(idx)


# ---------------------------------------------------------------- победа

## "attackers" | "defenders" | "draw" | "" (партия продолжается).
func check_winner(state) -> String:
	if state.king == -1:
		return "attackers"
	if _king_escaped(state):
		return "defenders"
	# Copenhagen: король у кромки в непробиваемой крепости → победа защитников.
	if bool(v.get("exit_fort", false)) and _exit_fort(state):
		return "defenders"
	# Copenhagen: осаждающие окружили короля и всех защитников → их победа.
	if bool(v.get("encirclement", false)) and _encircled(state):
		return "attackers"
	# Copenhagen: вечный повтор позиции = поражение белых (защитников).
	if String(v.get("repetition", "")) == "white_loss":
		if int(state.position_counts.get(state.position_key(), 0)) >= 3:
			return "attackers"
	if state.moves_no_capture >= DRAW_LIMIT:
		return "draw"
	# Нет ходов у стороны — она проигрывает.
	if moves_for_side(state, state.turn).is_empty():
		return "defenders" if state.turn == "attackers" else "attackers"
	return ""


func _king_escaped(state) -> bool:
	if state.king == -1:
		return false
	if String(v.get("escape", "corner")) == "corner":
		return board.is_corner(state.king)
	return board.is_edge(state.king)  # edge-escape (Tablut)


# ---------------------------------------------------------------- Этап 3: Copenhagen

## Фигура принадлежит стороне (для защитников король — тоже «свой»).
func _belongs(state, idx: int, side: String) -> bool:
	if side == "attackers":
		return state.attackers.has(idx)
	return state.defenders.has(idx) or idx == state.king


## Shieldwall (rule 4b): ряд из ≥2 врагов вдоль кромки, у каждого враг «спереди»
## (к центру), скобки на обоих торцах (своя фигура; угол заменяет один торец).
## `to` — только что сходившая «своя» фигура = ближний торец скобки.
func _shieldwall_captures(state, to: int, side: String) -> Array:
	var c: Vector2i = board.xy(to)
	var out: Array = []
	for e in _edge_orientations(c):
		out += _scan_shieldwall(state, c, e.along, e.inward, side)
		out += _scan_shieldwall(state, c, -e.along, e.inward, side)
	return out


## Ориентации кромок, на которых лежит клетка (углы → две).
func _edge_orientations(c: Vector2i) -> Array:
	var out: Array = []
	var n: int = board.size - 1
	if c.y == 0:
		out.append({"along": Vector2i(1, 0), "inward": Vector2i(0, 1)})
	if c.y == n:
		out.append({"along": Vector2i(1, 0), "inward": Vector2i(0, -1)})
	if c.x == 0:
		out.append({"along": Vector2i(0, 1), "inward": Vector2i(1, 0)})
	if c.x == n:
		out.append({"along": Vector2i(0, 1), "inward": Vector2i(-1, 0)})
	return out


## Сканирует ряд жертв от торца `start_c` в направлении `step` вдоль кромки.
func _scan_shieldwall(state, start_c: Vector2i, step: Vector2i, inward: Vector2i, side: String) -> Array:
	var victims: Array = []
	var p: Vector2i = start_c + step
	while board.in_board(p.x, p.y):
		var idx: int = board.index(p.x, p.y)
		var os: String = state.side_at(idx)
		if os != "" and os != side:
			# Враг-жертва: нужен «свой» строго спереди (к центру).
			var f: Vector2i = p + inward
			if not board.in_board(f.x, f.y):
				return []
			if not _belongs(state, board.index(f.x, f.y), side):
				return []
			victims.append(idx)
			p += step
		elif _belongs(state, idx, side) or board.is_corner(idx):
			return victims if victims.size() >= 2 else []  # дальний торец скобки
		else:
			return []  # пусто/чужой-без-фронта → скобка не замкнута
	return []  # ушли за доску без торца


## Exit fort (rule 6b): король касается кромки, может ходить, крепость непробиваема.
func _exit_fort(state) -> bool:
	if not board.is_edge(state.king):
		return false
	if legal_moves(state, state.king).is_empty():
		return false  # «able to move»
	# Регион: король + связные пустые клетки. Атакующий рядом с регионом → пробиваемо.
	var region: Dictionary = {state.king: true}
	var stack: Array = [state.king]
	while not stack.is_empty():
		var cc: Vector2i = board.xy(stack.pop_back())
		for d in DIRS:
			var nx: int = cc.x + d.x
			var ny: int = cc.y + d.y
			if not board.in_board(nx, ny):
				continue
			var nidx: int = board.index(nx, ny)
			if region.has(nidx):
				continue
			if state.attackers.has(nidx):
				return false  # осаждающий внутри/касается региона
			if state.defenders.has(nidx):
				continue  # защитник — стена, в регион не входит
			region[nidx] = true
			stack.append(nidx)
	# Стены-защитники должны быть невзимаемы.
	for cell in region.keys():
		var cc: Vector2i = board.xy(cell)
		for d in DIRS:
			var nx: int = cc.x + d.x
			var ny: int = cc.y + d.y
			if not board.in_board(nx, ny):
				continue
			var nidx: int = board.index(nx, ny)
			if state.defenders.has(nidx) and _wall_vulnerable(state, nidx):
				return false
	return true


## Защитник может быть взят кустодиально следующим ходом (один торец — осаждающий,
## противоположный — пустая клетка, куда осаждающий может зайти). Консервативно.
func _wall_vulnerable(state, didx: int) -> bool:
	var cc: Vector2i = board.xy(didx)
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var a := Vector2i(cc.x + axis.x, cc.y + axis.y)
		var b := Vector2i(cc.x - axis.x, cc.y - axis.y)
		if not (board.in_board(a.x, a.y) and board.in_board(b.x, b.y)):
			continue
		var ai: int = board.index(a.x, a.y)
		var bi: int = board.index(b.x, b.y)
		if state.attackers.has(ai) and state.side_at(bi) == "":
			return true
		if state.attackers.has(bi) and state.side_at(ai) == "":
			return true
	return false


## Encirclement («David Brown», rule 7): осаждающие сплошным кольцом отрезали
## короля и всех защитников от кромки. Заливка от кромки через не-атакующие клетки:
## если так не достать ни короля, ни одного защитника — они окружены.
func _encircled(state) -> bool:
	var seen: Dictionary = {}
	var stack: Array = []
	var n: int = board.size
	for i in range(n):
		for idx in [board.index(i, 0), board.index(i, n - 1), board.index(0, i), board.index(n - 1, i)]:
			if not state.attackers.has(idx) and not seen.has(idx):
				seen[idx] = true
				stack.append(idx)
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		if cur == state.king or state.defenders.has(cur):
			return false  # достижимы от кромки → не окружены
		var cc: Vector2i = board.xy(cur)
		for d in DIRS:
			var nx: int = cc.x + d.x
			var ny: int = cc.y + d.y
			if not board.in_board(nx, ny):
				continue
			var nidx: int = board.index(nx, ny)
			if seen.has(nidx) or state.attackers.has(nidx):
				continue
			seen[nidx] = true
			stack.append(nidx)
	return true

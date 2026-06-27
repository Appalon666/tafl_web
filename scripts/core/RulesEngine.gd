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

	# Король берётся только на ходу осаждающих (окружением).
	if side == "attackers" and state.king != -1 and _king_surrounded(state):
		captured.append(state.king)
		state.king = -1

	state.moves_no_capture = 0 if not captured.is_empty() else state.moves_no_capture + 1
	state.turn = "defenders" if side == "attackers" else "attackers"
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


## Король окружён с 4 сторон (стена = осаждающий или клетка трона).
func _king_surrounded(state) -> bool:
	var c: Vector2i = board.xy(state.king)
	for d in DIRS:
		var nx: int = c.x + d.x
		var ny: int = c.y + d.y
		if not board.in_board(nx, ny):
			return false  # король у кромки — не окружить (corner/edge-варианты)
		var nidx: int = board.index(nx, ny)
		if not (state.attackers.has(nidx) or board.is_throne(nidx)):
			return false
	return true


# ---------------------------------------------------------------- победа

## "attackers" | "defenders" | "draw" | "" (партия продолжается).
func check_winner(state) -> String:
	if state.king == -1:
		return "attackers"
	if _king_escaped(state):
		return "defenders"
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

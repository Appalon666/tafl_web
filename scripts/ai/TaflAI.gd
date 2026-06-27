extends RefCounted
## Сильный честный ИИ Тафла (§3, §9.5):
##   negamax + alpha-beta + iterative deepening + transposition table (Zobrist)
##   + move ordering (TT-move / captures / killers / history).
## Оценочная функция — по весам OpenTafl FishyEvaluator (нормировка §9.5):
##   материал, свобода короля, риск короля, дистанция до цели.
## Уровни сложности задаются ЧЕСТНО — глубиной/временем перебора, без читов.
## Интерфейс совместим с RandomAI: choose_move(rules, state).

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const WIN := 1000000      # терминальная оценка (выигрыш), > любой позиционной
const INF := 1 << 30

# Веса оценки (def-positive: + хорошо защитникам, − осаждающим).
const W_MATERIAL := 30    # за фигуру (защитник ценится 2×)
const W_KING_RISK := 45   # штраф за каждого осаждающего рядом с королём
const W_KING_GOAL := 120  # за каждую выигрышную клетку, доступную королю сейчас
const W_KING_MOB := 4     # за подвижность короля
const W_KING_DIST := 6    # штраф за дистанцию короля до ближайшей цели

var rules                  # RulesEngine
var board                  # TaflBoard
var max_depth: int
var time_budget_ms: int

var _z_atk: PackedInt64Array = PackedInt64Array()
var _z_def: PackedInt64Array = PackedInt64Array()
var _z_king: PackedInt64Array = PackedInt64Array()
var _z_turn: int = 0

var _tt: Dictionary = {}        # hash -> {depth, flag, score, move}
var _killers: Dictionary = {}   # depth -> [move, move]
var _history: Dictionary = {}   # "from,to" -> int
var _deadline: int = 0
var _stop: bool = false

# Статистика последнего поиска (для отладки/HUD).
var last_depth: int = 0
var last_nodes: int = 0


func _init(depth: int = 3, budget_ms: int = 1200) -> void:
	max_depth = depth
	time_budget_ms = budget_ms


# ---------------------------------------------------------------- публичный API

func choose_move(rules_ref, state):
	rules = rules_ref
	board = rules.board
	var n: int = board.size * board.size
	if _z_atk.size() != n:
		_init_zobrist(n)
	_tt.clear()
	_killers.clear()
	_history.clear()
	_stop = false
	_deadline = Time.get_ticks_msec() + time_budget_ms
	last_nodes = 0

	var best = null
	# Iterative deepening: каждая итерация улучшает порядок ходов через TT.
	for d in range(1, max_depth + 1):
		var res: Dictionary = _search_root(state, d)
		if _stop and res.move == null:
			break
		if res.move != null:
			best = res.move
			last_depth = d
		if not _stop and res.score >= WIN:
			break  # форсированный выигрыш найден — глубже не нужно
		if _stop:
			break

	if best == null:
		var ms: Array = rules.moves_for_side(state, state.turn)
		return ms[randi() % ms.size()] if not ms.is_empty() else null
	return best


# ---------------------------------------------------------------- поиск

func _search_root(state, depth: int) -> Dictionary:
	var alpha: int = -INF
	var beta: int = INF
	var best_move = null
	var best_score: int = -INF
	for m in _ordered_moves(state, depth, _tt_move(state)):
		var c = state.clone()
		rules.apply(c, m)
		var sc: int = -_negamax(c, depth - 1, -beta, -alpha, 1)
		if _stop:
			break
		if sc > best_score:
			best_score = sc
			best_move = m
		if sc > alpha:
			alpha = sc
	return {"move": best_move, "score": best_score}


func _negamax(state, depth: int, alpha: int, beta: int, ply: int) -> int:
	last_nodes += 1
	if (last_nodes & 1023) == 0 and Time.get_ticks_msec() > _deadline:
		_stop = true
		return 0

	var winner: String = rules.check_winner(state)
	if winner != "":
		if winner == "draw":
			return 0
		var val: int = WIN - ply  # ближе выигрыш — лучше
		return val if winner == state.turn else -val
	if depth <= 0:
		return _eval_stm(state)

	var alpha0: int = alpha
	var h: int = _hash(state)
	var tt = _tt.get(h)
	var tt_move = null
	if tt != null and int(tt.depth) >= depth:
		match int(tt.flag):
			0: return int(tt.score)            # exact
			-1: alpha = max(alpha, int(tt.score))  # lower bound
			1: beta = min(beta, int(tt.score))     # upper bound
		if alpha >= beta:
			return int(tt.score)
	if tt != null:
		tt_move = tt.move

	var best: int = -INF
	var best_move = null
	for m in _ordered_moves(state, depth, tt_move):
		var c = state.clone()
		rules.apply(c, m)
		var sc: int = -_negamax(c, depth - 1, -beta, -alpha, ply + 1)
		if _stop:
			return best if best > -INF else 0
		if sc > best:
			best = sc
			best_move = m
		if sc > alpha:
			alpha = sc
		if alpha >= beta:
			_record_killer(depth, m)
			var key: String = "%d,%d" % [m.from, m.to]
			_history[key] = int(_history.get(key, 0)) + depth * depth
			break

	var flag: int = 0
	if best <= alpha0:
		flag = 1   # upper bound
	elif best >= beta:
		flag = -1  # lower bound
	_tt[h] = {"depth": depth, "flag": flag, "score": best, "move": best_move}
	return best


# ---------------------------------------------------------------- порядок ходов

func _ordered_moves(state, depth: int, tt_move) -> Array:
	var side: String = state.turn
	var killers: Array = _killers.get(depth, [])
	var scored: Array = []
	for m in rules.moves_for_side(state, side):
		var s: int = 0
		if tt_move != null and m.from == tt_move.from and m.to == tt_move.to:
			s += 1000000
		s += _capture_estimate(state, m, side)
		for k in killers:
			if k != null and m.from == k.from and m.to == k.to:
				s += 9000
		s += int(_history.get("%d,%d" % [m.from, m.to], 0))
		scored.append([s, m])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for e in scored:
		out.append(e[1])
	return out


func _record_killer(depth: int, m) -> void:
	var ks: Array = _killers.get(depth, [null, null])
	if ks[0] != null and ks[0].from == m.from and ks[0].to == m.to:
		return
	ks[1] = ks[0]
	ks[0] = m
	_killers[depth] = ks


func _tt_move(state):
	var tt = _tt.get(_hash(state))
	return tt.move if tt != null else null


## Грубая оценка взятий ходом (без клонирования): `to` как «молот».
func _capture_estimate(state, m, side: String) -> int:
	var c: Vector2i = board.xy(m.to)
	var bonus: int = 0
	for d in DIRS:
		var ax: int = c.x + d.x
		var ay: int = c.y + d.y
		if not board.in_board(ax, ay):
			continue
		var adj: int = board.index(ax, ay)
		var sa: String = state.side_at(adj)
		if sa == "" or sa == side or adj == state.king:
			continue
		var bx: int = ax + d.x
		var by: int = ay + d.y
		if not board.in_board(bx, by):
			continue
		if _is_anvil_for(state, board.index(bx, by), side):
			bonus += 60
	return bonus


func _is_anvil_for(state, idx: int, side: String) -> bool:
	if board.is_corner(idx):
		return true
	if board.is_throne(idx) and not state.is_occupied(idx) and bool(rules.v.get("throne_hostile", true)):
		return true
	if side == "attackers":
		return state.attackers.has(idx)
	return state.defenders.has(idx) or (idx == state.king and bool(rules.v.get("king_armed", true)))


# ---------------------------------------------------------------- оценка

## Оценка с точки зрения стороны, которая ходит (для negamax).
func _eval_stm(state) -> int:
	var e: int = _eval(state)
	return e if state.turn == "defenders" else -e


## Статическая оценка позиции (def-positive). Веса — нормировка §9.5.
func _eval(state) -> int:
	var dv: int = state.defenders.size()
	var av: int = state.attackers.size()
	var sc: int = W_MATERIAL * (2 * dv - av)

	var kc: Vector2i = board.xy(state.king)
	# Риск короля: осаждающие вплотную.
	var adj: int = 0
	for d in DIRS:
		var nx: int = kc.x + d.x
		var ny: int = kc.y + d.y
		if board.in_board(nx, ny) and state.attackers.has(board.index(nx, ny)):
			adj += 1
	sc -= W_KING_RISK * adj

	# Свобода короля: выигрышные клетки + общая подвижность.
	var dests: Array = rules.legal_moves(state, state.king)
	var corner_escape: bool = String(rules.v.get("escape", "corner")) == "corner"
	var goals: int = 0
	for idx in dests:
		if (corner_escape and board.is_corner(idx)) or (not corner_escape and board.is_edge(idx)):
			goals += 1
	sc += W_KING_GOAL * goals
	sc += W_KING_MOB * dests.size()

	# Дистанция короля до ближайшей цели.
	sc -= W_KING_DIST * _king_goal_dist(state, corner_escape)
	return sc


func _king_goal_dist(state, corner_escape: bool) -> int:
	var kc: Vector2i = board.xy(state.king)
	if not corner_escape:
		# edge-escape: расстояние до ближайшей кромки.
		return min(min(kc.x, board.size - 1 - kc.x), min(kc.y, board.size - 1 - kc.y))
	var best: int = 1 << 20
	for cidx in board.corners:
		var cc: Vector2i = board.xy(cidx)
		best = min(best, abs(cc.x - kc.x) + abs(cc.y - kc.y))
	return best


# ---------------------------------------------------------------- Zobrist

func _init_zobrist(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x7AF1_2026
	_z_atk = PackedInt64Array(); _z_atk.resize(n)
	_z_def = PackedInt64Array(); _z_def.resize(n)
	_z_king = PackedInt64Array(); _z_king.resize(n)
	for i in range(n):
		_z_atk[i] = _rand64(rng)
		_z_def[i] = _rand64(rng)
		_z_king[i] = _rand64(rng)
	_z_turn = _rand64(rng)


func _rand64(rng: RandomNumberGenerator) -> int:
	return (rng.randi() << 32) ^ rng.randi()


func _hash(state) -> int:
	var h: int = 0
	for idx in state.attackers.keys():
		h ^= _z_atk[idx]
	for idx in state.defenders.keys():
		h ^= _z_def[idx]
	if state.king != -1:
		h ^= _z_king[state.king]
	if state.turn == "attackers":
		h ^= _z_turn
	return h

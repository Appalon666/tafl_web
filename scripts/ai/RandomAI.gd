extends RefCounted
## Базовый ИИ-заглушка для скелета: жадность на 1 полуход (предпочитает взятия),
## иначе случайный ход. Сильный многоуровневый ИИ (minimax/эвристики) — после
## анализа предметной области (см. docs/tafl_design_analysis.md, когда появится).

func choose_move(rules, state):
	var moves: Array = rules.moves_for_side(state, state.turn)
	if moves.is_empty():
		return null
	var best: Array = []
	var best_caps := -1
	for m in moves:
		var c = state.clone()
		var caps: int = rules.apply(c, m).size()
		# Бонус, если ход ведёт к немедленной победе.
		var win: bool = rules.check_winner(c) == state.turn
		var score: int = caps + (100 if win else 0)
		if score > best_caps:
			best_caps = score
			best = [m]
		elif score == best_caps:
			best.append(m)
	return best[randi() % best.size()]

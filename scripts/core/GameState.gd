extends RefCounted
## Лёгкое состояние партии Тафла. Дёшево клонируется (для ИИ и истории ходов).
##
## Стороны:
##  • "attackers" — осаждающие (многочисленные), ходят первыми.
##  • "defenders" — защитники + король; цель — увести короля.

var king: int = -1               # idx короля (-1 = взят)
var attackers: Dictionary = {}    # множество idx осаждающих (idx -> true)
var defenders: Dictionary = {}    # множество idx защитников (без короля)
var turn: String = "attackers"    # чей ход
var moves_no_capture: int = 0     # полуходов без взятия (для ничьей)


func clone():
	var s = get_script().new()
	s.king = king
	s.attackers = attackers.duplicate()
	s.defenders = defenders.duplicate()
	s.turn = turn
	s.moves_no_capture = moves_no_capture
	return s


func is_occupied(idx: int) -> bool:
	return idx == king or attackers.has(idx) or defenders.has(idx)


## Сторона фигуры на клетке: "attackers" | "defenders" | "" (пусто).
func side_at(idx: int) -> String:
	if attackers.has(idx):
		return "attackers"
	if idx == king or defenders.has(idx):
		return "defenders"
	return ""


func is_king(idx: int) -> bool:
	return idx == king

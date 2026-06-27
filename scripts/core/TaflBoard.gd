extends RefCounted
## Геометрия доски Тафла N×N: трон (центр), 4 угла, спецклетки.
## Доска квадратная нечётного размера (7/9/11). Точка кодируется idx = y*size + x.
##
## Спецклетки (поведение зависит от варианта — флаги берутся из RulesEngine):
##  • throne (трон) — центр; обычно только король может там стоять.
##  • corners (углы) — для corner-escape вариантов это поля побега короля;
##    для солдат недоступны; являются «враждебными» (помогают взятию).

var size: int = 11
var throne: int = 0
var corners: Array[int] = []


func _init(board_size: int = 11) -> void:
	size = board_size
	throne = index(size / 2, size / 2)
	corners = [
		index(0, 0), index(size - 1, 0),
		index(0, size - 1), index(size - 1, size - 1),
	]


func index(x: int, y: int) -> int:
	return y * size + x


func xy(idx: int) -> Vector2i:
	return Vector2i(idx % size, idx / size)


func in_board(x: int, y: int) -> bool:
	return x >= 0 and x < size and y >= 0 and y < size


func is_throne(idx: int) -> bool:
	return idx == throne


func is_corner(idx: int) -> bool:
	return corners.has(idx)


func is_edge(idx: int) -> bool:
	var c := xy(idx)
	return c.x == 0 or c.y == 0 or c.x == size - 1 or c.y == size - 1


## Спецклетка (трон/угол) — кандидат в «наковальню» при взятии и запретна для солдат.
func is_special(idx: int) -> bool:
	return is_throne(idx) or is_corner(idx)

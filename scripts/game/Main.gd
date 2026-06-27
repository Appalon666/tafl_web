extends Node2D
## Точка входа. Пока сразу запускает партию по текущему GameConfig.
## Меню/выбор варианта добавим отдельной сценой позже.

const GameControllerScript = preload("res://scripts/game/GameController.gd")


func _ready() -> void:
	var gc = GameControllerScript.new()
	add_child(gc)

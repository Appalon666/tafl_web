extends Node
## Настройки (autoload). Пока — только язык. Звук вне scope (добавим позже).

var locale := "ru"


func _ready() -> void:
	apply()


func apply() -> void:
	TranslationServer.set_locale(locale)


func set_locale_code(code: String) -> void:
	locale = code
	apply()

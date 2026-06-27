extends Node
## Настройки (autoload). Язык + глобальный UI-шрифт (если файл положен в проект).

## Куда положить TTF/OTF, чтобы он стал шрифтом всего UI (см. assets/fonts/README.md).
const UI_FONT_PATH := "res://assets/fonts/UIFont.ttf"
## Декоративный шрифт только для логотипа «TAFL» (латиница). Необязателен.
const TITLE_FONT_PATH := "res://assets/fonts/TitleFont.ttf"

var locale := "ru"
var title_font: Font = null  # шрифт заголовка, если файл положен


func _ready() -> void:
	apply()
	_apply_font()


func apply() -> void:
	TranslationServer.set_locale(locale)


## Если шрифт положен — делаем его глобальным (полная кириллица для веб-сборки).
## Нет файла — молча остаёмся на дефолтном шрифте Godot, без ошибок.
func _apply_font() -> void:
	if ResourceLoader.exists(UI_FONT_PATH):
		var f = load(UI_FONT_PATH)
		if f is Font:
			ThemeDB.fallback_font = f
	if ResourceLoader.exists(TITLE_FONT_PATH):
		var t = load(TITLE_FONT_PATH)
		if t is Font:
			title_font = t


func set_locale_code(code: String) -> void:
	locale = code
	apply()

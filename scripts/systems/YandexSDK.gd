extends Node
## Мост к Yandex Games SDK (autoload). Переносимый шаблон из проекта FaG —
## с УЖЕ встроенной паузой геймплея/звука при рекламе (требование Яндекс.Игр 4.7).
## Вне веба (десктоп, локальный тест) — безопасный no-op.
##
## JS-часть живёт в html/head_include веб-пресета (export_presets.cfg).
## Готовый сниппет: docs/yandex_sdk_head_include.html — вставить в head_include
## при настройке экспорта. Он грузит SDK и отдаёт объект window.RZ + хелперы.
##
## Подключение:
##  1) Autoload: Project Settings → Autoload → этот скрипт как "YandexSDK".
##  2) В export_presets.cfg (Web) → html/head_include = содержимое docs-сниппета.
##  3) Облачное сохранение: задать SAVE_FILES (пути user://*.json) или слушать
##     сигнал cloud_loaded и применять данные самостоятельно.
##  4) Реклама-вставка между логическими паузами: YandexSDK.show_interstitial().

signal cloud_loaded(data: Dictionary)
signal leaderboard_loaded(entries: Array)
signal auth_changed(authorized: bool)
signal sdk_ready  # SDK инициализировался и доступен (available стал true)

## Технический идентификатор лидерборда в кабинете Яндекс.Игр.
const LEADERBOARD_NAME := "rating"

const SAVE_DEBOUNCE := 4.0
## Файлы для синка в облако Яндекса. Прогресс игрока (разблокировка режимов).
const SAVE_FILES: Array[String] = ["user://progress.cfg"]
## Страховка: если реклама зависла без onClose/onError — снять паузу принудительно.
const AD_MAX_SECONDS := 45.0

var available := false
var _win = null
var _waiting_cloud := false
var _pending: Dictionary = {}
var _has_pending := false
var _save_timer := 0.0
var _ad_open := false
var _ad_timeout := 0.0
var _waiting_lb := false
var _waiting_auth := false


func _ready() -> void:
	# Пауза при рекламе (4.7): пока игра на паузе (get_tree().paused = true),
	# обычные узлы не обрабатываются. Этот мост обязан продолжать опрашивать SDK,
	# чтобы поймать onClose/onError и снять паузу — поэтому всегда активен.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)
		return
	_win = JavaScriptBridge.get_interface("window")
	if _win == null:
		set_process(false)
		return
	set_process(true)


func _process(delta: float) -> void:
	if not available:
		if _js_bool("!!(window.RZ && window.RZ.ready && window.RZ.player)"):
			available = true
			_apply_platform_lang()
			request_cloud_load()
			sdk_ready.emit()
		return
	_tick_ad(delta)
	_tick_save(delta)
	_tick_cloud_load()
	_tick_leaderboard()
	_tick_auth()


# ---------------------------------------------------------------- public API

func gameplay_start() -> void:
	if available and _win != null:
		_win.RZ_gameplayStart()


func gameplay_stop() -> void:
	if available and _win != null:
		_win.RZ_gameplayStop()


func show_interstitial() -> void:
	# Вызывать ТОЛЬКО в логических паузах (4.4): между партиями, в меню и т.п.
	if available and _win != null:
		_win.RZ_interstitial()


func push_save() -> void:
	if not (available and _win != null):
		return
	_pending = _collect_files()
	_has_pending = true
	_save_timer = SAVE_DEBOUNCE


func request_cloud_load() -> void:
	if available and _win != null:
		_waiting_cloud = true
		_win.RZ_load()


## Отправить рейтинг игрока в лидерборд (4.x — только целое число).
func submit_score(value: int) -> void:
	if available and _win != null:
		_win.RZ_setScore(value)


## Запросить записи лидерборда; результат придёт сигналом leaderboard_loaded.
func request_leaderboard() -> void:
	if available and _win != null:
		_waiting_lb = true
		_win.RZ_getLeaderboard()


## Авторизован ли игрок в профиле Яндекса (нужно для записи в лидерборд и PvP).
func is_authorized() -> bool:
	return available and _win != null and _js_bool("window.RZ_isAuthed()")


## Открыть нативный диалог входа Яндекса; итог придёт сигналом auth_changed(ok).
func prompt_auth() -> void:
	if available and _win != null:
		_waiting_auth = true
		_win.RZ_auth()


# ---------------------------------------------------------------- ads (4.7)

## Опрашиваем флаг window.RZ.adv (его JS выставляет в колбэках рекламы:
## open/close/error) и ставим/снимаем паузу геймплея + звука.
func _tick_ad(delta: float) -> void:
	var adv := String(JavaScriptBridge.eval("window.RZ ? (window.RZ.adv||'') : ''", true))
	if not _ad_open:
		if adv == "open":
			_enter_ad()
	else:
		_ad_timeout -= delta
		if adv == "close" or adv == "error" or _ad_timeout <= 0.0:
			_exit_ad()


func _enter_ad() -> void:
	_ad_open = true
	_ad_timeout = AD_MAX_SECONDS
	get_tree().paused = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)


func _exit_ad() -> void:
	_ad_open = false
	get_tree().paused = false
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	JavaScriptBridge.eval("if(window.RZ){window.RZ.adv='';}", true)


# ---------------------------------------------------------------- polling

func _tick_save(delta: float) -> void:
	if not _has_pending:
		return
	_save_timer -= delta
	if _save_timer <= 0.0:
		_has_pending = false
		_win.RZ_save(JSON.stringify(_pending))


func _tick_cloud_load() -> void:
	if not _waiting_cloud:
		return
	var lr: Variant = JavaScriptBridge.eval(
		"(window.RZ && !window.RZ.loadPending) ? window.RZ.loadResult : null", true)
	if lr != null and typeof(lr) == TYPE_STRING:
		_waiting_cloud = false
		var parsed: Variant = JSON.parse_string(String(lr))
		var data: Dictionary = parsed if parsed is Dictionary else {}
		_apply_cloud(data)
		cloud_loaded.emit(data)


func _tick_leaderboard() -> void:
	if not _waiting_lb:
		return
	var lr: Variant = JavaScriptBridge.eval(
		"(window.RZ && !window.RZ.lbPending) ? window.RZ.lbResult : null", true)
	if lr != null and typeof(lr) == TYPE_STRING:
		_waiting_lb = false
		var parsed: Variant = JSON.parse_string(String(lr))
		var entries: Array = parsed if parsed is Array else []
		leaderboard_loaded.emit(entries)


func _tick_auth() -> void:
	if not _waiting_auth:
		return
	var st := String(JavaScriptBridge.eval("window.RZ ? (window.RZ.authReq||'') : ''", true))
	if st == "ok" or st == "no":
		_waiting_auth = false
		JavaScriptBridge.eval("if(window.RZ){window.RZ.authReq='';}", true)
		auth_changed.emit(st == "ok")


# ---------------------------------------------------------------- cloud sync

func _collect_files() -> Dictionary:
	var out := {}
	for path in SAVE_FILES:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f:
				out[path] = f.get_as_text()
				f.close()
	return out


func _apply_cloud(data: Dictionary) -> void:
	if data.is_empty():
		return
	for path in data:
		if not SAVE_FILES.has(path):  # пишем только наши известные файлы
			continue
		var txt = data[path]
		if typeof(txt) != TYPE_STRING:
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(txt)
			f.close()
	# Применение состояния — на стороне слушателя cloud_loaded.


func _apply_platform_lang() -> void:
	var lang := String(JavaScriptBridge.eval("window.RZ ? (window.RZ.lang||'') : ''", true))
	var code := ""
	if lang.begins_with("en"):
		code = "en"
	elif lang.begins_with("ru"):
		code = "ru"
	if code != "":
		# Через Settings — чтобы совпали и TranslationServer, и Settings.locale
		# (от него зависят названия/описания режимов label_/desc_). Иначе у EN-
		# аудитории UI английский, а режимы остались бы русскими (грабля FaG 8.2.3).
		Settings.set_locale_code(code)


func _js_bool(expr: String) -> bool:
	var r: Variant = JavaScriptBridge.eval(expr, true)
	return bool(r)

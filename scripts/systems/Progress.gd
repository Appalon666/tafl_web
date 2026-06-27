extends Node
## Прогресс игрока (autoload): какие режимы пройдены и что разблокировано.
## Режимы открываются по порядку ORDER: следующий — после победы в предыдущем
## на сложности не ниже «Обычный» (easy не засчитывается). Сохраняется в user://.

const ORDER := ["brandubh", "tablut", "fetlar", "copenhagen"]
const SAVE_PATH := "user://progress.cfg"
## Очки рейтинга за победу = вес режима (индекс в ORDER +1) × вес сложности.
const DIFF_POINTS := {"easy": 0, "normal": 2, "hard": 3}
## Порядок сложностей ИИ — следующая открывается после победы на предыдущей.
const DIFF_ORDER := ["easy", "normal", "hard"]

var completed: Dictionary = {}   # variant_id -> true (режим пройден)
var score: int = 0               # суммарный рейтинг (очки за победы)
var games_played: int = 0
var wins: int = 0
var losses: int = 0
var wins_as_attackers: int = 0
var wins_as_defenders: int = 0
var hard_wins: int = 0
var tutorial_completed: bool = false
var variants_won: Dictionary = {}   # variant_id -> true (есть победа)
var achievements: Dictionary = {}   # achievement_id -> true (разблокировано)
var difficulty_won: Dictionary = {} # difficulty -> true (была победа на ней)
var autosave := true             # выключается в тестах, чтобы не писать на диск


func _ready() -> void:
	_load()
	# Подхватить облачное сохранение, когда мост дотянет его с сервера (асинхронно).
	var ysdk = get_node_or_null("/root/YandexSDK")
	if ysdk and ysdk.has_signal("cloud_loaded"):
		ysdk.cloud_loaded.connect(_on_cloud_loaded)


func _on_cloud_loaded(_data: Dictionary) -> void:
	# Мост уже записал progress.cfg на диск; перечитываем и сливаем (max/union),
	# затем пишем итог обратно на диск и в облако, чтобы все источники сошлись.
	_load()
	save_now()


## Открыт ли режим: первый — всегда; остальные — если предыдущий пройден.
func is_unlocked(id: String) -> bool:
	var i: int = ORDER.find(id)
	if i < 0:
		return false  # неизвестный режим — считаем закрытым
	if i == 0:
		return true   # первый режим всегда открыт
	return bool(completed.get(ORDER[i - 1], false))


func is_completed(id: String) -> bool:
	return bool(completed.get(id, false))


## Засчитывает прохождение режима. Возвращает id режима, который этим открылся
## (или "" — если ничего нового). difficulty="easy" не засчитывается.
func mark_completed(id: String, difficulty: String) -> String:
	if difficulty == "easy":
		return ""
	if bool(completed.get(id, false)):
		return ""  # уже было пройдено
	completed[id] = true
	_persist()
	var i: int = ORDER.find(id)
	if i >= 0 and i + 1 < ORDER.size():
		return ORDER[i + 1]  # следующий режим только что открылся
	return ""


## Начисляет очки рейтинга за победу человека: вес режима × вес сложности.
## Возвращает начисленные очки (0 — за «Лёгкий» или неизвестный режим).
func add_win(variant_id: String, difficulty: String) -> int:
	var dp: int = int(DIFF_POINTS.get(difficulty, 0))
	if dp == 0:
		return 0
	var weight: int = ORDER.find(variant_id) + 1  # 1..4; неизвестный → 0
	if weight <= 0:
		return 0
	var pts: int = weight * dp
	score += pts
	_persist()
	return pts


## Записывает итог партии в статистику. outcome: "win" | "loss" | "draw".
func record_game(outcome: String, side: String, variant_id: String, difficulty: String) -> void:
	games_played += 1
	match outcome:
		"win":
			wins += 1
			variants_won[variant_id] = true
			difficulty_won[difficulty] = true  # открывает следующую сложность
			if side == "attackers":
				wins_as_attackers += 1
			else:
				wins_as_defenders += 1
			if difficulty == "hard":
				hard_wins += 1
		"loss":
			losses += 1
	_persist()


func mark_tutorial_done() -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	_persist()


## Публичный сейв (для Achievements после разблокировки).
func save_now() -> void:
	_persist()


## Самый дальний открытый режим (для дефолтного выбора в меню).
func highest_unlocked() -> String:
	var best: String = ORDER[0]
	for id in ORDER:
		if is_unlocked(id):
			best = id
	return best


## Открыта ли сложность ИИ: easy всегда; следующая — после победы на предыдущей.
func difficulty_unlocked(d: String) -> bool:
	var i: int = DIFF_ORDER.find(d)
	if i <= 0:
		return true
	return bool(difficulty_won.get(DIFF_ORDER[i - 1], false))


func highest_difficulty() -> String:
	var best: String = DIFF_ORDER[0]
	for d in DIFF_ORDER:
		if difficulty_unlocked(d):
			best = d
	return best


## Сохранить на диск + синкнуть в облако (если не выключено в тестах).
func _persist() -> void:
	if not autosave:
		return
	_save()
	var ysdk = get_node_or_null("/root/YandexSDK")
	if ysdk:
		ysdk.push_save()


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	# Слияние, а не перезапись: на старте current=0 (max даёт значение из файла),
	# при облачном мердже — max(локаль, облако), чтобы офлайн-прогресс не терялся.
	for id in ORDER:
		if bool(cf.get_value("progress", id, false)):
			completed[id] = true
	score = maxi(score, int(cf.get_value("progress", "_score", 0)))
	games_played = maxi(games_played, int(cf.get_value("stats", "games", 0)))
	wins = maxi(wins, int(cf.get_value("stats", "wins", 0)))
	losses = maxi(losses, int(cf.get_value("stats", "losses", 0)))
	wins_as_attackers = maxi(wins_as_attackers, int(cf.get_value("stats", "wins_atk", 0)))
	wins_as_defenders = maxi(wins_as_defenders, int(cf.get_value("stats", "wins_def", 0)))
	hard_wins = maxi(hard_wins, int(cf.get_value("stats", "hard_wins", 0)))
	tutorial_completed = tutorial_completed or bool(cf.get_value("stats", "tutorial", false))
	for vid in ORDER:
		if bool(cf.get_value("variants_won", vid, false)):
			variants_won[vid] = true
	if cf.has_section("achievements"):
		for aid in cf.get_section_keys("achievements"):
			achievements[aid] = true
	for d in DIFF_ORDER:
		if bool(cf.get_value("difficulty_won", d, false)):
			difficulty_won[d] = true


func _save() -> void:
	var cf := ConfigFile.new()
	for id in completed.keys():
		cf.set_value("progress", id, true)
	cf.set_value("progress", "_score", score)
	cf.set_value("stats", "games", games_played)
	cf.set_value("stats", "wins", wins)
	cf.set_value("stats", "losses", losses)
	cf.set_value("stats", "wins_atk", wins_as_attackers)
	cf.set_value("stats", "wins_def", wins_as_defenders)
	cf.set_value("stats", "hard_wins", hard_wins)
	cf.set_value("stats", "tutorial", tutorial_completed)
	for vid in variants_won.keys():
		cf.set_value("variants_won", vid, true)
	for aid in achievements.keys():
		cf.set_value("achievements", aid, true)
	for d in difficulty_won.keys():
		cf.set_value("difficulty_won", d, true)
	cf.save(SAVE_PATH)

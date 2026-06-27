extends RefCounted
## Достижения Тафла. Локальные (у Яндекс.Игр нет нативного API ачивок) — состояние
## хранится в Progress.achievements и синкается в облако вместе с прогрессом.
## title/desc — русские ключи, на экране выводятся через tr().

## Список достижений по порядку отображения.
static func all() -> Array:
	return [
		{"id": "first_win", "title": "Первая кровь", "desc": "Выиграйте первую партию."},
		{"id": "escape_artist", "title": "Побег", "desc": "Победите за защитников (уведите короля)."},
		{"id": "besieger", "title": "Осада", "desc": "Победите за осаждающих (поймайте короля)."},
		{"id": "hardened", "title": "Закалённый", "desc": "Выиграйте на сложности «Сложный»."},
		{"id": "scholar", "title": "Ученик", "desc": "Пройдите обучение."},
		{"id": "all_modes", "title": "Мастер тафла", "desc": "Победите во всех четырёх режимах."},
		{"id": "veteran", "title": "Ветеран", "desc": "Сыграйте 10 партий."},
		{"id": "champion", "title": "Чемпион", "desc": "Наберите 50 очков рейтинга."},
	]


## Заработано ли достижение по текущему состоянию Progress.
static func is_earned(id: String, p) -> bool:
	match id:
		"first_win":
			return p.wins >= 1
		"escape_artist":
			return p.wins_as_defenders >= 1
		"besieger":
			return p.wins_as_attackers >= 1
		"hardened":
			return p.hard_wins >= 1
		"scholar":
			return p.tutorial_completed
		"all_modes":
			return p.variants_won.size() >= 4
		"veteran":
			return p.games_played >= 10
		"champion":
			return p.score >= 50
	return false


## Проверяет все достижения, помечает новые в p.achievements, сохраняет.
## Возвращает список id только что разблокированных.
static func refresh(p) -> Array:
	var newly: Array = []
	for a in all():
		var id: String = a.id
		if not p.achievements.has(id) and is_earned(id, p):
			newly.append(id)
	if not newly.is_empty():
		for id in newly:
			p.achievements[id] = true
		p.save_now()
	return newly


static func title_of(id: String) -> String:
	for a in all():
		if a.id == id:
			return String(a.title)
	return id

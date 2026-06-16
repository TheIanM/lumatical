class_name RunManager
extends RefCounted

## Manages roguelike run persistence: leaderboards, daily seeds, and share codes.
##
## Scores are saved to user://leaderboard.json as a simple array of entries.
## Daily seeds are derived from the date so everyone gets the same puzzles.
## Share codes are 6-character base36 strings that encode the seed.

const SAVE_PATH := "user://leaderboard.json"
const BASE36_CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


# ── Seeds ─────────────────────────────────────────────────────────────────────

## Returns today's daily seed. Same for everyone on the same date.
static func get_daily_seed() -> int:
	var date := Time.get_datetime_dict_from_system()
	return hash("%04d%02d%02d" % [date["year"], date["month"], date["day"]])


## Returns today's date as a readable string for display.
static func get_daily_label() -> String:
	var date := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


# ── Share Codes ───────────────────────────────────────────────────────────────

## Encode a seed integer as a 6-character base36 share code.
static func encode_seed(seed_val: int) -> String:
	var code := ""
	var v := absi(seed_val)
	for i in range(6):
		code = BASE36_CHARS[v % 36] + code
		v /= 36
	return code


## Decode a share code back to a seed integer.
static func decode_code(code: String) -> int:
	code = code.to_upper().strip_edges()
	var val := 0
	for ch in code:
		var idx: int = BASE36_CHARS.find(ch)
		if idx == -1:
			return -1
		val = val * 36 + idx
	return val


# ── Leaderboard ───────────────────────────────────────────────────────────────

## Submit a score to the leaderboard. Returns true if saved.
static func submit_score(mode: String, floor: int, score: int, seed_val: int) -> bool:
	var entries := load_scores()
	entries.append({
		"mode": mode,
		"floor": floor,
		"score": score,
		"seed": seed_val,
		"date": Time.get_datetime_string_from_system(false, true),
	})

	# Sort by score descending, keep top 10
	entries.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if entries.size() > 10:
		entries = entries.slice(0, 10)

	return _save_scores(entries)


## Load all leaderboard entries.
static func load_scores() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Array:
		return []
	return parsed


## Get the best score for a given mode.
static func get_best_score(mode: String) -> int:
	var best := 0
	for entry in load_scores():
		if entry.get("mode", "") == mode:
			best = maxi(best, int(entry.get("score", 0)))
	return best


# ── Internal ──────────────────────────────────────────────────────────────────

static func _save_scores(entries: Array) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()
	return true

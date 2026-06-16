class_name PuzzleSerializer
extends RefCounted

## Serializes and deserializes puzzle definitions between GDScript Dictionary
## format (used by the game) and JSON files (used by the level editor).
##
## JSON format conventions:
## - Grid positions are "x,y" strings (JSON object keys must be strings).
## - Colors are hex strings: "#rrggbb" or "#rrggbbaa".
## - Vector2i directions are [x, y] arrays.
## - Source/target/enemy data matches the in-game dict format.

const PUZZLE_DIR := "res://puzzles/"


# ── Serialization: Dictionary → JSON ──────────────────────────────────────────

## Convert a level Dictionary to a JSON string.
static func to_json(level: Dictionary) -> String:
	var data := {
		"name": level.get("name", "Untitled"),
		"sources": _sources_to_json(level.get("sources", [])),
		"targets": _targets_to_json(level.get("targets", {})),
		"blockers": _blockers_to_json(level.get("blockers", [])),
		"budgets": {
			"mirror": level.get("mirror_budget", 0),
			"prism": level.get("prism_budget", 0),
			"filter": level.get("filter_budget", 0),
			"splitter": level.get("splitter_budget", 0),
			"lens": level.get("lens_budget", 0),
		"refractor": level.get("refractor_budget", 0),
		"teleporter": level.get("teleporter_budget", 0),
		},
	}

	# Optional enemy arrays
	if level.has("shadow_blocks"):
		data["shadow_blocks"] = _shadow_blocks_to_json(level["shadow_blocks"])
	if level.has("chromatic_shades"):
		data["chromatic_shades"] = _shades_to_json(level["chromatic_shades"])
	if level.has("null_emitters"):
		data["null_emitters"] = _pos_array_to_json(level["null_emitters"])

	return JSON.stringify(data, "\t")


## Save a level Dictionary to a JSON file. Returns true on success.
static func save_to_file(level: Dictionary, filename: String) -> bool:
	var json_str := to_json(level)
	var path := PUZZLE_DIR + filename
	DirAccess.make_dir_recursive_absolute(PUZZLE_DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s for writing" % path)
		return false
	file.store_string(json_str)
	file.close()
	return true


# ── Deserialization: JSON → Dictionary ────────────────────────────────────────

## Parse a JSON string into a level Dictionary.
static func from_json(json_str: String) -> Dictionary:
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		push_error("Invalid JSON")
		return {}
	return _json_to_level(parsed)


## Load a level from a JSON file. Returns empty dict on failure.
static func load_from_file(filename: String) -> Dictionary:
	var path := PUZZLE_DIR + filename
	if not FileAccess.file_exists(path):
		push_error("File not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % path)
		return {}
	var json_str := file.get_as_text()
	file.close()
	return from_json(json_str)


## List all puzzle JSON files in the puzzle directory.
static func list_files() -> Array:
	if not DirAccess.dir_exists_absolute(PUZZLE_DIR):
		return []
	var files: Array = []
	var dir := DirAccess.open(PUZZLE_DIR)
	if dir == null:
		return []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


# ── Conversion Helpers ─────────────────────────────────────────────────────────

static func _json_to_level(data: Dictionary) -> Dictionary:
	var level := {}
	level["name"] = data.get("name", "Untitled")
	level["sources"] = _json_to_sources(data.get("sources", []))
	level["targets"] = _json_to_targets(data.get("targets", []))
	level["blockers"] = _json_to_blockers(data.get("blockers", []))

	var budgets: Dictionary = data.get("budgets", {})
	level["mirror_budget"] = int(budgets.get("mirror", 0))
	level["prism_budget"] = int(budgets.get("prism", 0))
	level["filter_budget"] = int(budgets.get("filter", 0))
	level["splitter_budget"] = int(budgets.get("splitter", 0))
	level["lens_budget"] = int(budgets.get("lens", 0))
	level["refractor_budget"] = int(budgets.get("refractor", 0))
	level["teleporter_budget"] = int(budgets.get("teleporter", 0))

	if data.has("shadow_blocks"):
		level["shadow_blocks"] = _json_to_shadow_blocks(data["shadow_blocks"])
	if data.has("chromatic_shades"):
		level["chromatic_shades"] = _json_to_shades(data["chromatic_shades"])
	if data.has("null_emitters"):
		level["null_emitters"] = _json_to_pos_array(data["null_emitters"])

	return level


# Sources

static func _sources_to_json(sources: Array) -> Array:
	var out: Array = []
	for src in sources:
		var d := {
			"pos": _pos_to_str(src["pos"]),
			"direction": [int(src["direction"].x), int(src["direction"].y)],
			"color": _color_to_str(src["color"]),
			"intensity": float(src.get("intensity", 1.0)),
		}
		out.append(d)
	return out


static func _json_to_sources(arr: Array) -> Array:
	var out: Array = []
	for src in arr:
		var parts := str(src["pos"]).split(",")
		out.append({
			"pos": Vector2i(int(parts[0]), int(parts[1])),
			"direction": Vector2i(int(src["direction"][0]), int(src["direction"][1])),
			"color": _str_to_color(src["color"]),
			"intensity": float(src.get("intensity", 1.0)),
		})
	return out


# Targets

static func _targets_to_json(targets: Dictionary) -> Array:
	var out: Array = []
	for pos in targets:
		var entry := {"pos": _pos_to_str(pos)}
		entry["color"] = _color_to_str(targets[pos]["color"])
		if targets[pos].has("intensity"):
			entry["intensity"] = float(targets[pos]["intensity"])
		out.append(entry)
	return out


static func _json_to_targets(arr: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in arr:
		var parts := str(entry["pos"]).split(",")
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		var data := {"color": _str_to_color(entry["color"])}
		if entry.has("intensity"):
			data["intensity"] = float(entry["intensity"])
		out[pos] = data
	return out


# Blockers

static func _blockers_to_json(blockers: Array) -> Array:
	var out: Array = []
	for pos in blockers:
		out.append(_pos_to_str(pos))
	return out


static func _json_to_blockers(arr: Array) -> Array:
	var out: Array = []
	for pos_str in arr:
		var parts := str(pos_str).split(",")
		out.append(Vector2i(int(parts[0]), int(parts[1])))
	return out


# Shadow blocks

static func _shadow_blocks_to_json(blocks: Array) -> Array:
	var out: Array = []
	for sb in blocks:
		out.append({
			"pos": _pos_to_str(sb["pos"]),
			"threshold": float(sb.get("threshold", 0.75)),
		})
	return out


static func _json_to_shadow_blocks(arr: Array) -> Array:
	var out: Array = []
	for sb in arr:
		var parts := str(sb["pos"]).split(",")
		out.append({
			"pos": Vector2i(int(parts[0]), int(parts[1])),
			"threshold": float(sb.get("threshold", 0.75)),
		})
	return out


# Chromatic shades

static func _shades_to_json(shades: Array) -> Array:
	var out: Array = []
	for cs in shades:
		out.append({
			"pos": _pos_to_str(cs["pos"]),
			"color": _color_to_str(cs["color"]),
		})
	return out


static func _json_to_shades(arr: Array) -> Array:
	var out: Array = []
	for cs in arr:
		var parts := str(cs["pos"]).split(",")
		out.append({
			"pos": Vector2i(int(parts[0]), int(parts[1])),
			"color": _str_to_color(cs["color"]),
		})
	return out


# Null emitters

static func _pos_array_to_json(positions: Array) -> Array:
	var out: Array = []
	for pos in positions:
		out.append(_pos_to_str(pos))
	return out


static func _json_to_pos_array(arr: Array) -> Array:
	var out: Array = []
	for pos_str in arr:
		var parts := str(pos_str).split(",")
		out.append(Vector2i(int(parts[0]), int(parts[1])))
	return out


# Position / Color helpers

static func _pos_to_str(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


static func _color_to_str(col: Color) -> String:
	return col.to_html(false)


static func _str_to_color(hex: String) -> Color:
	return Color.html(hex)

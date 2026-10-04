class_name PuzzleEngine
extends RefCounted
## Native, deterministic port of lumi.html's puzzle rules. Coordinates are (column, row).
## Resolution is atomic. Each returned step has an independent board snapshot for animation.
## Presentation, queued input, persistence and cafe rewards belong to the scene/controller.

const COLS = 8
const ROWS = 8
const TYPES = 6
const SP_NONE = 0
const SP_H = 1
const SP_V = 2
const SP_BOMB = 3
const SP_RAIN = 4
const FRUIT_KEYS = ["apple", "straw", "lemon", "orange", "banana", "melon"]
const COLOR_LABELS = ["빨강 고양이", "노랑 고양이", "초록 고양이", "파랑 고양이", "보라 고양이", "주황 고양이"]
# Original traversal order is down, up, right, left.
const DIRS = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

var levels: Array = []
var level_data: Dictionary = {}
var level_index = 0
var board: Array = []
var moves = 0
var score = 0
var combo = 1
var phase = "idle"
var stars = 0
var hammers = 2
var plus_left = 1
var need_fruit: Array = [0, 0, 0, 0, 0, 0]
var got_fruit: Array = [0, 0, 0, 0, 0, 0]
var need_ice = 0
var got_ice = 0
var need_crate = 0
var got_crate = 0
var goals: Array = []
var last_result: Dictionary = {}
var _gid = 1
var _rng_state = 1
var _steps: Array = []
var _total_cleared = 0

func _init() -> void:
	var parsed = preload("res://scripts/level_profile.gd").levels()
	if parsed is Array:
		levels = parsed

func initialize(index: int = 0, seed_value: int = 1) -> void:
	assert(not levels.is_empty(), "Puzzle level data could not be loaded")
	level_index = clampi(index, 0, levels.size() - 1)
	level_data = levels[level_index].duplicate(true)
	_rng_state = preload("res://scripts/level_profile.gd").opening_seed(index,seed_value) & 0xffffffff
	_gid = 1
	moves = int(level_data.moves)
	score = 0
	combo = 1
	phase = "idle"
	stars = 0
	hammers = 2
	plus_left = 1
	need_fruit = []
	got_fruit = [0, 0, 0, 0, 0, 0]
	for key in FRUIT_KEYS:
		need_fruit.append(int(level_data.get(key, 0)))
	need_ice = int(level_data.get("ice", 0))
	need_crate = int(level_data.get("crate", 0))
	got_ice = 0
	got_crate = 0
	_steps = []
	_total_cleared = 0
	_generate()
	_place_opening_ice()
	_place_opening_crates()
	_sync_goals()
	last_result = {}

# Low-32-bit multiplication avoids signed 64-bit overflow and matches JS Math.imul.
func _imul(a: int, b: int) -> int:
	return ((a & 65535) * (b & 65535) + ((((a >> 16) * (b & 65535) + (b >> 16) * (a & 65535)) & 65535) << 16)) & 0xffffffff

func _rand() -> float:
	_rng_state = (_rng_state + 0x6d2b79f5) & 0xffffffff
	var t = _imul(_rng_state ^ (_rng_state >> 15), 1 | _rng_state)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) ^ t) & 0xffffffff
	return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

func make_gem(pos: Vector2i, color: int) -> Dictionary:
	var gem = {"id": _gid, "type": color, "look": -1, "special": SP_NONE, "ice": false, "crate": false, "r": pos.y, "c": pos.x}
	_gid += 1
	return gem

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < COLS and pos.y < ROWS

func gem_at(pos: Vector2i):
	if not in_bounds(pos) or board.size() != ROWS:
		return null
	return board[pos.y][pos.x]

func _all_positions() -> Array:
	var result: Array = []
	for r in ROWS:
		for c in COLS:
			result.append(Vector2i(c, r))
	return result

func _count_dir(pos: Vector2i, color: int, direction: Vector2i) -> int:
	var count = 0
	var next = pos + direction
	while in_bounds(next):
		var gem = gem_at(next)
		if gem == null or gem.type != color:
			break
		count += 1
		next += direction
	return count

func _would_match(pos: Vector2i, color: int) -> bool:
	if color < 0:
		return false
	return _count_dir(pos, color, Vector2i.LEFT) + _count_dir(pos, color, Vector2i.RIGHT) >= 2 or _count_dir(pos, color, Vector2i.UP) + _count_dir(pos, color, Vector2i.DOWN) >= 2

func _choose_type(pos: Vector2i) -> int:
	var options: Array = []
	for color in TYPES:
		if not _would_match(pos, color):
			options.append(color)
	if options.is_empty():
		options = [0, 1, 2, 3, 4, 5]
	return options[int(_rand() * options.size())]

func find_runs() -> Array:
	var runs: Array = []
	for r in ROWS:
		var c = 0
		while c < COLS:
			var gem = board[r][c]
			if gem == null or gem.type < 0:
				c += 1
				continue
			var end = c + 1
			while end < COLS and board[r][end] != null and board[r][end].type == gem.type:
				end += 1
			if end - c >= 3:
				var cells: Array = []
				for x in range(c, end):
					cells.append(Vector2i(x, r))
				runs.append({"dir": "h", "cells": cells})
			c = end
	for c in COLS:
		var r = 0
		while r < ROWS:
			var gem = board[r][c]
			if gem == null or gem.type < 0:
				r += 1
				continue
			var end = r + 1
			while end < ROWS and board[end][c] != null and board[end][c].type == gem.type:
				end += 1
			if end - r >= 3:
				var cells: Array = []
				for y in range(r, end):
					cells.append(Vector2i(c, y))
				runs.append({"dir": "v", "cells": cells})
			r = end
	return runs

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var ga = gem_at(a)
	var gb = gem_at(b)
	board[a.y][a.x] = gb
	board[b.y][b.x] = ga
	if ga != null:
		ga.r = b.y
		ga.c = b.x
	if gb != null:
		gb.r = a.y
		gb.c = a.x

func _valid_pair(a: Vector2i, b: Vector2i) -> bool:
	if not in_bounds(a) or not in_bounds(b) or absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	var ga = gem_at(a)
	var gb = gem_at(b)
	return ga != null and gb != null and not ga.crate and not gb.crate

func is_legal_swap(a: Vector2i, b: Vector2i) -> bool:
	if not _valid_pair(a, b):
		return false
	var ga = gem_at(a)
	var gb = gem_at(b)
	if ga.special == SP_RAIN or gb.special == SP_RAIN or not pair_combo(ga, gb).is_empty():
		return true
	var before = find_runs()
	_swap_cells(a, b)
	var after = find_runs()
	_swap_cells(a, b)
	if before == after:
		return false
	for run in after:
		if a in run.cells or b in run.cells:
			return true
	return false

func hint() -> Array:
	for r in ROWS:
		for c in COLS:
			var pos = Vector2i(c, r)
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other = pos + direction
				if is_legal_swap(pos, other):
					return [pos, other]
	return []

func _generate() -> void:
	for attempt in 80:
		board = []
		for r in ROWS:
			var row: Array = []
			row.resize(COLS)
			board.append(row)
		for pos in _all_positions():
			board[pos.y][pos.x] = make_gem(pos, _choose_type(pos))
		if find_runs().is_empty() and not hint().is_empty():
			return
	_scrub_matches()

func _scrub_matches() -> void:
	for iteration in 40:
		var runs = find_runs()
		if runs.is_empty():
			return
		var cells = runs[0].cells
		var pos = cells[int(cells.size() / 2)]
		var gem = gem_at(pos)
		var fixed = false
		for color in TYPES:
			if color != gem.type and not _would_match(pos, color):
				gem.type = color
				gem.special = SP_NONE
				fixed = true
				break
		if not fixed:
			gem.type = (gem.type + 1) % TYPES
			gem.special = SP_NONE

func _matched_keys(runs: Array) -> Array:
	var seen: Dictionary = {}
	for run in runs:
		for pos in run.cells:
			seen[pos] = true
	return seen.keys()

func _pick_cell(cells: Array, primary: Vector2i, secondary: Vector2i) -> Vector2i:
	if primary in cells:
		return primary
	if secondary in cells:
		return secondary
	if primary.x >= 0:
		var best: Vector2i = cells[0]
		var distance = 999
		for pos in cells:
			var next = absi(pos.x - primary.x) + absi(pos.y - primary.y)
			if next < distance:
				distance = next
				best = pos
		return best
	return cells[int(cells.size() / 2)]

func plan_specials(runs: Array, primary: Vector2i = Vector2i(-1, -1), secondary: Vector2i = Vector2i(-1, -1)) -> Array:
	var in_run: Dictionary = {}
	for index in runs.size():
		for pos in runs[index].cells:
			if not in_run.has(pos):
				in_run[pos] = []
			in_run[pos].append(index)
	var seen: Dictionary = {}
	var specs: Array = []
	for start in in_run.keys():
		if seen.has(start):
			continue
		var cluster: Array = []
		var queue: Array = [start]
		seen[start] = true
		while not queue.is_empty():
			var pos = queue.pop_back()
			cluster.append(pos)
			for direction in DIRS:
				var neighbor = pos + direction
				if in_run.has(neighbor) and not seen.has(neighbor):
					seen[neighbor] = true
					queue.append(neighbor)
		var used: Dictionary = {}
		var cluster_runs: Array = []
		for pos in cluster:
			for index in in_run[pos]:
				if not used.has(index):
					used[index] = true
					cluster_runs.append(runs[index])
		# Strict greater-than preserves the original stable tie ordering.
		var longest = null
		for run in cluster_runs:
			if run.cells.size() >= 5 and (longest == null or run.cells.size() > longest.cells.size()):
				longest = run
		if longest != null:
			specs.append({"pos": _pick_cell(longest.cells, primary, secondary), "kind": SP_RAIN})
			continue
		var intersections: Array = []
		for pos in cluster:
			var horizontal = false
			var vertical = false
			for index in in_run[pos]:
				horizontal = horizontal or runs[index].dir == "h"
				vertical = vertical or runs[index].dir == "v"
			if horizontal and vertical:
				intersections.append(pos)
		if not intersections.is_empty():
			specs.append({"pos": _pick_cell(intersections, primary, secondary), "kind": SP_BOMB})
			continue
		var four = null
		for run in cluster_runs:
			if run.cells.size() >= 4 and (four == null or run.cells.size() > four.cells.size()):
				four = run
		if four != null:
			specs.append({"pos": _pick_cell(four.cells, primary, secondary), "kind": SP_H if four.dir == "h" else SP_V})
	return specs

func _retarget_specs(specs: Array, seeds: Array) -> void:
	var used: Dictionary = {}
	for i in range(specs.size() - 1, -1, -1):
		var spec = specs[i]
		if spec.pos not in seeds:
			var best = null
			var distance = 99
			for pos in seeds:
				if used.has(pos):
					continue
				var next = absi(pos.x - spec.pos.x) + absi(pos.y - spec.pos.y)
				if next < distance:
					distance = next
					best = pos
			if best == null:
				specs.remove_at(i)
				continue
			spec.pos = best
		if used.has(spec.pos):
			specs.remove_at(i)
			continue
		used[spec.pos] = true

func area_keys(gem: Dictionary, pos: Vector2i) -> Array:
	var cells: Array = []
	match int(gem.special):
		SP_H:
			for c in COLS:
				cells.append(Vector2i(c, pos.y))
		SP_V:
			for r in ROWS:
				cells.append(Vector2i(pos.x, r))
		SP_BOMB:
			for r in range(pos.y - 1, pos.y + 2):
				for c in range(pos.x - 1, pos.x + 2):
					if in_bounds(Vector2i(c, r)):
						cells.append(Vector2i(c, r))
		SP_RAIN:
			var colors: Array = []
			for other in _all_positions():
				var piece = gem_at(other)
				if piece != null and piece.type >= 0 and piece.type not in colors:
					colors.append(piece.type)
			if not colors.is_empty():
				var color = colors[int(_rand() * colors.size())]
				for other in _all_positions():
					var piece = gem_at(other)
					if piece != null and piece.type == color:
						cells.append(other)
	return cells

func _collect_clears(seeds: Array, preserve: Dictionary, acts: Array) -> Array:
	var doomed: Dictionary = {}
	var activated: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array = seeds.duplicate()
	while not queue.is_empty():
		var pos = queue.pop_back()
		if visited.has(pos):
			continue
		visited[pos] = true
		var gem = gem_at(pos)
		if gem == null:
			continue
		if gem.special != SP_NONE and not activated.has(gem.id):
			activated[gem.id] = true
			var extra = area_keys(gem, pos)
			acts.append({"special": gem.special, "pos": pos, "cells": extra.duplicate()})
			queue.append_array(extra)
		if not preserve.has(pos):
			doomed[pos] = true
	return doomed.keys()

func _crates_beside(doomed: Array, preserve: Dictionary) -> Array:
	var extra: Dictionary = {}
	for pos in doomed:
		var gem = gem_at(pos)
		if preserve.has(pos) or gem == null or gem.crate:
			continue
		for direction in DIRS:
			var neighbor = pos + direction
			var other = gem_at(neighbor)
			if other != null and other.crate and neighbor not in doomed:
				extra[neighbor] = true
	return extra.keys()

func _break_ice(gem: Dictionary) -> bool:
	if not gem.ice:
		return false
	gem.ice = false
	got_ice += 1
	return true

func _begin_match(player: bool, primary: Vector2i = Vector2i(-1, -1), secondary: Vector2i = Vector2i(-1, -1)) -> void:
	var runs = find_runs()
	if runs.is_empty():
		return
	var seeds: Array = []
	var ice_only: Array = []
	for pos in _matched_keys(runs):
		if gem_at(pos).ice:
			ice_only.append(pos)
		else:
			seeds.append(pos)
	var specs = plan_specials(runs, primary, secondary) if player else []
	_retarget_specs(specs, seeds)
	var preserve: Dictionary = {}
	for spec in specs:
		preserve[spec.pos] = true
	for pos in ice_only:
		_break_ice(gem_at(pos))
	if not ice_only.is_empty():
		_record("ice", {"cells": ice_only})
	if seeds.is_empty() and specs.is_empty():
		# An entirely frozen line first thaws, then clears on the next beat.
		_begin_match(false)
		return
	_finish_clear(seeds, preserve, specs)

func _finish_clear(seeds: Array, preserve: Dictionary = {}, specs: Array = [], direct: bool = false, effect: String = "match") -> void:
	var acts: Array = []
	var doomed = _collect_clears(seeds, preserve, acts)
	if not direct:
		doomed.append_array(_crates_beside(doomed, preserve))
	for spec in specs:
		var gem = gem_at(spec.pos)
		if gem == null:
			continue
		gem.special = spec.kind
		if spec.kind == SP_RAIN:
			if gem.type >= 0:
				gem.look = gem.type
			gem.type = -1
	if doomed.is_empty() and specs.is_empty():
		return
	var points = doomed.size() * 10 * combo
	score += points
	_total_cleared += doomed.size()
	var removed: Array = []
	var ice_hits: Array = []
	for pos in doomed:
		var gem = gem_at(pos)
		if gem == null or preserve.has(pos):
			continue
		removed.append(gem.duplicate(true))
		if gem.crate:
			got_crate += 1
		else:
			if _break_ice(gem):
				ice_hits.append(pos)
			if gem.type >= 0 and need_fruit[gem.type] > 0:
				got_fruit[gem.type] += 1
	_sync_goals()
	_record("clear", {"cells": doomed.duplicate(), "removed": removed, "created": specs.duplicate(true), "activations": acts, "ice": ice_hits, "points": points, "combo": combo, "effect": effect})
	for pos in doomed:
		board[pos.y][pos.x] = null
	_record("gap", {"cells": doomed.duplicate()})

func pair_combo(a: Dictionary, b: Dictionary) -> String:
	var s1 = int(a.special)
	var s2 = int(b.special)
	if s1 == SP_NONE or s2 == SP_NONE:
		return ""
	if s1 == SP_RAIN and s2 == SP_RAIN:
		return "rain2"
	if s1 == SP_RAIN or s2 == SP_RAIN:
		return "rainspec"
	if _is_stripe(s1) and _is_stripe(s2):
		return "stripes"
	if (_is_stripe(s1) and s2 == SP_BOMB) or (_is_stripe(s2) and s1 == SP_BOMB):
		return "stripebomb"
	if s1 == SP_BOMB and s2 == SP_BOMB:
		return "bombs"
	return ""

func _is_stripe(special: int) -> bool:
	return special == SP_H or special == SP_V

func combo_clear_keys(a: Dictionary, b: Dictionary, kind: String, primary: Vector2i) -> Array:
	var cells: Dictionary = {}
	if kind == "stripes":
		for gem in [a, b]:
			for pos in area_keys(gem, Vector2i(gem.c, gem.r)):
				cells[pos] = true
	elif kind == "stripebomb":
		var stripe = a if _is_stripe(a.special) else b
		if stripe.special == SP_V:
			for c in range(stripe.c - 1, stripe.c + 2):
				for r in ROWS:
					if in_bounds(Vector2i(c, r)):
						cells[Vector2i(c, r)] = true
		else:
			for r in range(stripe.r - 1, stripe.r + 2):
				for c in COLS:
					if in_bounds(Vector2i(c, r)):
						cells[Vector2i(c, r)] = true
	elif kind == "bombs":
		for r in range(primary.y - 2, primary.y + 3):
			for c in range(primary.x - 2, primary.x + 3):
				if in_bounds(Vector2i(c, r)):
					cells[Vector2i(c, r)] = true
	return cells.keys()

func _begin_pair(a: Dictionary, b: Dictionary, kind: String, primary: Vector2i) -> void:
	if kind == "rainspec":
		var rain = a if a.special == SP_RAIN else b
		var spec = b if rain.id == a.id else a
		var special = int(spec.special)
		var color = rain.type if rain.type >= 0 else spec.type
		rain.special = SP_NONE
		spec.special = SP_NONE
		var seeds: Array = [Vector2i(rain.c, rain.r), Vector2i(spec.c, spec.r)]
		var count = 0
		if color >= 0 and (_is_stripe(special) or special == SP_BOMB):
			for pos in _all_positions():
				var gem = gem_at(pos)
				if gem == null or gem.id == rain.id or gem.id == spec.id or gem.type != color:
					continue
				gem.special = special
				seeds.append(pos)
				count += 1
				if count >= 8:
					break
		_finish_clear(seeds, {}, [], false, kind)
		return
	var cells = combo_clear_keys(a, b, kind, primary)
	a.special = SP_NONE
	b.special = SP_NONE
	_finish_clear(cells, {}, [], false, kind)

func _begin_rainbow(a: Dictionary, b: Dictionary) -> void:
	var seeds: Array = []
	if a.special == SP_RAIN and b.special == SP_RAIN:
		a.special = SP_NONE
		b.special = SP_NONE
		for pos in _all_positions():
			if gem_at(pos) != null:
				seeds.append(pos)
	else:
		var rain = a if a.special == SP_RAIN else b
		var other = b if rain.id == a.id else a
		var color = int(other.type)
		rain.special = SP_NONE
		for pos in _all_positions():
			var gem = gem_at(pos)
			if gem != null and (gem.id == rain.id or (color >= 0 and gem.type == color)):
				seeds.append(pos)
	_finish_clear(seeds, {}, [], false, "rainbow")

func try_swap(a: Vector2i, b: Vector2i) -> Dictionary:
	_steps = []
	_total_cleared = 0
	var old_score = score
	if phase != "idle" or moves <= 0:
		return _result(false, old_score, "busy_or_finished")
	if not _valid_pair(a, b):
		return _result(false, old_score, "invalid_pair")
	if not is_legal_swap(a, b):
		_record("reject", {"a": a, "b": b})
		return _result(false, old_score, "no_match")
	phase = "resolving"
	_swap_cells(a, b)
	moves -= 1
	combo = 1
	_record("swap", {"a": a, "b": b})
	var ga = gem_at(b)
	var gb = gem_at(a)
	var kind = pair_combo(ga, gb)
	if kind == "rain2":
		_begin_rainbow(ga, gb)
	elif not kind.is_empty():
		_begin_pair(ga, gb, kind, b)
	elif ga.special == SP_RAIN or gb.special == SP_RAIN:
		_begin_rainbow(ga, gb)
	else:
		_begin_match(true, b, a)
	_settle()
	return _result(true, old_score)

func _settle() -> void:
	for iteration in 42:
		apply_gravity()
		combo += 1
		if combo > 40:
			_scrub_matches()
			_record("scrub", {})
			break
		if find_runs().is_empty():
			break
		_begin_match(false)
	finish_turn()

func finish_turn() -> void:
	_sync_goals()
	if goals_met():
		phase = "win"
		stars = stars_for(moves, int(level_data.moves))
	elif moves <= 0:
		phase = "lose"
	else:
		phase = "idle"
		if hint().is_empty():
			_shuffle_board()
	_record("settled", {"phase": phase, "stars": stars})

func _result(accepted: bool, old_score: int, reason: String = "") -> Dictionary:
	_sync_goals()
	last_result = {"accepted": accepted, "reason": reason, "steps": _steps.duplicate(true), "cleared": _total_cleared, "score_delta": score - old_score, "moves": moves, "phase": phase, "stars": stars, "goals": goals.duplicate(true)}
	return last_result

func _record(kind: String, details: Dictionary) -> void:
	var step = details.duplicate(true)
	step["kind"] = kind
	step["board"] = board.duplicate(true)
	step["score"] = score
	step["moves"] = moves
	_steps.append(step)

func apply_gravity() -> void:
	var has_crates = false
	for pos in _all_positions():
		var gem = gem_at(pos)
		if gem != null and gem.crate:
			has_crates = true
			break
	var motions: Array = []
	if has_crates:
		_gravity_around_crates(motions)
	else:
		_gravity_open(motions)
	_record("fall", {"motions": motions})

func _gravity_open(motions: Array) -> void:
	var columns: Array = []
	for c in COLS:
		var column: Array = []
		for r in range(ROWS - 1, -1, -1):
			if board[r][c] != null:
				column.append(board[r][c])
		columns.append(column)
		for r in ROWS:
			board[r][c] = null
	for c in COLS:
		var r = ROWS - 1
		for gem in columns[c]:
			var from = Vector2i(gem.c, gem.r)
			gem.r = r
			gem.c = c
			board[r][c] = gem
			if from.y != r:
				motions.append({"id": gem.id, "from": from, "to": Vector2i(c, r), "spawned": false})
			r -= 1
	var spawned = [0, 0, 0, 0, 0, 0, 0, 0]
	# The open-board refill is row-major bottom-up, unlike crate segments.
	for r in range(ROWS - 1, -1, -1):
		for c in COLS:
			if board[r][c] == null:
				var pos = Vector2i(c, r)
				var gem = make_gem(pos, _choose_type(pos))
				board[r][c] = gem
				motions.append({"id": gem.id, "from": Vector2i(c, -1 - spawned[c]), "to": pos, "spawned": true})
				spawned[c] += 1

func _gravity_around_crates(motions: Array) -> void:
	for c in COLS:
		var r = ROWS - 1
		while r >= 0:
			if board[r][c] != null and board[r][c].crate:
				r -= 1
				continue
			var bottom = r
			while r >= 0 and not (board[r][c] != null and board[r][c].crate):
				r -= 1
			var top = r + 1
			var gems: Array = []
			for y in range(bottom, top - 1, -1):
				if board[y][c] != null:
					gems.append(board[y][c])
				board[y][c] = null
			var write = bottom
			for gem in gems:
				var from = Vector2i(gem.c, gem.r)
				gem.r = write
				gem.c = c
				board[write][c] = gem
				if from.y != write:
					motions.append({"id": gem.id, "from": from, "to": Vector2i(c, write), "spawned": false})
				write -= 1
			var spawned = 0
			for y in range(write, top - 1, -1):
				var pos = Vector2i(c, y)
				var gem = make_gem(pos, _choose_type(pos))
				board[y][c] = gem
				motions.append({"id": gem.id, "from": Vector2i(c, top - 1 - spawned), "to": pos, "spawned": true})
				spawned += 1

func _opening_keys() -> Dictionary:
	var opening: Dictionary = {}
	var pair = hint()
	if not pair.is_empty():
		_swap_cells(pair[0], pair[1])
		for pos in _matched_keys(find_runs()):
			opening[pos] = true
		_swap_cells(pair[0], pair[1])
	return opening

func _same_neighbor(pos: Vector2i, color: int) -> bool:
	for direction in DIRS:
		var other = gem_at(pos + direction)
		if other != null and color >= 0 and other.type == color:
			return true
	return false

func _place_opening_ice() -> void:
	var left = need_ice - got_ice
	for pos in _all_positions():
		gem_at(pos).ice = false
	if left <= 0:
		return
	var matched = _matched_keys(find_runs())
	var opening = _opening_keys()
	var pool: Array = []
	for skip_opening in [true, false]:
		pool = []
		for pos in _all_positions():
			var gem = gem_at(pos)
			if pos in matched or (skip_opening and opening.has(pos)) or not _same_neighbor(pos, gem.type):
				continue
			pool.append(gem)
		if pool.size() >= left:
			break
	for i in range(pool.size() - 1, 0, -1):
		var j = int(_rand() * (i + 1))
		var temp = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	for i in mini(left, pool.size()):
		pool[i].ice = true

func _near_crate(pos: Vector2i) -> bool:
	for direction in DIRS:
		var other = gem_at(pos + direction)
		if other != null and other.crate:
			return true
	return false

func _crate_pool(matched: Array, opening: Dictionary, banned: Dictionary, skip_opening: bool, separated: bool) -> Array:
	var pool: Array = []
	for pos in _all_positions():
		var gem = gem_at(pos)
		if banned.has(gem.id) or gem.ice or gem.crate or pos in matched:
			continue
		if skip_opening and opening.has(pos):
			continue
		if separated and _near_crate(pos):
			continue
		pool.append(gem)
	return pool

func _place_opening_crates() -> void:
	var left = need_crate - got_crate
	if left <= 0:
		return
	var matched = _matched_keys(find_runs())
	var opening = _opening_keys()
	var banned: Dictionary = {}
	var placed = 0
	for guard in 100:
		if placed >= left:
			break
		var pool = _crate_pool(matched, opening, banned, true, true)
		if pool.is_empty():
			pool = _crate_pool(matched, opening, banned, true, false)
		if pool.is_empty():
			pool = _crate_pool(matched, opening, banned, false, false)
		if pool.is_empty():
			break
		var gem = pool[int(_rand() * pool.size())]
		var previous = gem.type
		gem.crate = true
		gem.type = -2
		gem.special = SP_NONE
		gem.ice = false
		placed += 1
		if hint().is_empty():
			gem.crate = false
			gem.type = previous
			placed -= 1
			banned[gem.id] = true

func _shuffle_board() -> void:
	_generate()
	_place_opening_ice()
	_place_opening_crates()
	_record("shuffle", {})

func shuffle() -> Dictionary:
	_steps = []
	_total_cleared = 0
	if phase != "idle":
		return _result(false, score, "busy_or_finished")
	_shuffle_board()
	return _result(true, score)

func use_hammer(pos: Vector2i) -> Dictionary:
	_steps = []
	_total_cleared = 0
	var old_score = score
	if phase != "idle" or hammers <= 0 or gem_at(pos) == null:
		return _result(false, old_score, "unavailable")
	hammers -= 1
	phase = "resolving"
	gem_at(pos).special = SP_NONE
	combo = 1
	_finish_clear([pos], {}, [], true, "hammer")
	combo = 0
	_settle()
	return _result(true, old_score)

func use_plus() -> bool:
	if phase != "idle" or plus_left <= 0:
		return false
	plus_left -= 1
	moves += 5
	return true

func goals_met() -> bool:
	for color in TYPES:
		if got_fruit[color] < need_fruit[color]:
			return false
	return got_ice >= need_ice and got_crate >= need_crate

func _sync_goals() -> void:
	goals = []
	for color in TYPES:
		if need_fruit[color] > 0:
			goals.append({"kind": "fruit", "type": color, "label": COLOR_LABELS[color], "target": need_fruit[color], "current": got_fruit[color]})
	if need_ice > 0:
		goals.append({"kind": "ice", "type": -1, "label": "얼음", "target": need_ice, "current": got_ice})
	if need_crate > 0:
		goals.append({"kind": "crate", "type": -2, "label": "상자", "target": need_crate, "current": got_crate})

static func stars_for(left: int, budget: int) -> int:
	if maxi(0, left) >= ceili(maxi(1, budget) * 0.4):
		return 3
	if maxi(0, left) >= ceili(maxi(1, budget) * 0.15):
		return 2
	return 1

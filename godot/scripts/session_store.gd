class_name PuzzleSessionStore
extends RefCounted
## Durable navigation and native puzzle checkpoint, separate from cafe currency.
## Order: CafeModel.begin_attempt -> begin_puzzle -> checkpoint after each atomic
## action -> begin_completion -> CafeModel.finish_attempt -> presentation ->
## acknowledge_completion. On resume, finish_attempt may safely repeat with the
## same attempt_id. A first win unlocks the cafe only after presentation acknowledgment.
## Mutation results are {ok, state} or {ok:false, reason, message}. Check every result.
## A corrupt main save recovers only from a validated backup; its raw bytes are
## preserved in .before-restore. With no valid recovery load_state returns {} and
## blocks mutations rather than silently discarding progress.

const Store = preload("res://scripts/save_store.gd")
const Puzzle = preload("res://scripts/puzzle_engine.gd")
const VERSION = 1
const MAX_BYTES = 2 * 1024 * 1024
const MAX_SAFE_INTEGER = 9007199254740991
const SNAPSHOT_INTS = ["level_index", "moves", "score", "combo", "stars", "hammers", "plus_left", "need_ice", "got_ice", "need_crate", "got_crate", "_gid", "_rng_state", "_total_cleared"]
const SNAPSHOT_ARRAYS = ["board", "need_fruit", "got_fruit"]

var storage: RefCounted
var state: Dictionary = {}
var last_error = ""
var recovered_backup = false
var _levels: Array = []

func _init(save_path: String = "user://session-save.json", store_override: Variant = null) -> void:
	storage = Store.new(save_path) if store_override == null else store_override
	var parsed = preload("res://scripts/level_profile.gd").levels()
	if parsed is Array: _levels = parsed

func fresh() -> Dictionary:
	return {"version":VERSION, "first_puzzle_completed":false, "phase":"title", "attempt_id":"", "first_run":false, "puzzle_snapshot":{}}

func _fail(reason: String, message: String) -> Dictionary:
	last_error = message
	return {"ok":false, "reason":reason, "message":message}

func _integer(value: Variant, minimum: int = 0, maximum: int = MAX_SAFE_INTEGER) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and value >= minimum and value <= maximum

func _valid_snapshot(s: Variant) -> bool:
	if not s is Dictionary or _levels.is_empty(): return false
	for field in SNAPSHOT_INTS:
		if not _integer(s.get(field)): return false
	if not _integer(s.level_index, 0, _levels.size() - 1): return false
	var level: Dictionary = _levels[int(s.level_index)]
	if not s.get("phase") in ["idle", "win", "lose"]: return false
	if not _integer(s.moves, 0, int(level.moves) + 5) or not _integer(s.combo, 0, 41): return false
	if not _integer(s.stars, 0, 3) or not _integer(s.hammers, 0, 2) or not _integer(s.plus_left, 0, 1): return false
	if not _integer(s._rng_state, 0, 0xffffffff) or not _integer(s._gid, 1): return false
	for field in ["need_fruit", "got_fruit"]:
		if not s.get(field) is Array or s[field].size() != Puzzle.TYPES: return false
		for amount in s[field]:
			if not _integer(amount): return false
	var met = true
	for color in Puzzle.TYPES:
		if s.need_fruit[color] != int(level.get(Puzzle.FRUIT_KEYS[color], 0)): return false
		if s.got_fruit[color] < s.need_fruit[color]: met = false
	if s.need_ice != int(level.get("ice", 0)) or s.need_crate != int(level.get("crate", 0)): return false
	if s.got_ice > s.need_ice or s.got_crate > s.need_crate: return false
	met = met and s.got_ice >= s.need_ice and s.got_crate >= s.need_crate
	if s.phase == "win":
		if not met or s.stars != Puzzle.stars_for(int(s.moves), int(level.moves)): return false
	elif s.stars != 0 or met or (s.phase == "lose" and s.moves != 0) or (s.phase == "idle" and s.moves <= 0):
		return false
	if not s.get("board") is Array or s.board.size() != Puzzle.ROWS: return false
	var ids = {}
	for r in Puzzle.ROWS:
		if not s.board[r] is Array or s.board[r].size() != Puzzle.COLS: return false
		for c in Puzzle.COLS:
			var gem = s.board[r][c]
			if not gem is Dictionary: return false
			if not _integer(gem.get("id"), 1, int(s._gid) - 1) or ids.has(gem.id): return false
			ids[gem.id] = true
			if not _integer(gem.get("type"), -2, Puzzle.TYPES - 1) or not _integer(gem.get("look"), -1, Puzzle.TYPES - 1): return false
			if not _integer(gem.get("special"), Puzzle.SP_NONE, Puzzle.SP_RAIN): return false
			if not gem.get("ice") is bool or not gem.get("crate") is bool: return false
			if not _integer(gem.get("r"), r, r) or not _integer(gem.get("c"), c, c): return false
			if gem.crate:
				if gem.type != -2 or gem.special != Puzzle.SP_NONE or gem.ice: return false
			elif gem.type == -2 or (gem.type == -1 and gem.special != Puzzle.SP_RAIN): return false
	return true

func _valid(s: Variant) -> bool:
	if not s is Dictionary or s.get("version") != VERSION: return false
	if not s.get("first_puzzle_completed") is bool or not s.get("first_run") is bool: return false
	if not s.get("phase") in ["title", "puzzle", "completion", "cafe"]: return false
	if not s.get("attempt_id") is String or not s.get("puzzle_snapshot") is Dictionary: return false
	if s.phase in ["title", "cafe"]:
		return s.attempt_id.is_empty() and s.puzzle_snapshot.is_empty() and not s.first_run and (s.phase != "cafe" or s.first_puzzle_completed)
	if s.attempt_id.length() < 8 or s.attempt_id.length() > 256: return false
	if s.first_run == s.first_puzzle_completed or not _valid_snapshot(s.puzzle_snapshot): return false
	if s.first_run and s.puzzle_snapshot.level_index != 0: return false
	return (s.phase == "puzzle" and s.puzzle_snapshot.phase == "idle") or (s.phase == "completion" and s.puzzle_snapshot.phase in ["win", "lose"])

func _parse(raw: Variant) -> Dictionary:
	if not raw is String or raw.to_utf8_buffer().size() > MAX_BYTES: return {}
	var parser = JSON.new()
	if parser.parse(raw) != OK or not _valid(parser.data): return {}
	var parsed: Dictionary = parser.data
	parsed.version = int(parsed.version)
	if not parsed.puzzle_snapshot.is_empty():
		var snapshot: Dictionary = parsed.puzzle_snapshot
		for field in SNAPSHOT_INTS: snapshot[field] = int(snapshot[field])
		for field in ["need_fruit", "got_fruit"]:
			for i in snapshot[field].size(): snapshot[field][i] = int(snapshot[field][i])
		for row in snapshot.board:
			for gem in row:
				for field in ["id", "type", "look", "special", "r", "c"]: gem[field] = int(gem[field])
	return parsed

func load_state() -> Dictionary:
	last_error = ""
	recovered_backup = false
	var raw = storage.get_item(Store.KEY)
	if not storage.last_error.is_empty():
		last_error = storage.last_error
		state = {}
		return {}
	if raw == null:
		state = fresh()
		return state.duplicate(true)
	var loaded = _parse(raw)
	if not loaded.is_empty():
		state = loaded
		return state.duplicate(true)
	var backup_raw = storage.get_item(Store.KEY + ":backup")
	var backup = _parse(backup_raw)
	if storage.last_error.is_empty() and not backup.is_empty():
		if storage.commit(backup_raw, null, raw):
			state = backup
			recovered_backup = true
			return state.duplicate(true)
		last_error = storage.last_error
	else:
		last_error = "퍼즐 저장을 읽을 수 없어요. 원본을 보존했습니다."
	state = {}
	return {}

func should_first_puzzle() -> bool:
	if state.is_empty(): load_state()
	return not state.get("first_puzzle_completed", false)

func _ready_state() -> bool:
	return not load_state().is_empty()

func _commit(next: Dictionary) -> Dictionary:
	if not _valid(next): return _fail("invalid_state", "퍼즐 저장 형식이 맞지 않아요. 이전 저장을 보존했습니다.")
	var previous = storage.get_item(Store.KEY)
	if not storage.last_error.is_empty(): return _fail("storage", storage.last_error)
	if previous != null and _parse(previous).is_empty(): return _fail("invalid_save", "퍼즐 원본 저장을 보존했습니다.")
	var raw = JSON.stringify(next, "", true, true)
	if raw.to_utf8_buffer().size() > MAX_BYTES: return _fail("invalid_state", "퍼즐 저장이 너무 커요.")
	if not storage.commit(raw, previous): return _fail("storage", storage.last_error)
	state = next.duplicate(true)
	last_error = ""
	return {"ok":true, "state":state.duplicate(true)}

func _snapshot(engine: RefCounted) -> Dictionary:
	var snapshot = {"phase":engine.phase}
	for field in SNAPSHOT_INTS: snapshot[field] = engine.get(field)
	for field in SNAPSHOT_ARRAYS: snapshot[field] = engine.get(field).duplicate(true)
	return snapshot

func begin_puzzle(attempt_id: String, engine: RefCounted, first_run: bool) -> Dictionary:
	if not _ready_state(): return _fail("invalid_save", last_error)
	if state.phase == "completion": return _fail("completion_pending", "먼저 퍼즐 결과를 확인해 주세요.")
	if first_run != not state.first_puzzle_completed: return _fail("first_run", "첫 퍼즐 진행 정보가 맞지 않아요.")
	if engine.phase != "idle": return _fail("phase", "시작할 퍼즐이 준비되지 않았어요.")
	var next = state.duplicate(true)
	next.phase = "puzzle"
	next.attempt_id = attempt_id
	next.first_run = first_run
	next.puzzle_snapshot = _snapshot(engine)
	return _commit(next)

func checkpoint(engine: RefCounted) -> Dictionary:
	if not _ready_state(): return _fail("invalid_save", last_error)
	if not state.phase in ["puzzle", "completion"]: return _fail("phase", "진행 중인 퍼즐이 없어요.")
	if engine.level_index != state.puzzle_snapshot.level_index: return _fail("level", "진행 중인 레벨이 맞지 않아요.")
	if state.phase == "completion" and engine.phase != state.puzzle_snapshot.phase: return _fail("completion_pending", "완료한 퍼즐 결과를 바꿀 수 없어요.")
	var next = state.duplicate(true)
	next.puzzle_snapshot = _snapshot(engine)
	next.phase = "completion" if engine.phase in ["win", "lose"] else "puzzle"
	return _commit(next)

func begin_completion(engine: RefCounted) -> Dictionary:
	if not engine.phase in ["win", "lose"]: return _fail("unfinished", "아직 퍼즐이 끝나지 않았어요.")
	return checkpoint(engine)

func acknowledge_completion() -> Dictionary:
	if not _ready_state(): return _fail("invalid_save", last_error)
	if state.phase != "completion": return _fail("phase", "확인할 퍼즐 결과가 없어요.")
	var next = state.duplicate(true)
	if next.first_run and next.puzzle_snapshot.phase == "win": next.first_puzzle_completed = true
	next.phase = "cafe" if next.first_puzzle_completed else "title"
	next.attempt_id = ""
	next.first_run = false
	next.puzzle_snapshot = {}
	return _commit(next)

func abandon_puzzle() -> Dictionary:
	## The controller must successfully call CafeModel.abandon first.
	if not _ready_state(): return _fail("invalid_save", last_error)
	if state.phase == "completion": return _fail("completion_pending", "먼저 퍼즐 결과를 확인해 주세요.")
	var next = state.duplicate(true)
	next.phase = "cafe" if next.first_puzzle_completed else "title"
	next.attempt_id = ""
	next.first_run = false
	next.puzzle_snapshot = {}
	return _commit(next)

func restore_engine(engine: RefCounted) -> bool:
	if not _ready_state(): return false
	if not state.phase in ["puzzle", "completion"]:
		last_error = "이어 할 퍼즐이 없어요."
		return false
	var snapshot: Dictionary = state.puzzle_snapshot
	# Copy primitives explicitly: JSON numbers are floats; engine counters and
	# bitwise RNG arithmetic must be restored as integers.
	for field in SNAPSHOT_INTS: engine.set(field, int(snapshot[field]))
	engine.phase = snapshot.phase
	engine.level_data = engine.levels[int(snapshot.level_index)].duplicate(true)
	engine.board = snapshot.board.duplicate(true)
	for row in engine.board:
		for gem in row:
			for field in ["id", "type", "look", "special", "r", "c"]: gem[field] = int(gem[field])
	for field in ["need_fruit", "got_fruit"]:
		var values: Array = []
		for value in snapshot[field]: values.append(int(value))
		engine.set(field, values)
	engine._steps = []
	engine._sync_goals()
	engine.last_result = {"accepted":true, "reason":"resumed", "steps":[], "cleared":int(snapshot._total_cleared), "score_delta":0, "moves":engine.moves, "phase":engine.phase, "stars":engine.stars, "goals":engine.goals.duplicate(true)}
	return true

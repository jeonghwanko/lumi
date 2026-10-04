extends SceneTree
## Run with isolated XDG_{DATA,CONFIG,CACHE}_HOME directories under /tmp:
## godot --headless --path godot --script res://tests/test_session.gd

const Session = preload("res://scripts/session_store.gd")
const Store = preload("res://scripts/save_store.gd")
const Puzzle = preload("res://scripts/puzzle_engine.gd")
const Cafe = preload("res://scripts/cafe_model.gd")
var checks = 0
var failures: Array = []
var scenarios = 0

func _check(value: bool, message: String = "check failed") -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _eq(actual: Variant, expected: Variant, message: String = "values differ") -> void:
	_check(actual == expected, message + " expected=" + str(expected) + " actual=" + str(actual))

func _scenario(name: String) -> void:
	scenarios += 1
	print("Session: " + name)

func _fixture(completed: bool = false) -> Dictionary:
	var store = Store.MemoryStore.new()
	var session = Session.new("", store)
	var state = session.fresh()
	if completed:
		state.first_puzzle_completed = true
		state.phase = "cafe"
		store.set_item(Store.KEY, JSON.stringify(state))
	return {"s":store, "session":session}

func _snapshot(engine) -> Dictionary:
	return Session.new()._snapshot(engine)

func _step(engine) -> void:
	var pair = engine.hint()
	_check(pair.size() == 2, "legal hint available")
	if pair.size() == 2: _check(engine.try_swap(pair[0], pair[1]).accepted, "hint accepted")

func _finish(engine) -> void:
	for i in 50:
		if engine.phase != "idle": return
		_step(engine)
	_check(false, "game must reach a terminal state")

func _initialize() -> void:
	ProjectSettings.set_setting("lumi/review_mode",false)
	_memory_scenarios()
	_disk_scenarios()
	print("SESSION TESTS: %d scenarios, %d checks, %d failures" % [scenarios, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _memory_scenarios() -> void:
	_scenario("fresh title cannot enter cafe or mark first complete early")
	var f = _fixture()
	var session = f.session
	_eq(session.load_state(), session.fresh())
	_check(session.should_first_puzzle())
	_check(f.s.data.is_empty(), "fresh read does not write")
	_eq(session.acknowledge_completion().reason, "phase")
	var engine = Puzzle.new(); engine.initialize(0, 1)
	_eq(session.begin_puzzle("attempt-first-1", engine, false).reason, "first_run")
	_check(session.begin_puzzle("attempt-first-1", engine, true).ok)
	_eq(session.state.phase, "puzzle")
	_check(not session.state.first_puzzle_completed)
	_eq(session.begin_completion(engine).reason, "unfinished")
	_eq(session.acknowledge_completion().reason, "phase")
	_eq(session.state.phase, "puzzle")

	_scenario("mid-puzzle exact native snapshot and independent restored board")
	_step(engine)
	_check(engine.use_plus())
	_check(engine.use_hammer(Vector2i(3, 3)).accepted)
	_check(session.checkpoint(engine).ok)
	var saved = _snapshot(engine)
	var reload = Session.new("", f.s)
	var restored = Puzzle.new()
	_check(reload.restore_engine(restored))
	_eq(_snapshot(restored), saved)
	_eq(restored.goals, engine.goals)
	_eq(restored._steps, [])
	_eq(restored.last_result.phase, engine.phase)
	_eq(restored.hammers, 1)
	_eq(restored.plus_left, 0)
	var cell_type = engine.board[0][0].type
	restored.board[0][0].type = (cell_type + 1) % Puzzle.TYPES
	_eq(engine.board[0][0].type, cell_type, "restored board never aliases source")
	_eq(reload.state.puzzle_snapshot.board[0][0].type, cell_type, "restored board never aliases session")

	_scenario("all levels resume deterministic board, counters, RNG and next action")
	for level in 8:
		for seed_value in [1, 123456, 0xffffffff]:
			f = _fixture(level != 0); session = f.session
			engine = Puzzle.new(); engine.initialize(level, seed_value)
			_check(session.begin_puzzle("deterministic-%d-%d" % [level, seed_value], engine, level == 0).ok)
			for turn in 3:
				if engine.phase != "idle": break
				_step(engine)
			_check(session.checkpoint(engine).ok)
			restored = Puzzle.new(); reload = Session.new("", f.s)
			_check(reload.restore_engine(restored))
			_eq(_snapshot(restored), _snapshot(engine), "resume level %d" % level)
			while engine.phase == "idle":
				var pair = engine.hint()
				_eq(restored.hint(), pair)
				var original_result = engine.try_swap(pair[0], pair[1])
				var restored_result = restored.try_swap(pair[0], pair[1])
				_eq(restored_result, original_result, "deterministic next action")
				_eq(_snapshot(restored), _snapshot(engine), "identical eventual result")
			_check(session.checkpoint(engine).ok)
			_eq(session.state.phase, "completion")

	_scenario("first win survives result-screen quit; cafe reward remains exactly once")
	f = _fixture(); session = f.session
	var cafe_storage = Store.MemoryStore.new()
	var cafe = Cafe.new(cafe_storage)
	engine = Puzzle.new(); engine.initialize(0, 1)
	_check(cafe.begin_attempt(1, "first-win-reward-1").ok)
	_check(session.begin_puzzle("first-win-reward-1", engine, true).ok)
	_finish(engine)
	_eq(engine.phase, "win")
	_check(session.begin_completion(engine).ok)
	_check(not session.state.first_puzzle_completed, "win alone does not skip presentation")
	_eq(session.state.phase, "completion")
	_eq(cafe.finish_attempt(session.state.attempt_id, true).amount, 100)
	reload = Session.new("", f.s); restored = Puzzle.new()
	_check(reload.restore_engine(restored))
	_eq(restored.phase, "win")
	_eq(cafe.finish_attempt(reload.state.attempt_id, true).amount, 0)
	_eq(Cafe.new(cafe_storage).read().balance, 100)
	_check(reload.begin_completion(restored).ok, "completion may be re-entered")
	_eq(reload.begin_puzzle("too-early-retry", restored, true).reason, "completion_pending")
	_eq(reload.abandon_puzzle().reason, "completion_pending")
	_check(reload.acknowledge_completion().ok)
	_eq(reload.state.phase, "cafe")
	_check(reload.state.first_puzzle_completed)
	_check(not Session.new("", f.s).should_first_puzzle())
	_eq(reload.acknowledge_completion().reason, "phase")
	_eq(cafe.read().balance, 100)

	_scenario("later cafe puzzle loss returns cafe without losing first completion")
	session = reload
	engine = Puzzle.new(); engine.initialize(0, 3)
	_check(session.begin_puzzle("later-lost-attempt-1", engine, false).ok)
	_finish(engine)
	_eq(engine.phase, "lose")
	_check(session.begin_completion(engine).ok)
	_check(session.acknowledge_completion().ok)
	_eq(session.state.phase, "cafe")
	_check(session.state.first_puzzle_completed)

	_scenario("first loss acknowledgment returns title; abandonment never completes first")
	f = _fixture(); session = f.session
	engine = Puzzle.new(); engine.initialize(0, 3)
	_check(session.begin_puzzle("first-loss-1", engine, true).ok)
	_finish(engine)
	_eq(engine.phase, "lose")
	_check(session.begin_completion(engine).ok)
	_check(session.acknowledge_completion().ok)
	_eq(session.state.phase, "title")
	_check(session.should_first_puzzle())
	engine.initialize(0, 1)
	_check(session.begin_puzzle("abandon-first-1", engine, true).ok)
	_check(session.abandon_puzzle().ok)
	_eq(session.state.phase, "title")
	_check(session.should_first_puzzle())
	_check(session.begin_puzzle("restart-first-1", engine, true).ok)
	_check(session.begin_puzzle("restart-first-2", engine, true).ok)
	_eq(session.state.attempt_id, "restart-first-2")

	_scenario("write failure preserves in-memory flag and durable pending completion")
	_finish(engine)
	_check(session.begin_completion(engine).ok)
	var previous = f.s.get_item(Store.KEY)
	var before = session.state.duplicate(true)
	f.s.fail_writes = true
	_eq(session.acknowledge_completion().reason, "storage")
	_eq(session.state, before)
	_eq(f.s.get_item(Store.KEY), previous)
	f.s.fail_writes = false
	_check(session.acknowledge_completion().ok)

	_scenario("malformed top-level and nested JSON fail closed; raw stays byte-identical")
	f = _fixture(); session = f.session
	engine.initialize(0, 1)
	_check(session.begin_puzzle("malformed-fixture-1", engine, true).ok)
	var valid = session.state.duplicate(true)
	var cases: Array = [null, [], "bad", 1, true, {}, {"version":99}]
	for field in valid:
		var broken = valid.duplicate(true); broken[field] = null; cases.append(broken)
	for field in valid.puzzle_snapshot:
		var broken = valid.duplicate(true); broken.puzzle_snapshot[field] = "bad"; cases.append(broken)
	for field in valid.puzzle_snapshot.board[0][0]:
		var broken = valid.duplicate(true); broken.puzzle_snapshot.board[0][0][field] = null; cases.append(broken)
	var broken = valid.duplicate(true); broken.puzzle_snapshot.board[0][1].id = broken.puzzle_snapshot.board[0][0].id; cases.append(broken)
	broken = valid.duplicate(true); broken.puzzle_snapshot._rng_state = 4294967296; cases.append(broken)
	broken = valid.duplicate(true); broken.puzzle_snapshot.moves = 0.5; cases.append(broken)
	broken = valid.duplicate(true); broken.phase = "completion"; cases.append(broken)
	broken = valid.duplicate(true); broken.first_puzzle_completed = true; cases.append(broken)
	for bad in cases:
		var raw = JSON.stringify(bad)
		var bad_store = Store.MemoryStore.new({Store.KEY:raw})
		var bad_session = Session.new("", bad_store)
		_check(bad_session.load_state().is_empty(), "bad save rejected")
		_check(not bad_session.last_error.is_empty())
		_check(not bad_session.begin_puzzle("never-overwrite-1", engine, true).ok)
		_eq(bad_store.get_item(Store.KEY), raw)

	_scenario("corrupt current recovers validated backup while preserving exact raw")
	f = _fixture(); session = f.session
	engine.initialize(0, 1)
	_check(session.begin_puzzle("recover-backup-1", engine, true).ok)
	var backup_expected = session.state.duplicate(true)
	_step(engine)
	_check(session.checkpoint(engine).ok)
	f.s.set_item(Store.KEY, "{broken raw \n")
	reload = Session.new("", f.s)
	_eq(reload.load_state(), backup_expected)
	_check(reload.recovered_backup)
	_eq(f.s.get_item(Store.KEY + ":before-restore"), "{broken raw \n")
	_eq(reload._parse(f.s.get_item(Store.KEY)), backup_expected)
	f.s.set_item(Store.KEY, "{broken-again")
	f.s.fail_stage = "before_restore"
	_check(reload.load_state().is_empty())
	_eq(f.s.get_item(Store.KEY), "{broken-again")
	f.s.fail_stage = ""
	_check(not reload.load_state().is_empty())

func _disk_scenarios() -> void:
	_scenario("native disk checkpoints, atomic failure stages and reload")
	var directory = "user://session-tests-" + str(OS.get_process_id())
	var path = directory + "/session.json"
	var session = Session.new(path)
	var engine = Puzzle.new(); engine.initialize(0, 1)
	_check(session.begin_puzzle("disk-first-puzzle-1", engine, true).ok)
	_check(FileAccess.file_exists(path))
	_step(engine)
	_check(session.checkpoint(engine).ok)
	var previous = FileAccess.get_file_as_string(path)
	var saved = session.state.duplicate(true)
	var restored = Puzzle.new()
	_check(Session.new(path).restore_engine(restored))
	_eq(_snapshot(restored), _snapshot(engine))
	_check(not JSON.parse_string(FileAccess.get_file_as_string(path + ".backup")).is_empty())
	_step(engine)
	for stage in ["write", "backup", "commit"]:
		session.storage.fail_writes = stage == "write"
		session.storage.fail_stage = "" if stage == "write" else stage
		_eq(session.checkpoint(engine).reason, "storage")
		_eq(FileAccess.get_file_as_string(path), previous)
		_eq(Session.new(path).load_state(), saved)
		session.storage.fail_writes = false
		session.storage.fail_stage = ""
	_check(session.checkpoint(engine).ok)

	_scenario("native corrupt bytes retained before validated recovery")
	var expected_backup = session._parse(FileAccess.get_file_as_string(path + ".backup"))
	_check(session.storage.set_item(Store.KEY, "{ native truncated session"))
	var reloaded = Session.new(path)
	_eq(reloaded.load_state(), expected_backup)
	_check(reloaded.recovered_backup)
	_eq(FileAccess.get_file_as_string(path + ".before-restore"), "{ native truncated session")
	_check(reloaded.restore_engine(restored))
	_eq(restored._rng_state, int(expected_backup.puzzle_snapshot._rng_state))

	# Only remove the disposable files owned by this suite.
	for suffix in ["", ".tmp", ".backup", ".backup.tmp", ".before-restore", ".before-restore.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

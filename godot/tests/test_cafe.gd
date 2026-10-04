extends SceneTree
## Run: godot --headless --path godot --script res://tests/test_cafe.gd
## The original 21 JS scenarios are reproduced, followed by native save/import
## failure cases. Uses isolated memory stores and an isolated user:// test path.
const Model = preload("res://scripts/cafe_model.gd")
const Store = preload("res://scripts/save_store.gd")
var checks = 0
var failures = 0
var scenarios = 0
var attempt_number = 0
var current_scenario = ""

func _initialize() -> void:
	ProjectSettings.set_setting("lumi/review_mode",false)
	call_deferred("_run")

func _check(condition: bool, label: String = "") -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL [%s] %s" % [current_scenario, label])

func _eq(actual: Variant, expected: Variant, label: String = "") -> void:
	# Godot JSON represents numbers as doubles; dictionary equality otherwise
	# distinguishes 20 from 20.0 even though schema/JSON numeric values agree.
	var same = actual == expected
	if actual is Dictionary or actual is Array:
		same = JSON.parse_string(JSON.stringify(actual, "", true, true)) == JSON.parse_string(JSON.stringify(expected, "", true, true))
	_check(same, "%s expected %s; got %s" % [label, str(expected), str(actual)])

func _scenario(name: String) -> void:
	current_scenario = name
	scenarios += 1
	print("TEST %02d %s" % [scenarios, name])

func _setup(initial: Dictionary = {}) -> Dictionary:
	attempt_number = 0
	var store = Store.MemoryStore.new(initial)
	return {"s":store, "m":Model.new(store)}

func _win(model: RefCounted, level: int = 1) -> Dictionary:
	attempt_number += 1
	var id = "attempt-" + str(attempt_number)
	_check(model.begin_attempt(level, id).ok, "begin win attempt")
	var result = model.finish_attempt(id, true)
	_check(result.ok, "finish win attempt: " + str(result.get("message", "")))
	return result

func _memories(model: RefCounted, kind: String) -> Array:
	return model.read().memories.filter(func(memory): return memory.kind == kind)

func _run() -> void:
	_original_scenarios()
	_native_scenarios()
	print("CAFE TESTS: %d scenarios, %d assertions, %d failures" % [scenarios, checks, failures])
	quit(0 if failures == 0 else 1)

func _original_scenarios() -> void:
	_scenario("36 facilities, unique dedicated cats, exact design chapter membership")
	var fixture = _setup()
	var m = fixture.m
	_eq(m.catalog.facilities.size(), 36)
	_eq(m.catalog.chapters.size(), 6)
	_eq(m.catalog.decorations.size(), 19)
	var cats = {}
	var members = {}
	for facility in m.catalog.facilities:
		cats[facility.catId] = true
		_check(facility.has("atlas"), "preserve atlas metadata")
	for chapter in m.catalog.chapters:
		for id in chapter.facilities: members[id] = true
	_eq(cats.size(), 36)
	_eq(members.size(), 36)
	_eq(m.catalog.chapters[0].facilities, ["f19", "f05", "f21", "f25", "f01", "f20"])

	_scenario("first and repeat wins pay, same completion cannot pay twice")
	fixture = _setup(); m = fixture.m
	_eq(_win(m).amount, 100)
	_eq(m.finish_attempt("attempt-1", true).amount, 0)
	_eq(_win(m).amount, 35)
	_eq(m.read().balance, 135)

	_scenario("failure and abandonment have no reward; unknown attempt rejected")
	fixture = _setup(); m = fixture.m
	m.begin_attempt(1, "loss-run-1")
	_eq(m.finish_attempt("loss-run-1", false).amount, 0)
	_eq(m.finish_attempt("loss-run-1", true).amount, 0)
	m.begin_attempt(1, "abort-run-1")
	m.abandon("abort-run-1")
	_eq(m.finish_attempt("abort-run-1", true).amount, 0)
	_eq(m.finish_attempt("missing", true).ok, false)
	_eq(m.read().balance, 0)

	_scenario("purchase atomicity, insufficient balance and duplicate purchase")
	fixture = _setup(); m = fixture.m
	_eq(m.purchase("f05").reason, "insufficient")
	_win(m)
	_check(m.purchase("f05").ok)
	_eq(m.read().balance, 20)
	_eq(m.purchase("f05").changed, false)
	_eq(m.read().balance, 20)
	_eq(m.read().chapter, 2)
	_eq(m.purchase("f07").reason, "locked")

	_scenario("all 36 facilities and three growth levels reachable with replay")
	fixture = _setup(); m = fixture.m
	for chapter in range(1, 7):
		for facility in m.catalog.facilities:
			if facility.chapter != chapter or m.read().owned.has(facility.id): continue
			while m.read().balance < facility.price: _win(m)
			_check(m.purchase(facility.id).ok, "purchase " + facility.id)
	for facility in m.catalog.facilities:
		while m.read().owned[facility.id].level < 3:
			var cost = facility.upgrades[int(m.read().owned[facility.id].level) - 1]
			while m.read().balance < cost: _win(m)
			_check(m.upgrade(facility.id).ok, "upgrade " + facility.id)
	_eq(m.read().owned.size(), 36)
	_eq(m.read().chapter, 6)
	for item in m.read().owned.values(): _eq(item.level, 3)
	_eq(m.upgrade("f05").changed, false)

	_scenario("layout save/store/restore, overlap bounds and stale edits atomic")
	fixture = _setup(); m = fixture.m
	_win(m); m.purchase("f05")
	var state = m.read()
	var draft = {"f19":state.owned.f19.position, "f05":{"x":22,"y":45}}
	_check(m.save_layout(draft, state.revision).ok)
	state = m.read()
	var previous = fixture.s.get_item(Model.KEY)
	var bad = draft.duplicate(true); bad.f05 = draft.f19.duplicate()
	_eq(m.save_layout(bad, state.revision).reason, "overlap")
	_eq(fixture.s.get_item(Model.KEY), previous)
	bad.f05 = {"x":1,"y":45}
	_eq(m.save_layout(bad, state.revision).reason, "bounds")
	_eq(m.save_layout(draft, state.revision - 1).reason, "conflict")
	bad.f05 = null
	_check(m.save_layout(bad, state.revision).ok)
	_eq(m.read().owned.f05.position, null)
	_eq(m.read().owned.f05.level, 1)

	_scenario("reload preferences, companion and project survive")
	fixture = _setup(); m = fixture.m
	_win(m); m.purchase("f05"); m.set_project("f13"); m.set_companion("cat05"); m.setting(true)
	var reload = Model.new(fixture.s).read()
	_eq(reload.project, "f13"); _eq(reload.companion, "cat05"); _eq(reload.settings.reduceMotion, true)
	_eq(reload, m.read())

	_scenario("v1 migration preserves raw, balance, ownership and first clears")
	var old = {"version":1,"balance":60,"claimed":[1],"owned":["drip"],"slots":[null,null,"drip",null,null,null]}
	var raw = JSON.stringify(old)
	fixture = _setup({Model.OLD:raw}); m = fixture.m
	state = m.read()
	_eq(state.balance, 60); _check(state.owned.has("f05")); _eq(state.owned.f05.position.x, 78)
	_eq(_win(m).amount, 35); _eq(m.read().balance, 95); _eq(fixture.s.get_item(Model.OLD), raw)

	_scenario("corrupt save intact and storage failure cannot spend")
	fixture = _setup({Model.KEY:"{"}); m = fixture.m
	_check(m.read().is_empty()); _check(not m.last_error.is_empty()); _eq(fixture.s.get_item(Model.KEY), "{")
	fixture = _setup(); m = fixture.m; _win(m)
	previous = fixture.s.get_item(Model.KEY)
	fixture.s.fail_writes = true
	_eq(m.purchase("f05").reason, "storage")
	_eq(fixture.s.get_item(Model.KEY), previous); _eq(m.read().balance, 100)

	_scenario("facility story two distinct wins; repeat completion idempotent")
	fixture = _setup(); m = fixture.m
	m.begin_order("f19"); _win(m); m.finish_attempt("attempt-1", true)
	_eq(m.read().order.completed, 1)
	_win(m)
	_eq(m.read().order.completed, 2); _eq(_memories(m, "story").size(), 1)
	_eq(m.begin_order("f19").reason, "complete"); _eq(m.read().balance, 135)

	_scenario("remembered garden and free lighting survive without layout change")
	fixture = _setup(); m = fixture.m
	m.lighting("night"); var owned_before = m.read().owned
	m.remember("photo-test-1"); m.lighting("sunset")
	state = Model.new(fixture.s).read()
	_eq(state.settings.lighting, "sunset"); _eq(state.memories[0].lighting, "night")
	_eq(state.memories[0].layout, owned_before); _eq(state.owned, owned_before)

	_scenario("reopening active order preserves progress")
	fixture = _setup(); m = fixture.m
	m.begin_order("f19"); _win(m); m.begin_order("f19")
	_eq(m.read().order.completed, 1)

	_scenario("decor purchase atomic; surfaces and placements persist independently")
	fixture = _setup(); m = fixture.m
	_eq(m.purchase_decoration("d-plant").reason, "insufficient")
	_win(m)
	_check(m.purchase_decoration("d-wood-floor").ok)
	_check(m.equip_surface("d-wood-floor").ok); _check(m.purchase_decoration("d-plant").ok)
	var balance = m.read().balance
	_eq(m.purchase_decoration("d-plant").changed, false); _eq(m.read().balance, balance)
	state = m.read()
	_check(m.save_layout({"f19":state.owned.f19.position}, state.revision, {"d-wood-floor":null,"d-plant":{"x":20,"y":70}}).ok)
	reload = Model.new(fixture.s).read()
	_eq(reload.surfaces.floor, "d-wood-floor"); _eq(reload.decorOwned["d-plant"].position, {"x":20,"y":70}); _eq(reload.owned.f19.level, 1)

	_scenario("decoration collisions, bounds and cancel-by-no-write preserve layout")
	fixture = _setup(); m = fixture.m
	_win(m); m.purchase_decoration("d-plant"); state = m.read(); raw = fixture.s.get_item(Model.KEY)
	var layout = {"f19":state.owned.f19.position}
	_eq(m.save_layout(layout, state.revision, {"d-plant":state.owned.f19.position}).reason, "overlap")
	_eq(m.save_layout(layout, state.revision, {"d-plant":{"x":0,"y":50}}).reason, "bounds")
	_eq(fixture.s.get_item(Model.KEY), raw)

	_scenario("orders retain independent progress, require placement, serve once")
	fixture = _setup(); m = fixture.m
	_win(m); m.purchase("f05"); m.begin_order("f05"); _win(m); m.begin_order("f19"); _win(m); m.begin_order("f05")
	_eq(m.read().order.completed, 1)
	_win(m); _eq(m.serve_order().reason, "stored")
	state = m.read(); m.save_layout({"f19":state.owned.f19.position,"f05":{"x":22,"y":45}}, state.revision)
	_check(m.serve_order().ok); _eq(m.read().visits.f05, 1); _eq(m.serve_order().changed, false); _eq(m.read().visits.f05, 1)
	m.begin_order("f19"); _eq(m.read().order.completed, 1)

	_scenario("prior behavior selection preserves growth and storage")
	fixture = _setup(); m = fixture.m
	for i in range(5): _win(m)
	m.purchase("f05"); m.upgrade("f05"); _check(m.behavior("f05", 1).ok)
	state = m.read(); m.save_layout({"f19":state.owned.f19.position,"f05":null}, state.revision)
	_eq(Model.new(fixture.s).read().owned.f05.actionStage, 1); _eq(m.read().owned.f05.level, 2); _eq(m.behavior("f05", 3).reason, "stage")

	_scenario("verified backup restores corrupt save; invalid import preserves raw")
	fixture = _setup(); m = fixture.m
	_win(m); var correct = fixture.s.get_item(Model.KEY); m.setting(true); fixture.s.set_item(Model.KEY, "{broken")
	_check(m.read().is_empty()); _eq(m.restore_save("{broken").reason, "invalid_save"); _eq(fixture.s.get_item(Model.KEY), "{broken")
	_check(m.restore_backup().ok); _eq(m.read().balance, 100); _eq(fixture.s.get_item(Model.KEY + ":before-restore"), "{broken")
	bad = JSON.parse_string(correct); bad.balance += 1; raw = fixture.s.get_item(Model.KEY)
	_eq(m.restore_save(JSON.stringify(bad)).reason, "invalid_save"); _eq(fixture.s.get_item(Model.KEY), raw)

	_scenario("old v2 normalizes without overwrite; corrupt memories reject")
	fixture = _setup(); m = fixture.m; _win(m)
	old = m.read()
	for field in ["decorOwned", "surfaces", "orderBook", "visits"]: old.erase(field)
	fixture.s.set_item(Model.KEY, JSON.stringify(old)); raw = fixture.s.get_item(Model.KEY)
	_eq(m.read().decorOwned, {}); _eq(fixture.s.get_item(Model.KEY), raw)
	old.memories = [{"id":"bad","kind":"arrival","facility":"missing"}]
	_eq(m.restore_save(JSON.stringify(old)).reason, "invalid_save")

	_scenario("companion records use cat at start, count once, persist")
	fixture = _setup(); m = fixture.m
	_win(m); m.purchase("f05"); m.begin_attempt(1, "companion-start-1"); m.set_companion("cat05")
	m.finish_attempt("companion-start-1", true); m.finish_attempt("companion-start-1", true)
	_eq(m.read().companionRecords.cat19.wins, 2); _check(not m.read().companionRecords.has("cat05"))
	_win(m); _eq(Model.new(fixture.s).read().companionRecords.cat05.wins, 1)
	_eq(m.read().memories.filter(func(memory): return memory.id == "companion:cat05").size(), 1)

	_scenario("corrupt memory fields and unsafe IDs rejected before import")
	fixture = _setup(); m = fixture.m
	m.remember("photo-safe-1"); state = m.read(); raw = fixture.s.get_item(Model.KEY)
	state.memories[0].id = 'x" onclick="alert(1)'
	_eq(m.restore_save(JSON.stringify(state)).reason, "invalid_save")
	state.memories[0].id = "photo-safe-1"; state.memories[0].layout.f19.actionStage = "bad"
	_eq(m.restore_save(JSON.stringify(state)).reason, "invalid_save"); _eq(fixture.s.get_item(Model.KEY), raw)

	_scenario("audio/effects settings normalize, persist; project gift exactly once")
	fixture = _setup(); m = fixture.m
	m.sound(false); m.effects("low")
	_eq(Model.new(fixture.s).read().settings.sound, false); _eq(m.read().settings.effects, "low")
	_win(m); var first = m.purchase("f05"); _eq(first.gift, "d-coaster"); balance = m.read().balance
	_check(m.read().decorOwned.has("d-coaster")); _eq(m.purchase("f05").changed, false); _eq(m.read().balance, balance); _eq(m.effects("unknown").reason, "effects")

func _native_scenarios() -> void:
	_scenario("native disk save, reload and export are schema-compatible")
	var path = "user://model-tests-" + str(OS.get_process_id()) + "/save.json"
	var store = Store.new(path)
	var m = Model.new(store)
	attempt_number = 0
	_eq(_win(m).amount, 100)
	_check(FileAccess.file_exists(path))
	var state = m.read()
	_eq(Model.new(Store.new(path)).read(), state)
	_eq(JSON.parse_string(m.export_save()), state)
	_eq(JSON.parse_string(store.get_item(Model.KEY + ":backup")).balance, 0)

	_scenario("native write, backup and final rename failures cannot spend")
	var previous = store.get_item(Model.KEY)
	store.fail_writes = true
	_eq(m.purchase("f05").reason, "storage"); _eq(store.get_item(Model.KEY), previous); _eq(m.read().balance, 100)
	store.fail_writes = false
	for stage in ["backup", "commit"]:
		store.fail_stage = stage
		_eq(m.purchase("f05").reason, "storage"); _eq(store.get_item(Model.KEY), previous); _eq(Model.new(Store.new(path)).read().balance, 100)
	store.fail_stage = ""
	_check(m.purchase("f05").ok); _eq(m.read().balance, 20)
	_check(m.read().owned.has("f05"))

	_scenario("native corrupt raw preserved, validated backup recoverable")
	var backup_before = store.get_item(Model.KEY + ":backup")
	store.set_item(Model.KEY, "{broken-disk-save")
	_check(m.read().is_empty()); _eq(m.purchase("f19").reason, "invalid_save")
	_eq(store.get_item(Model.KEY), "{broken-disk-save")
	_check(m.restore_backup().ok)
	_eq(m.read().balance, 100); _eq(store.get_item(Model.KEY + ":before-restore"), "{broken-disk-save")
	_eq(store.get_item(Model.KEY + ":backup"), backup_before)

	_scenario("explicit browser v1 import preserves money/history; invalid import atomic")
	var legacy = {"version":1,"balance":60,"claimed":[1],"owned":["drip"],"slots":[null,null,"drip",null,null,null]}
	previous = store.get_item(Model.KEY)
	_check(m.restore_save(JSON.stringify(legacy)).ok)
	_eq(m.read().migration, "v1"); _eq(m.read().balance, 60); _eq(m.read().owned.f05.position.x, 78)
	_eq(store.get_item(Model.KEY + ":before-restore"), previous)
	previous = store.get_item(Model.KEY)
	legacy.owned.append("unknown")
	_eq(m.restore_save(JSON.stringify(legacy)).reason, "invalid_save"); _eq(store.get_item(Model.KEY), previous)

	_scenario("native import backup failure cannot overwrite current save")
	var imported = Model.new(Store.MemoryStore.new()).export_save()
	store.fail_stage = "before_restore"
	_eq(m.restore_save(imported).reason, "storage"); _eq(store.get_item(Model.KEY), previous)
	store.fail_stage = ""

	_scenario("read normalization never silently writes; older v2 orders repaired")
	var fixture = _setup(); m = fixture.m
	var old = m.fresh()
	old.settings.erase("sound"); old.settings.erase("effects"); old.erase("companionRecords")
	old.order = {"facility":"f19","completed":1}
	old.erase("orderBook")
	var raw = JSON.stringify(old)
	fixture.s.set_item(Model.KEY, raw)
	state = m.read()
	_eq(state.settings.sound, true); _eq(state.settings.effects, "full"); _eq(state.companionRecords, {})
	_eq(state.order.served, false); _eq(state.orderBook.f19.completed, 1); _eq(fixture.s.get_item(Model.KEY), raw)

	_scenario("defensive import validator rejects malformed values without runtime errors")
	fixture = _setup(); m = fixture.m; m.setting(false)
	previous = fixture.s.get_item(Model.KEY)
	for field in ["owned", "attempts", "settings", "decorOwned", "surfaces", "orderBook", "visits", "companionRecords", "ledger", "claimedLevels", "memories"]:
		var bad = m.read(); bad[field] = "malformed"
		_eq(m.restore_save(JSON.stringify(bad)).reason, "invalid_save", field)
		_eq(fixture.s.get_item(Model.KEY), previous)
	for value in [null, [], "value", 3, true]:
		_eq(m.restore_save(JSON.stringify(value)).reason, "invalid_save")
		_eq(fixture.s.get_item(Model.KEY), previous)
	var bad = m.read(); bad.revision = 0.5
	_eq(m.restore_save(JSON.stringify(bad)).reason, "invalid_save")
	bad = m.read(); bad.balance = 9007199254740992; bad.openingBalance = 9007199254740992
	_eq(m.restore_save(JSON.stringify(bad)).reason, "invalid_save")
	bad = m.read(); bad.owned.f19.position.x = 93
	_eq(m.restore_save(JSON.stringify(bad)).reason, "invalid_save")
	bad = m.read(); bad.companion = "cat00"
	_eq(m.restore_save(JSON.stringify(bad)).reason, "invalid_save")
	bad = m.read(); bad.order = {"facility":"f19","completed":0,"served":"yes"}
	_eq(m.restore_save(JSON.stringify(bad)).reason, "invalid_save")
	_eq(fixture.s.get_item(Model.KEY), previous)

	_scenario("no-op operations, invalid actions, return values cannot mutate saved state")
	fixture = _setup(); m = fixture.m
	_eq(m.begin_attempt(0, "bad-attempt").reason, "attempt")
	_eq(m.begin_attempt(1, "short").reason, "attempt")
	_eq(m.set_companion("cat05").reason, "owned")
	_eq(m.set_project("missing").reason, "facility")
	_eq(m.purchase("missing").reason, "facility")
	_eq(m.upgrade("f05").reason, "owned")
	_eq(m.equip_surface("d-plant").reason, "decoration")
	_eq(m.purchase_decoration("missing").reason, "decoration")
	_eq(m.lighting("unknown").reason, "lighting")
	_eq(m.remember("bad/id-1").reason, "id")
	_eq(m.restore_backup().reason, "no_backup")
	var result = m.remember("photo-idempotent-1")
	_check(result.ok)
	previous = fixture.s.get_item(Model.KEY)
	_eq(m.remember("photo-idempotent-1").changed, false)
	result.state.owned.f19.level = 3
	_eq(fixture.s.get_item(Model.KEY), previous)
	_eq(m.read().owned.f19.level, 1)

	_scenario("second model detects stale edit revision, draft never aliases state")
	fixture = _setup(); m = fixture.m
	state = m.read(); var draft = {"f19":{"x":20,"y":45}}
	var second_model = Model.new(fixture.s)
	second_model.sound(false)
	_eq(m.save_layout(draft, state.revision).reason, "conflict")
	state = m.read(); _check(m.save_layout(draft, state.revision).ok)
	draft.f19.x = 80
	_eq(m.read().owned.f19.position.x, 20)

	_scenario("surfaces cannot be placed as furniture, decor overlap and missing lists reject")
	fixture = _setup(); m = fixture.m; _win(m)
	m.purchase_decoration("d-wood-floor"); m.purchase_decoration("d-plant"); state = m.read()
	var layout = {"f19":state.owned.f19.position}
	_eq(m.save_layout(layout, state.revision, {"d-wood-floor":{"x":20,"y":80},"d-plant":null}).reason, "surface")
	_eq(m.save_layout(layout, state.revision, {}).reason, "layout")
	_eq(m.save_layout({}, state.revision).reason, "layout")

	_scenario("safe-integer money and fractional placement round-trip exactly")
	fixture = _setup(); m = fixture.m
	state = m.fresh(); state.balance = 9007199254740991; state.openingBalance = 9007199254740991
	state.owned.f19.position = {"x":48.1234567890123,"y":19.9876543210987}
	_check(m.restore_save(JSON.stringify(state, "", true, true)).ok)
	_eq(m.read().balance, 9007199254740991)
	_check(m.setting(true).ok)
	_eq(m.read().balance, 9007199254740991)
	_eq(m.read().owned.f19.position.x, state.owned.f19.position.x)
	_check(m.begin_attempt(1, "overflow-safe-1").ok)
	previous = fixture.s.get_item(Model.KEY)
	_eq(m.finish_attempt("overflow-safe-1", true).reason, "invalid_save")
	_eq(fixture.s.get_item(Model.KEY), previous)
	_eq(m.read().balance, 9007199254740991)

	_scenario("malformed nested import fields fail closed without changing raw")
	fixture = _setup(); m = fixture.m; m.setting(false)
	previous = fixture.s.get_item(Model.KEY)
	var malformed_states = []
	for value in [null, [], "bad", true, 1]:
		var malformed = m.read(); malformed.owned.f19 = value; malformed_states.append(malformed)
		malformed = m.read(); malformed.ledger = [value]; malformed_states.append(malformed)
		malformed = m.read(); malformed.memories = [value]; malformed_states.append(malformed)
		malformed = m.read(); malformed.attempts = {"attempt-bad-1":value}; malformed_states.append(malformed)
		malformed = m.read(); malformed.companionRecords = {"cat19":value}; malformed_states.append(malformed)
		malformed = m.read(); malformed.orderBook = {"f19":value}; malformed_states.append(malformed)
		malformed = m.read(); malformed.decorOwned = {"d-plant":value}; malformed_states.append(malformed)
	for malformed in malformed_states:
		_eq(m.restore_save(JSON.stringify(malformed)).reason, "invalid_save")
		_eq(fixture.s.get_item(Model.KEY), previous)

	# Only remove this suite's own disposable test files.
	for suffix in ["", ".tmp", ".backup", ".backup.tmp", ".before-restore", ".before-restore.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir()))

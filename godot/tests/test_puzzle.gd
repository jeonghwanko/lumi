extends SceneTree
## Run: godot --headless --path godot --script res://tests/test_puzzle.gd
## Fixture strings below were independently captured from the unchanged JS engine
## through its seeded boot and first three row-major legal hints, not from this port.

const EngineScript = preload("res://scripts/puzzle_engine.gd")
const JS_TERMINALS = [
	[510,5,"win","0135420431354530250205223231034142421401210430103515421455355400",[0,12,0,0,0,0],0,0],
	[480,2,"win","1455405200335422215055312523212233004405153140454250355330552155",[0,12,0,0,0,0],0,0],
	[620,0,"lose","0103040521454033140545135150240240025344330235222345324425534540",[0,7,0,0,0,0],0,0],
	[540,0,"lose","4032404230343235225214301425302240421303130554213204502543513234",[0,9,0,0,0,0],0,0],
	[570,0,"win","0133032554414031541034311032115225122545343033143052251151502423",[0,12,0,0,0,0],0,0],
	[740,0,"lose","2131415411055342432501032104234432154402210430103515421455355400",[0,0,0,0,0,13],3,0],
	[720,0,"lose","5202015144554204353130310515213203004405153140454250355330552155",[0,0,0,0,0,12],0,0],
	[720,0,"lose","1212551004105215220200405523140240055344330035222345324425534540",[0,0,0,0,0,9],0,0],
	[830,0,"lose","4235243501242404005303021434002240411303130554213204502543513234",[0,0,0,0,0,17],3,0],
	[770,0,"lose","2113544250020521525425411301415220403545343033143052251151502423",[0,0,0,0,0,6],3,0],
	[330,13,"win","3033020431513530203305223424434142411401210430103515421455355400",[0,9,0,0,0,9],0,0],
	[510,5,"win","1454305200332422215005312523212233004405153140454250355330552155",[0,12,0,0,0,9],0,0],
	[740,0,"lose","0105230521441233140513135150240240025344330235222345324425534540",[0,7,0,0,0,13],0,0],
	[390,9,"win","4534325530520035224414301422302240421303130554213204502543513234",[0,9,0,0,0,9],0,0],
	[480,7,"win","4104002551414031541034311032115225122545343033143052251151502423",[0,9,0,0,0,9],0,0],
	[680,0,"lose","5421504550531210403143032525515135112301210430103515421455355400",[0,0,0,6,0,0],4,0],
	[720,0,"lose","5202015144554204353130310515213203004405153140454250355330552155",[0,0,0,12,0,0],0,0],
	[920,0,"lose","0140113023531515213105304321340251252344310035222345324425534540",[0,0,0,8,0,0],3,0],
	[830,0,"lose","4235243501242404005303021434002240411303130554213204502543513234",[0,0,0,17,0,0],3,0],
	[770,0,"lose","2113544250020521525425411301415220403545343033143052251151502423",[0,0,0,14,0,0],3,0],
	[840,0,"lose","23532413054125035414051434335341.245140.210430103515421..535.400",[0,0,17,0,0,0],0,1],
	[1010,0,"lose","51510025511553202042023.5030232232004405153140454250355330552.55",[0,0,15,0,0,0],0,4],
	[890,0,"lose","514412203055344100131005455022454024552233103522234532442.534540",[0,0,15,0,0,0],0,5],
	[1150,0,"lose","52312350315312343143510523314523100350031352442132445.25.3513234",[0,0,21,0,0,0],0,4],
	[1010,0,"lose","45354314323510010011212130551252151401450430341420.2031151503523",[0,0,18,0,0,0],0,5],
	[750,8,"win","0015420435154530514205223101034145421401200430103115421450355400",[9,0,0,0,9,0],0,0],
	[420,10,"win","1031105201515422323355312523212233004405153140454250355330552155",[9,0,0,0,9,0],0,0],
	[560,8,"win","0330411521451033140545135150240240025344330235222345324425534540",[10,0,0,0,11,0],0,0],
	[510,7,"win","4032545530343235225214301425302240421303130554213204502543513234",[9,0,0,0,12,0],0,0],
	[390,12,"win","4134453151515052545034311025115225122545343033143052251151502423",[9,0,0,0,9,0],0,0],
	[1180,0,"lose","1051334012132441203231503405153352450455010430103515421..5355400",[0,22,0,9,0,0],0,2],
	[1010,0,"lose","5112142113505351234005500511412341452405152100454250355330552.55",[0,15,0,16,0,0],0,3],
	[850,0,"lose","5244054012431245112505.03515030240225.4433123522234532442.534540",[0,9,0,12,0,0],0,1],
	[990,0,"lose","34023322534055044214340042341021334230031352142132445.2543513234",[0,12,0,9,0,0],0,3],
	[1030,0,"lose","54541140432303352121230111415152251504453430331430.2251151502423",[0,21,0,14,0,0],0,3],
	[890,0,"lose","2002125414334142441553032322014432112302210430103515421455355400",[0,0,0,0,12,16],3,0],
	[840,0,"lose","5250415141432204350530310235213203004405153140454250355330552155",[0,0,0,0,15,15],0,0],
	[840,0,"lose","1252022304121141221052455523140240055344330035222345324425534540",[0,0,0,0,12,12],0,0],
	[980,0,"lose","4235004501245434005312121434032240411003130554213204502543513234",[0,0,0,0,19,17],3,0],
	[890,0,"lose","2113320050020423525423421301415220403545343033143052251151502423",[0,0,0,0,19,9],3,0]
]
var checks = 0
var failures: Array = []
var games = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func types(engine) -> String:
	var result = ""
	for row in engine.board:
		for gem in row:
			result += str(gem.type) if gem != null and gem.type >= 0 else "."
	return result

func count_flag(engine, flag: String) -> int:
	var result = 0
	for row in engine.board:
		for gem in row:
			if gem != null and gem[flag]:
				result += 1
	return result

func clean_fixture():
	var engine = EngineScript.new()
	engine.initialize(0, 7)
	for r in 8:
		for c in 8:
			engine.board[r][c] = engine.make_gem(Vector2i(c, r), (c + 2 * r) % 6)
	engine.need_fruit = [999, 999, 999, 999, 999, 999]
	engine.need_ice = 999
	engine.need_crate = 999
	return engine

func paint_run(engine, cells: Array, color: int = 2) -> void:
	for pos in cells:
		engine.gem_at(pos).type = color

func first_step(result: Dictionary, kind: String) -> Dictionary:
	for step in result.steps:
		if step.kind == kind:
			return step
	return {}

func _initialize() -> void:
	ProjectSettings.set_setting("lumi/review_mode",false)
	var engine = EngineScript.new()
	check(engine.levels.size() == 8, "eight level definitions")
	var budgets = [18, 24, 22, 24, 26, 24, 26, 28]
	for level in 8:
		for seed_value in range(1, 9):
			engine.initialize(level, seed_value)
			check(engine.moves == budgets[level], "original move budget %d" % level)
			check(engine.board.size() == 8 and types(engine).length() == 64, "64 cells %d/%d" % [level, seed_value])
			check(engine.find_runs().is_empty() and engine.hint().size() == 2, "playable opening %d/%d" % [level, seed_value])
			check(count_flag(engine, "ice") == engine.need_ice, "opening ice count %d/%d" % [level, seed_value])
			check(count_flag(engine, "crate") == engine.need_crate, "opening crate count %d/%d" % [level, seed_value])
			for r in 8:
				for c in 8:
					var gem = engine.board[r][c]
					check(gem.r == r and gem.c == c, "opening coordinates")
					if gem.ice:
						check(engine._same_neighbor(Vector2i(c, r), gem.type), "reachable opening ice")
					if gem.crate:
						check(not gem.ice and gem.type == -2, "crate is not iced or matchable")
	_test_js_parity()
	_test_swaps()
	_test_special_creation()
	_test_special_combos()
	_test_rule_edges()
	_test_ice_crates_boosters()
	_test_stars_and_end()
	_test_seeded_games()
	print(JSON.stringify({"ok": failures.is_empty(), "assertions": checks, "seeded_games": games, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _test_js_parity() -> void:
	var expected_boards = [
		"3135453450350420202410023411434142451401210430103515421455355400",
		"2351513430350210212411023411434142451401210430103515421455355400",
		"3135453450350420202410023411434142451401210430103515421455355400",
		"2351513430350210212411023411434142451401210430103515421455355400",
		"31031134533202102025110234114341.245140.210430103515421..535.400",
		"3135453450350420202410023411434142451401210430103515421455355400",
		"23405134002452102025110234114341.2451401210430103515421..5355400",
		"2351513430350210212411023411434142451401210430103515421455355400"
	]
	var expected_scores = [90, 90, 90, 90, 100, 90, 130, 90]
	for level in 8:
		var engine = EngineScript.new()
		engine.initialize(level, 1)
		if engine.need_crate == 0:
			check(types(engine) == "3035513425220210202411023411434142451401210430103515421455355400", "exact JS opening %d" % level)
		for move in 3:
			var pair = engine.hint()
			check(engine.try_swap(pair[0], pair[1]).accepted, "JS parity accepted hint")
		check(types(engine) == expected_boards[level], "exact JS board after three seeded turns, level %d" % (level + 1))
		check(engine.score == expected_scores[level], "exact JS score after three seeded turns, level %d" % (level + 1))

func _test_swaps() -> void:
	var engine = EngineScript.new()
	engine.initialize(0, 3)
	var before = engine.board.duplicate(true)
	var old_moves = engine.moves
	var invalid: Array = []
	for r in 8:
		for c in 7:
			if not engine.is_legal_swap(Vector2i(c, r), Vector2i(c + 1, r)):
				invalid = [Vector2i(c, r), Vector2i(c + 1, r)]
				break
		if not invalid.is_empty():
			break
	var rejected = engine.try_swap(invalid[0], invalid[1])
	check(not rejected.accepted and engine.board == before and engine.moves == old_moves and engine.score == 0, "invalid swap restores all state")
	check(not engine.try_swap(Vector2i(0, 0), Vector2i(2, 0)).accepted, "nonadjacent swaps rejected")
	check(not engine.try_swap(Vector2i(-1, 0), Vector2i(0, 0)).accepted, "out of bounds rejected")
	var pair = engine.hint()
	var result = engine.try_swap(pair[0], pair[1])
	check(result.accepted and engine.moves == old_moves - 1 and result.score_delta > 0, "legal swap spends exactly one move")
	check(not first_step(result, "swap").is_empty() and not first_step(result, "clear").is_empty() and not first_step(result, "fall").is_empty(), "animation snapshots present")
	var snapshot = first_step(result, "swap").board.duplicate(true)
	engine.board[0][0].type = 99
	check(first_step(result, "swap").board == snapshot, "animation snapshots independent of live board")

func _test_special_creation() -> void:
	var engine = clean_fixture()
	var horizontal = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
	paint_run(engine, horizontal)
	var specs = engine.plan_specials(engine.find_runs(), Vector2i(4, 3))
	check(specs.size() == 1 and specs[0].kind == engine.SP_H and specs[0].pos == Vector2i(4, 3), "four horizontal makes row stripe at swapped cell")
	engine._begin_match(true, Vector2i(4, 3))
	check(engine.gem_at(Vector2i(4, 3)).special == engine.SP_H and engine.score == 30, "created special survives and is not scored as cleared")
	check(engine.got_fruit[2] == 3, "created special not counted as collected fruit")
	engine = clean_fixture()
	paint_run(engine, [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5)], 0)
	specs = engine.plan_specials(engine.find_runs(), Vector2i(3, 4))
	check(specs.size() == 1 and specs[0].kind == engine.SP_V, "four vertical makes column stripe")
	engine = clean_fixture()
	paint_run(engine, horizontal + [Vector2i(6, 3)])
	specs = engine.plan_specials(engine.find_runs(), Vector2i(4, 3))
	check(specs.size() == 1 and specs[0].kind == engine.SP_RAIN, "five makes rainbow")
	engine._begin_match(true, Vector2i(4, 3))
	check(engine.gem_at(Vector2i(4, 3)).type == -1 and engine.gem_at(Vector2i(4, 3)).look == 2, "rainbow retains appearance but not match color")
	engine = clean_fixture()
	paint_run(engine, [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(2, 3), Vector2i(4, 3)], 5)
	specs = engine.plan_specials(engine.find_runs(), Vector2i(3, 3))
	check(specs.size() == 1 and specs[0].kind == engine.SP_BOMB, "T or L intersection makes bomb")
	engine = clean_fixture()
	paint_run(engine, horizontal)
	engine.gem_at(Vector2i(4, 3)).ice = true
	engine._begin_match(true, Vector2i(4, 3))
	check(engine.got_ice == 1 and engine.gem_at(Vector2i(4, 3)) != null and engine.gem_at(Vector2i(4, 3)).special == 0, "iced creation target only thaws")
	var created = []
	for step in engine._steps:
		if step.kind == "clear":
			created = step.created
	check(created.size() == 1 and created[0].pos != Vector2i(4, 3), "special retargets to non-iced matched tile")

func _test_special_combos() -> void:
	var pairs = [[1, 1, 8], [2, 2, 16], [1, 2, 15], [1, 3, 24], [2, 3, 24], [3, 3, 25], [4, 4, 64]]
	for fixture in pairs:
		var engine = clean_fixture()
		var a = Vector2i(3, 3)
		var b = Vector2i(4, 3)
		engine.gem_at(a).special = fixture[0]
		engine.gem_at(b).special = fixture[1]
		var result = engine.try_swap(a, b)
		var clear = first_step(result, "clear")
		check(result.accepted and clear.cells.size() == fixture[2], "pair footprint %d+%d" % [fixture[0], fixture[1]])
		check(clear.activations.is_empty(), "pair does not double-fire constituent specials")
	var engine = clean_fixture()
	engine.gem_at(Vector2i(3, 3)).special = 4
	engine.gem_at(Vector2i(3, 3)).type = -1
	var color = engine.gem_at(Vector2i(4, 3)).type
	var expected = 1
	for row in engine.board:
		for gem in row:
			if gem.type == color:
				expected += 1
	var result = engine.try_swap(Vector2i(3, 3), Vector2i(4, 3))
	check(first_step(result, "clear").cells.size() == expected, "rainbow normal clears selected color")
	for kind in [1, 2, 3]:
		engine = clean_fixture()
		engine.gem_at(Vector2i(3, 3)).special = 4
		engine.gem_at(Vector2i(3, 3)).type = -1
		engine.gem_at(Vector2i(4, 3)).special = kind
		result = engine.try_swap(Vector2i(3, 3), Vector2i(4, 3))
		var clear = first_step(result, "clear")
		check(clear.effect == "rainspec" and clear.activations.size() == 8, "rainbow copies and activates up to eight specials %d" % kind)
	engine = clean_fixture()
	engine.gem_at(Vector2i(0, 3)).special = 1
	engine.gem_at(Vector2i(4, 3)).special = 2
	engine._finish_clear([Vector2i(0, 3)])
	var clear = first_step({"steps": engine._steps}, "clear")
	check(clear.cells.size() == 15 and clear.activations.size() == 2, "special chain expands row into column once")

func _test_ice_crates_boosters() -> void:
	var engine = clean_fixture()
	var line = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	paint_run(engine, line, 2)
	engine.gem_at(line[1]).ice = true
	var ice_id = engine.gem_at(line[1]).id
	engine._begin_match(false)
	check(engine.got_ice == 1 and engine.got_fruit[2] == 2 and engine.gem_at(line[1]).id == ice_id, "normal match cracks ice and preserves fruit")
	engine = clean_fixture()
	paint_run(engine, line, 2)
	for pos in line:
		engine.gem_at(pos).ice = true
	engine._begin_match(false)
	check(engine.got_ice == 3 and engine.got_fruit[2] == 3, "all-iced line cracks then clears on next beat")
	engine = clean_fixture()
	engine.gem_at(Vector2i(0, 3)).special = 1
	engine.gem_at(Vector2i(4, 3)).ice = true
	engine._finish_clear([Vector2i(0, 3)])
	check(engine.got_ice == 1 and engine.gem_at(Vector2i(4, 3)) == null, "special clears ice and underlying tile together")
	engine = clean_fixture()
	var crate = engine.gem_at(Vector2i(3, 4))
	crate.crate = true
	crate.type = -2
	check(not engine.try_swap(Vector2i(3, 4), Vector2i(4, 4)).accepted, "crate cannot swap")
	paint_run(engine, line, 2)
	engine._begin_match(false)
	check(engine.got_crate == 1 and engine.gem_at(Vector2i(3, 4)) == null, "adjacent normal clear breaks crate")
	engine = clean_fixture()
	var above_id = engine.board[1][0].id
	var below_id = engine.board[6][0].id
	var low_id = engine.board[6][1].id
	engine.board[5][0].crate = true
	engine.board[5][0].type = -2
	var crate_id = engine.board[5][0].id
	engine.board[2][0] = null
	engine.board[4][1].crate = true
	engine.board[4][1].type = -2
	engine.board[7][1] = null
	engine.apply_gravity()
	check(engine.board[5][0].id == crate_id and engine.board[2][0].id == above_id and engine.board[6][0].id == below_id and engine.board[7][1].id == low_id, "crate splits fixed gravity segments")
	engine = clean_fixture()
	var target = Vector2i(3, 3)
	engine.gem_at(target).ice = true
	engine.gem_at(target).special = 3
	engine.gem_at(Vector2i(3, 4)).crate = true
	engine.gem_at(Vector2i(3, 4)).type = -2
	var old_moves = engine.moves
	var result = engine.use_hammer(target)
	check(result.accepted and engine.hammers == 1 and engine.moves == old_moves and engine.got_ice == 1, "hammer spends no move and clears ice")
	check(first_step(result, "clear").cells.size() == 1 and engine.got_crate == 0, "hammer suppresses special and adjacent-crate splash")
	check(engine.use_plus() and engine.moves == old_moves + 5 and not engine.use_plus(), "+5 is free and usable once")
	engine.phase = "resolving"
	check(not engine.use_plus() and not engine.use_hammer(target).accepted, "boosters blocked while busy")
	engine = EngineScript.new()
	engine.initialize(4, 1)
	engine.got_crate = 2
	old_moves = engine.moves
	engine.shuffle()
	check(count_flag(engine, "crate") == 4 and engine.got_crate == 2 and engine.moves == old_moves, "shuffle restores only remaining crates")
	engine.initialize(1, 1)
	engine.got_ice = 2
	engine.shuffle()
	check(count_flag(engine, "ice") == 2 and engine.got_ice == 2, "shuffle restores only remaining ice")

func _test_stars_and_end() -> void:
	check(EngineScript.stars_for(8, 18) == 3 and EngineScript.stars_for(7, 18) == 2, "40 percent star threshold")
	check(EngineScript.stars_for(3, 18) == 2 and EngineScript.stars_for(2, 18) == 1 and EngineScript.stars_for(0, 18) == 1, "15 percent and zero move star thresholds")
	var engine = EngineScript.new()
	engine.initialize(0, 1)
	engine.got_fruit[1] = 12
	engine.moves = 0
	engine.finish_turn()
	check(engine.phase == "win" and engine.stars == 1, "win takes priority on last move")
	check(not engine.try_swap(Vector2i(0, 0), Vector2i(1, 0)).accepted, "finished board rejects swap")
	engine.initialize(0, 1)
	engine.moves = 0
	engine.finish_turn()
	check(engine.phase == "lose", "unmet goal at zero moves loses")
	engine.initialize(2, 1)
	engine.got_fruit[1] = 8
	engine.finish_turn()
	check(engine.phase == "idle", "mixed goals require both colors")

func _test_seeded_games() -> void:
	for level in 8:
		for seed_value in range(1, 6):
			var engine = EngineScript.new()
			engine.initialize(level, seed_value)
			var turns = 0
			while engine.phase == "idle" and turns < 40:
				var pair = engine.hint()
				check(pair.size() == 2, "seeded game never stalls %d/%d" % [level, seed_value])
				if pair.size() != 2:
					break
				var before = engine.moves
				var result = engine.try_swap(pair[0], pair[1])
				check(result.accepted and engine.moves == before - 1, "seeded game legal turn")
				check(engine.find_runs().is_empty() and types(engine).length() == 64, "seeded game stable filled board")
				turns += 1
			check(engine.phase in ["win", "lose"] and turns <= int(engine.level_data.moves), "seeded game terminates %d/%d" % [level, seed_value])
			var expected = JS_TERMINALS[level * 5 + seed_value - 1]
			check(engine.score == expected[0] and engine.moves == expected[1] and engine.phase == expected[2], "exact JS terminal score/moves/phase %d/%d" % [level, seed_value])
			check(types(engine) == expected[3], "exact JS terminal board %d/%d" % [level, seed_value])
			check(engine.got_fruit == expected[4] and engine.got_ice == expected[5] and engine.got_crate == expected[6], "exact JS terminal goals %d/%d" % [level, seed_value])
			games += 1

func _test_rule_edges() -> void:
	var engine = clean_fixture()
	var line = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
	paint_run(engine, line)
	engine._begin_match(false)
	var clear = first_step({"steps": engine._steps}, "clear")
	check(clear.created.is_empty() and clear.cells.size() == 4 and engine.score == 40, "cascade four clears normally without creating a special")
	engine = clean_fixture()
	paint_run(engine, line)
	engine.gem_at(Vector2i(4, 3)).special = engine.SP_V
	engine._begin_match(true, Vector2i(4, 3))
	clear = first_step({"steps": engine._steps}, "clear")
	check(clear.cells.size() == 10 and clear.activations.size() == 1 and engine.gem_at(Vector2i(4, 3)).special == engine.SP_H, "old special fires even at preserved new-special location")
	# Stripe footprints follow each piece's post-swap position and axis.
	for fixture in [[1, 16], [2, 8]]:
		engine = clean_fixture()
		engine.gem_at(Vector2i(3, 3)).special = fixture[0]
		engine.gem_at(Vector2i(3, 4)).special = fixture[0]
		var result = engine.try_swap(Vector2i(3, 3), Vector2i(3, 4))
		check(first_step(result, "clear").cells.size() == fixture[1], "vertical swap stripe axes %d" % fixture[0])
	engine = clean_fixture()
	engine.gem_at(Vector2i(0, 0)).special = engine.SP_BOMB
	check(engine.area_keys(engine.gem_at(Vector2i(0, 0)), Vector2i(0, 0)).size() == 4, "corner bomb clipped to board")
	engine.gem_at(Vector2i(1, 0)).special = engine.SP_BOMB
	var result = engine.try_swap(Vector2i(0, 0), Vector2i(1, 0))
	check(first_step(result, "clear").cells.size() == 12, "corner bomb pair clips 5x5 to primary position")
	# Rainbows that retain a color use their own color for a special pair.
	engine = clean_fixture()
	engine.gem_at(Vector2i(3, 3)).special = engine.SP_RAIN
	engine.gem_at(Vector2i(3, 3)).type = 2
	engine.gem_at(Vector2i(4, 3)).special = engine.SP_H
	result = engine.try_swap(Vector2i(3, 3), Vector2i(4, 3))
	clear = first_step(result, "clear")
	var swap_board = first_step(result, "swap").board
	var copied_color_correct = true
	for activation in clear.activations:
		copied_color_correct = copied_color_correct and swap_board[activation.pos.y][activation.pos.x].type == 2
	check(clear.activations.size() == 8 and copied_color_correct, "colored rainbow special pair uses rainbow color")
	engine = clean_fixture()
	engine.gem_at(Vector2i(0, 3)).special = engine.SP_H
	engine.gem_at(Vector2i(4, 3)).special = engine.SP_RAIN
	engine.gem_at(Vector2i(4, 3)).type = -1
	engine._finish_clear([Vector2i(0, 3)])
	clear = first_step({"steps": engine._steps}, "clear")
	check(clear.activations.size() == 2 and clear.cells.size() > 8, "collateral rainbow activates random board color")
	engine = EngineScript.new()
	engine.initialize(0, 1)
	for r in 8:
		for c in 8:
			engine.board[r][c] = engine.make_gem(Vector2i(c, r), (c + 2 * r) % 6)
	check(engine.hint().is_empty() and engine.find_runs().is_empty(), "dead-board fixture has no moves or matches")
	var old_moves = engine.moves
	engine.finish_turn()
	check(engine.moves == old_moves and engine.score == 0 and not engine.hint().is_empty() and not first_step({"steps": engine._steps}, "shuffle").is_empty(), "dead board automatically reshuffles without move or score cost")
	for level in [1, 3, 7]:
		engine.initialize(level, 1)
		var ice_positions: Array = []
		for r in 8:
			for c in 8:
				if engine.board[r][c].ice:
					ice_positions.append(r * 8 + c)
		check(ice_positions == ([18, 21, 26, 27, 62] if level == 3 else [18, 21, 26, 62]), "exact JS seeded ice placement level %d" % level)

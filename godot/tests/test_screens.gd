extends SceneTree
## Native title/result regression coverage. No artwork or saved state is needed.
## Run with fresh /tmp/lumi-ui-* XDG storage and LUMI_UI_TEST=1:
## godot --headless --path godot --script res://tests/test_screens.gd
## tools/run_checks.sh runs this alongside the model and application tests.
const TITLE = preload("res://scenes/title_screen.tscn")
const COMPLETION = preload("res://scenes/completion_screen.tscn")
var failures := 0
var checks := 0
func _initialize() -> void:
	ProjectSettings.set_setting("lumi/review_mode",false)
	call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
func settle() -> void:
	for i in 4: await process_frame
func scan(node: Node, bounds: Rect2) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		check(rect.position.x >= bounds.position.x - 1 and rect.end.x <= bounds.end.x + 1, "%s horizontal overflow: %s in %s" % [node.name, rect, bounds])
		check(rect.position.y >= bounds.position.y - 1 and rect.end.y <= bounds.end.y + 1, "%s vertical overflow: %s in %s" % [node.name, rect, bounds])
		if node is Button: check(rect.size.y >= 60.0, "touch height: " + str(rect))
	for child in node.get_children(): scan(child, bounds)
func _run() -> void:
	var isolated := OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/lumi-ui-")
	if OS.get_name() == "Windows":
		isolated = str(ProjectSettings.get_setting("application/config/name", "")).begins_with("Lumi-Isolated-")
	if OS.get_environment("LUMI_UI_TEST") != "1" or not isolated:
		push_error("Set LUMI_UI_TEST=1 and fresh /tmp/lumi-ui-* XDG storage before running native screen tests.")
		quit(2)
		return
	await _layout_matrix()
	print("SCREEN LAYOUT MATRIX: %d assertions, %d failures" % [checks, failures])
	await _data_binding_without_artwork()
	await _signal_contracts()
	print("NATIVE SCREEN TESTS: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _layout_matrix() -> void:
	for dimensions in [Vector2(320,580),Vector2(360,580),Vector2(390,760),Vector2(768,940),Vector2(768,390),Vector2(320,320)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = Vector2i(dimensions)
		for kind in ["title", "win", "first_loss", "loss"]:
			var scene: Control = TITLE.instantiate() if kind == "title" else COMPLETION.instantiate()
			if kind != "title":
				scene.won = kind == "win"
				scene.first_run = kind == "first_loss"
				scene.stars = 2
				scene.reward = 100
				scene.level_number = 1
				scene.reduce_motion = true
			root.add_child(scene)
			await settle()
			scan(scene, Rect2(Vector2.ZERO, dimensions))
			if kind == "title":
				var title: Control = scene.get_node("Title")
				var subtitle: Control = scene.get_node("Subtitle")
				check(not title.get_rect().intersects(subtitle.get_rect()), "title/subtitle overlap %s: %s / %s" % [dimensions,title.get_rect(),subtitle.get_rect()])
				scene.get_node("StartButton").pressed.emit()
				scene.get_node("StartButton").pressed.emit()
				check(scene.transition_started and scene.get_node("StartButton").disabled, "start lock")
			else:
				var visible := []
				for child in scene.get_children():
					if child is Control and child.visible: visible.append(child)
				for a in visible:
					for b in visible:
						if a == b: continue
						check(not a.get_rect().intersects(b.get_rect()), "%s %s %s overlap at %s: %s / %s" % [kind,a.name,b.name,dimensions,a.get_rect(),b.get_rect()])
				if kind == "win":
					check(scene.get_node("Stars").filled == 2, "actual stars")
					check(scene.get_node("RewardBadge").get_child(0).get_node("RewardValue").text == "커피 방울 +100", "actual reward")
				var button: Button = scene.get_node("ContinueButton") if kind == "win" else scene.get_node("RetryButton")
				button.pressed.emit()
				button.pressed.emit()
				check(scene.committed and button.disabled, "result lock")
			print("SCREEN ",kind," ",dimensions)
			scene.queue_free()
			await settle()

func _data_binding_without_artwork() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(390, 760)
	# Render real controls by themselves: no background, character, mockup, or atlas.
	# Every star count is crossed with zero, small values, and both real reward sizes.
	for star_count in [0, 1, 2, 3]:
		for reward_amount in [0, 1, 2, 3, 35, 100]:
			var scene: Control = COMPLETION.instantiate()
			scene.won = true
			scene.first_run = true
			scene.stars = star_count
			scene.reward = reward_amount
			scene.score = reward_amount * 10
			scene.reduce_motion = true
			root.add_child(scene)
			await settle()
			var tag := "stars=%d reward=%d without artwork" % [star_count, reward_amount]
			check(scene.get_class() == "Control", tag + " transparent root")
			check(scene.find_children("*", "TextureRect", true, false).is_empty(), tag + " no image-backed UI")
			check(scene.find_children("*", "Sprite2D", true, false).is_empty(), tag + " no baked star/reward art")
			check(scene.get_node("Stars").visible, tag + " star indicator visible")
			check(scene.get_node("Stars").filled == star_count, tag + " exact native star fill")
			check(scene.get_node("RewardBadge").visible, tag + " live reward badge visible")
			check(scene.find_child("RewardValue", true, false).text == "커피 방울 +%d" % reward_amount, tag + " exact native reward text")
			check(scene.get_node("Score").text == "%d점" % (reward_amount * 10), tag + " exact score field")
			check(scene.get_node("ResultSubtitle").text == "퍼즐 완료", tag + " unknown level stays generic")
			check(scene.get_node("ContinueButton").text == "카페로 가기", tag + " approved live continue action")
			check(not scene.has_node("RetryButton"), tag + " winning screen has one action")
			check(scene.get_node("Stars").modulate.a == 1.0, tag + " reduced motion immediately readable")
			scene.queue_free()
			await settle()
	for number in [0, 1, 3]:
		var scene: Control = COMPLETION.instantiate()
		scene.won = true
		scene.level_number = number
		scene.reduce_motion = true
		root.add_child(scene)
		await settle()
		var expected := "퍼즐 완료" if number == 0 else ("첫 번째 퍼즐 완료" if number == 1 else "3번째 퍼즐 완료")
		check(scene.get_node("ResultSubtitle").text == expected, "real puzzle number %d" % number)
		scene.queue_free()
		await settle()
	# Even inconsistent supplied values cannot paint a positive result on a loss.
	for initial in [true, false]:
		var scene: Control = COMPLETION.instantiate()
		scene.won = false
		scene.first_run = initial
		scene.stars = 3
		scene.reward = 100
		scene.reduce_motion = true
		root.add_child(scene)
		await settle()
		check(not scene.get_node("Stars").visible, "loss does not invent earned stars")
		check(scene.get_node("Stars").filled == 0, "loss cannot fill supplied winning stars")
		check(not scene.get_node("RewardBadge").visible, "loss does not invent reward from supplied data/art")
		check(scene.get_node("RetryButton").visible, "loss always offers retry")
		check(scene.has_node("ContinueButton") == not initial, "first-loss cafe gate preserved")
		scene.queue_free()
		await settle()
	print("SCREEN VALUE BINDING: checked 24 star/reward combinations and level/loss cases")

func _signal_contracts() -> void:
	for resume in [false, true]:
		var scene: Control = TITLE.instantiate()
		scene.resume_available = resume
		var calls := {"start": 0, "settings": 0}
		scene.start_requested.connect(func(): calls.start += 1)
		scene.settings_requested.connect(func(): calls.settings += 1)
		root.add_child(scene)
		await settle()
		check(scene.get_node("StartButton").text == ("이어하기" if resume else "시작하기"), "resume label %s" % resume)
		scene.get_node("SettingsButton").pressed.emit()
		check(calls.settings == 1, "title settings signal")
		scene.get_node("StartButton").pressed.emit()
		scene.get_node("StartButton").pressed.emit()
		scene.get_node("SettingsButton").pressed.emit()
		check(calls.start == 1, "double start emits once")
		check(calls.settings == 1, "settings blocked after start commit")
		check(scene.get_node("SettingsButton").disabled, "settings disabled during transition")
		scene.queue_free()
		await settle()
	for kind in ["win", "first_loss", "retry_loss", "continue_loss"]:
		var scene: Control = COMPLETION.instantiate()
		scene.won = kind == "win"
		scene.first_run = kind == "first_loss"
		scene.reduce_motion = true
		var calls := {"continue": 0, "retry": 0}
		scene.continue_requested.connect(func(): calls["continue"] += 1)
		scene.retry_requested.connect(func(): calls.retry += 1)
		root.add_child(scene)
		await settle()
		var use_continue: bool = kind == "win" or kind == "continue_loss"
		var button: Button = scene.get_node("ContinueButton" if use_continue else "RetryButton")
		button.pressed.emit()
		button.pressed.emit()
		if scene.has_node("ContinueButton"): scene.get_node("ContinueButton").pressed.emit()
		if scene.has_node("RetryButton"): scene.get_node("RetryButton").pressed.emit()
		check(calls["continue"] == (1 if use_continue else 0), kind + " single continue signal")
		check(calls.retry == (0 if use_continue else 1), kind + " single retry signal")
		check(scene.committed, kind + " transition commit")
		if scene.has_node("ContinueButton"): check(scene.get_node("ContinueButton").disabled, kind + " continue disabled")
		if scene.has_node("RetryButton"): check(scene.get_node("RetryButton").disabled, kind + " retry disabled")
		scene.queue_free()
		await settle()
	print("SCREEN SIGNAL CONTRACTS: checked resume/settings/duplicate and cross-action locks")

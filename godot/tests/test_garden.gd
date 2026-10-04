extends SceneTree
## Native Garden state/art/input contract. No production save reads or writes.
## Run through tools/run_checks.sh or tools/run_checks.ps1 for isolated runtime storage.
## This verifies native nodes and input geometry, not rendered pixels or device graphics.
const Garden = preload("res://scripts/garden_view.gd")
const Model = preload("res://scripts/cafe_model.gd")
var failed := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func _initialize() -> void:
	ProjectSettings.set_setting("lumi/review_mode",false)
	call_deferred("run")
func run() -> void:
	var isolated := OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/lumi-ui-")
	if OS.get_name() == "Windows":
		isolated = str(ProjectSettings.get_setting("application/config/name", "")).begins_with("Lumi-Isolated-")
	if OS.get_environment("LUMI_UI_TEST") != "1" or not isolated:
		push_error("Use run_checks or LUMI_UI_TEST=1 with fresh /tmp/lumi-ui-* XDG storage; Windows requires a Lumi-Isolated-* project copy.")
		quit(2)
		return
	print("Isolated Garden runtime: " + OS.get_user_data_dir())
	var model := Model.new({})
	var catalog: Dictionary = model.catalog
	var original_catalog := JSON.stringify(catalog)
	var state: Dictionary = model.fresh()
	var null_atlases := true
	for facility in catalog.facilities:
		null_atlases = null_atlases and facility.get("atlas", "missing") == null
	check(null_atlases, "all facility animation atlases remain null")
	var garden := Garden.new()
	garden.size = Vector2(390, 700)
	garden.presentation_mode = true
	garden.set_state(state, catalog)
	root.add_child(garden)
	await process_frame
	check(garden.custom_minimum_size == Vector2(120, 120), "home permits short landscape allocation")
	check(garden._visuals.size() == 1, "initial exact one owned facility")
	check(not garden._visuals.has("facility:f05"), "unowned cafe omitted")
	check(garden.needs_art == ["f19", "cat19"], "initial missing art diagnostics")
	var art := load("res://assets/art/f19-bell-entrance-jongjong.png") as Texture2D
	check(art != null, "real static entrance art loads")
	garden.set_art(art, null, true)
	await process_frame
	var visual: Control = garden._visuals["facility:f19"]
	check(visual.cat_id == "cat19", "initial owned visual identifies exactly cat19")
	check(visual.get_meta("static_art_only", false), "static entrance does not claim final animation")
	check(visual.embedded_cat, "embedded cat acknowledged")
	check(visual.get_node("FacilityArt").visible, "owned native TextureRect visible")
	check(not visual.get_node("CatArt").visible, "duplicate cat suppressed")
	check(not visual.get_node("PlaceholderLabel").visible, "no placeholder label over supplied art")
	check(garden.needs_art.is_empty(), "no missing display art for supplied static pair")
	check(state.owned.f19.position == {"x":48,"y":19}, "source initial position untouched")
	for dimensions in [Vector2(320, 540), Vector2(390, 700), Vector2(844, 540), Vector2(320, 160), Vector2(390, 260), Vector2(844, 160)]:
		garden.size = dimensions
		for x in [8, 48, 92]:
			for y in [12, 19, 87]:
				state.owned.f19.position = {"x":x,"y":y}
				garden.set_state(state, catalog)
				visual = garden._visuals["facility:f19"]
				var bounds: Rect2 = visual.visual_bounds()
				bounds.position += visual.position
				check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1 and bounds.end.x <= dimensions.x+0.1 and bounds.end.y <= dimensions.y+0.1, "all valid edge art visible")
				garden._hit(visual.position)
				check(garden.drag_id == "f19", "mapped center hits owned facility")
				var normalized: Dictionary = garden.local_to_normalized(visual.position)
				check(absf(float(normalized.x)-x)<0.01 and absf(float(normalized.y)-y)<0.01, "inverse placement round trip")
	state.decorOwned = {"d-wood-floor":{"position":{"x":20,"y":50}}, "d-brick-path":{"position":{"x":60,"y":50}}}
	garden.set_state(state, catalog)
	check(garden._visuals.size() == 1, "floor and path have no plant node")
	state.owned.f19.position = null
	garden.set_state(state, catalog)
	check(garden._visuals.is_empty(), "stored entrance and embedded cat removed")
	state.owned.f19.position = {"x":48,"y":19}
	garden.editing = true
	garden.facility_layout = {"f19":{"x":48,"y":19}, "f05":{"x":65,"y":60}}
	garden.decor_layout = {}
	garden.set_state(state, catalog)
	check(garden._visuals.size()==1, "draft cannot grant facility ownership")
	var old_position: Dictionary = state.owned.f19.position.duplicate()
	garden._hit(garden.normalized_to_local(garden.facility_layout.f19))
	garden._drag(Vector2(10000, -100))
	check(garden.facility_layout.f19 == {"x":92.0,"y":12.0}, "editor exact normalized clamp")
	check(state.owned.f19.position == old_position, "editor does not mutate saved state")
	check(JSON.stringify(catalog) == original_catalog, "rendering and editing do not change catalog or atlas contracts")
	var editor := Garden.new()
	editor.editing = true
	root.add_child(editor)
	await process_frame
	check(editor.custom_minimum_size == Vector2(260, 300), "editor keeps original minimum bounds")
	editor.queue_free()
	print("GARDEN LAYER: %d checks, %d failures" % [checks, failed])
	garden.queue_free()
	quit(1 if failed else 0)

extends Control
signal play_requested
signal project_requested
signal settings_requested
signal facility_selected(id: String)
signal decoration_selected(id: String)
const Garden=preload("res://scripts/garden_view.gd")
const Icon=preload("res://scripts/ui_icon.gd")
const Bold=preload("res://assets/fonts/NotoSansKR-Game-Bold.otf")
var state: Dictionary={}
var catalog: Dictionary={}
var first_arrival:=false
var transition_started:=false
var garden: Control
var balance_label: Label
var project_button: Button
var play_button: Button
var settings_button: Button
var project_title: Label
var project_cost: Label
var welcome: Label
var logo: PanelContainer
var wallet: PanelContainer
func _ready() -> void:
	name="HomeScreen"
	size_flags_vertical=SIZE_EXPAND_FILL
	size_flags_horizontal=SIZE_EXPAND_FILL
	custom_minimum_size=Vector2(240,280)
	_build()
	resized.connect(_layout)
	_layout()

func _label(value: String,font_size: int) -> Label:
	var l=Label.new()
	l.text=value
	l.add_theme_font_override("font",Bold)
	l.add_theme_font_size_override("font_size",font_size)
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter=MOUSE_FILTER_IGNORE
	return l

func _style(color: Color, radius: int=24) -> StyleBoxFlat:
	var st=StyleBoxFlat.new()
	st.bg_color=color
	st.border_color=Color("fffbed")
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.shadow_color=Color(0.22,0.31,0.16,0.13)
	st.shadow_size=4
	st.shadow_offset=Vector2(0,3)
	return st

func _build() -> void:
	garden=Garden.new()
	garden.presentation_mode=true
	garden.custom_minimum_size=Vector2.ZERO
	garden.set_state(state,catalog)
	garden.set_art(load("res://assets/art/f19-bell-entrance-jongjong.png"),null,true)
	garden.item_selected.connect(func(id,deco):
		if deco: decoration_selected.emit(id)
		else: facility_selected.emit(id))
	add_child(garden)
	logo=PanelContainer.new()
	logo.add_theme_stylebox_override("panel",_style(Color("fff8e9"),28))
	logo.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(logo)
	var cat=Icon.new()
	cat.kind="cat"
	cat.custom_minimum_size=Vector2(34,34)
	var logomargin=MarginContainer.new()
	for side in ["left","top","right","bottom"]: logomargin.add_theme_constant_override("margin_"+side,12)
	logo.add_child(logomargin)
	logomargin.add_child(cat)
	wallet=PanelContainer.new()
	wallet.add_theme_stylebox_override("panel",_style(Color("fff8e9"),26))
	wallet.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(wallet)
	var row=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	wallet.add_child(row)
	var drop=Icon.new()
	drop.kind="drop"
	drop.custom_minimum_size=Vector2(24,32)
	row.add_child(drop)
	balance_label=_label(str(int(state.balance)),23)
	row.add_child(balance_label)
	settings_button=Button.new()
	settings_button.name="HomeSettingsButton"
	settings_button.custom_minimum_size=Vector2(60,60)
	settings_button.tooltip_text="카페 메뉴와 설정"
	settings_button.accessibility_name="카페 메뉴와 설정"
	var gear=Icon.new()
	gear.kind="gear"
	gear.position=Vector2(14,14)
	gear.size=Vector2(32,32)
	settings_button.add_child(gear)
	settings_button.pressed.connect(func(): settings_requested.emit())
	add_child(settings_button)
	welcome=_label("우리의 첫 카페" if first_arrival else "우리 고양이 커피숍",16)
	welcome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(welcome)
	project_button=Button.new()
	project_button.name="ProjectButton"
	project_button.custom_minimum_size.y=66
	project_button.pressed.connect(func(): project_requested.emit())
	add_child(project_button)
	var cup=Icon.new()
	cup.kind="cup"
	cup.position=Vector2(12,11)
	cup.size=Vector2(42,42)
	project_button.add_child(cup)
	var f: Dictionary={}
	for item in catalog.facilities:
		if item.id==state.project: f=item
	var project_text="카페 꾸미기"
	var price_text="작업대에서 다음 목표를 골라요"
	if not f.is_empty():
		if not state.owned.has(f.id):
			project_text="다음: "+str(f.name)
			price_text="커피 방울 %d"%int(f.price)
		else:
			var level=int(state.owned[f.id].level)
			project_text=str(f.name)+" · 성장 %d"%level
			price_text="다음 성장 %d 방울"%int(f.upgrades[level-1]) if level<3 else "고양이와 함께하는 작은 쉼"
	project_title=_label(project_text,18)
	project_title.position=Vector2(64,7)
	project_button.add_child(project_title)
	project_cost=_label(price_text,14)
	project_cost.position=Vector2(64,34)
	project_cost.modulate=Color("96745d")
	project_button.add_child(project_cost)
	var chevron=_label("›",30)
	chevron.name="Chevron"
	project_button.add_child(chevron)
	play_button=Button.new()
	play_button.name="PlayButton"
	play_button.text="퍼즐 하기"
	play_button.custom_minimum_size.y=60
	play_button.add_theme_font_override("font",Bold)
	play_button.add_theme_font_size_override("font_size",22)
	for variant in ["normal","hover","pressed","disabled"]:
		play_button.add_theme_stylebox_override(variant,_style(Color("3a614b") if variant=="pressed" else Color("446f56"),24))
	for color_key in ["font_color","font_hover_color","font_pressed_color"]: play_button.add_theme_color_override(color_key,Color.WHITE)
	play_button.pressed.connect(func():
		if transition_started: return
		transition_started=true
		play_button.disabled=true
		play_requested.emit())
	add_child(play_button)

func _layout() -> void:
	if size.x<200 or size.y<240: return
	if not is_instance_valid(garden): return
	var w=size.x
	var h=size.y
	logo.position=Vector2(0,0)
	logo.size=Vector2(60,60)
	settings_button.position=Vector2(w-60,0)
	settings_button.size=Vector2(60,60)
	wallet.position=Vector2(maxf(70,w-196),4)
	wallet.size=Vector2(126,52)
	welcome.position=Vector2(0,68)
	welcome.size=Vector2(w,28)
	garden.position=Vector2(0,75)
	garden.size=Vector2(w,maxf(140,h-215))
	project_button.position=Vector2(0,h-138)
	project_button.size=Vector2(w,66)
	project_title.size=Vector2(maxf(50,w-91),27)
	project_title.add_theme_font_size_override("font_size",16 if w<340 else 18)
	project_cost.size=Vector2(maxf(50,w-91),24)
	project_button.get_node("Chevron").position=Vector2(w-27,12)
	project_button.get_node("Chevron").size=Vector2(20,40)
	play_button.position=Vector2(0,h-60)
	play_button.size=Vector2(w,60)

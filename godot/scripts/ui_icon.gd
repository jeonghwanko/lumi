extends Control
## Small vector UI icons remain sharp at any device scale.
var kind: String="cup"
var ink: Color=Color("52392e")
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var unit=minf(size.x,size.y)/64.0
	var origin=(size-Vector2.ONE*unit*64)/2
	draw_set_transform(origin,0,Vector2.ONE*unit)
	match kind:
		"back":
			draw_polyline(PackedVector2Array([Vector2(39,16),Vector2(23,32),Vector2(39,48)]),ink,7,true)
		"gear":
			for i in 8:
				var angle=float(i)/8*TAU
				draw_line(Vector2(32,32)+Vector2.from_angle(angle)*16,Vector2(32,32)+Vector2.from_angle(angle)*24,ink,9,true)
			draw_circle(Vector2(32,32),21,ink,true,-1,true)
			draw_circle(Vector2(32,32),8,Color("fff8e9"),true,-1,true)
		"drop":
			var points=PackedVector2Array([Vector2(32,5),Vector2(14,32),Vector2(12,43),Vector2(17,53),Vector2(26,58),Vector2(38,58),Vector2(48,51),Vector2(52,40),Vector2(46,26)])
			draw_colored_polygon(points,ink)
			draw_line(Vector2(22,37),Vector2(20,43),Color("c79162"),4,true)
		"hammer":
			draw_line(Vector2(18,52),Vector2(39,24),Color("8d5738"),10,true)
			draw_line(Vector2(17,50),Vector2(36,25),Color("c99265"),4,true)
			var head=PackedVector2Array([Vector2(22,12),Vector2(30,6),Vector2(52,23),Vector2(51,34),Vector2(43,37),Vector2(22,22)])
			draw_colored_polygon(head,Color("86ad92"))
			draw_polyline(head,ink,2,true)
		"cup":
			draw_arc(Vector2(48,29),13,-PI/2,PI/2,20,ink,4,true)
			draw_polyline(PackedVector2Array([Vector2(12,17),Vector2(45,17),Vector2(44,35),Vector2(38,45),Vector2(29,48),Vector2(20,44),Vector2(14,34),Vector2(12,17)]),ink,4,true)
			draw_line(Vector2(9,54),Vector2(51,54),ink,4,true)
		"cat":
			var face=PackedVector2Array([Vector2(10,49),Vector2(9,30),Vector2(14,10),Vector2(25,20),Vector2(39,20),Vector2(50,10),Vector2(55,32),Vector2(52,49),Vector2(44,55),Vector2(21,55)])
			draw_colored_polygon(face,ink)
			draw_circle(Vector2(24,36),2.6,Color("fff8e9"),true,-1,true)
			draw_circle(Vector2(41,36),2.6,Color("fff8e9"),true,-1,true)
			draw_circle(Vector2(32.5,43),2,Color("fff8e9"),true,-1,true)
			draw_line(Vector2(33,44),Vector2(28,48),Color("fff8e9"),2,true)
			draw_line(Vector2(33,44),Vector2(37,48),Color("fff8e9"),2,true)
	draw_set_transform(Vector2.ZERO)

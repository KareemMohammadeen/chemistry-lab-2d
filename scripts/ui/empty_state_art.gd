class_name EmptyStateArt
extends Control
## A small line illustration for the Inspector's empty state: a dashed frame holding a flask
## and a pointer. Purely decorative; it is drawn from code so it follows the colour tokens.

const DASH_PX := 8.0
const GAP_PX := 6.0
const LINE_WIDTH := 2.0


func _ready() -> void:
	custom_minimum_size = Vector2(120.0, 104.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	_dashed_rect(box, LabColors.PANEL_BORDER_STRONG)
	var center := box.get_center()
	# Flask outline.
	var flask := PackedVector2Array([
		center + Vector2(-8.0, -26.0), center + Vector2(8.0, -26.0), center + Vector2(8.0, -8.0),
		center + Vector2(24.0, 22.0), center + Vector2(-24.0, 22.0), center + Vector2(-8.0, -8.0), center + Vector2(-8.0, -26.0)])
	draw_polyline(flask, LabColors.TEXT_MUTED, LINE_WIDTH, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-16.0, 8.0), center + Vector2(16.0, 8.0),
		center + Vector2(23.0, 21.0), center + Vector2(-23.0, 21.0)]), Color(LabColors.ACCENT, 0.5))
	# Pointer arrow.
	var tip := center + Vector2(14.0, 6.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(0.0, 20.0), tip + Vector2(5.5, 15.0),
		tip + Vector2(10.0, 24.0), tip + Vector2(13.0, 22.5), tip + Vector2(8.5, 14.0), tip + Vector2(15.0, 14.0)]), LabColors.TEXT_PRIMARY)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	var corners: Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in range(4):
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % 4]
		var length := from.distance_to(to)
		var direction := (to - from) / maxf(length, 0.001)
		var travelled := 0.0
		while travelled < length:
			var stop := minf(travelled + DASH_PX, length)
			draw_line(from + direction * travelled, from + direction * stop, color, LINE_WIDTH)
			travelled += DASH_PX + GAP_PX

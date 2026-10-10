class_name RaceRoad
extends Node2D
## Scene-authored strips make the scrolling track inspectable without a shader.

enum Section { NORMAL, CURVES, NARROW, ICE, NIGHT }

const SECTION_NAMES: Array[String] = ["OPEN ROAD", "CURVES", "MOTORWAY", "ICE ROAD", "NIGHT RUN"]
const GRASS: Color = Color("55a049")
const ASPHALT: Color = Color("6c6c6c")

var section: int = Section.NORMAL
var scroll: float = 0.0
var width: float = 224.0
var curve_strength: float = 0.0
var headlight_x: float = 168.0
var rows: Array[RoadStrip] = []


func _ready() -> void:
	for child in $Rows.get_children():
		rows.append(child as RoadStrip)
	refresh()


func reset_road() -> void:
	section = Section.NORMAL
	scroll = 0.0
	width = 224.0
	curve_strength = 0.0
	refresh()


func advance(delta: float, speed: float) -> void:
	scroll += speed * delta
	width = move_toward(width, 112.0 if section == Section.NARROW else 224.0, delta * 112.0)
	curve_strength = move_toward(curve_strength, 1.0 if section == Section.CURVES else 0.0, delta)
	refresh()


func lane_x(coordinate: float, screen_y: float) -> float:
	return 56.0 + coordinate * 56.0 + curve_offset(screen_y)


func curve_offset(screen_y: float) -> float:
	return sin((scroll + 240.0 - screen_y) / 100.0) * 19.0 * curve_strength


func minimum_lane() -> int:
	return 1 if section == Section.NARROW else 0


func maximum_lane() -> int:
	return 2 if section == Section.NARROW else 3


func refresh() -> void:
	for row in rows:
		var screen_y: float = float(row.get_index() * 8)
		var centre_x: float = 140.0 + curve_offset(screen_y)
		var surface: Sprite2D = row.surface
		surface.position.x = centre_x
		surface.scale.x = width
		surface.modulate = Color("b2dce8") if section == Section.ICE else ASPHALT
		var grass: Sprite2D = row.grass
		grass.modulate = Color("d7e7ef") if section == Section.ICE else GRASS
		if section == Section.NIGHT:
			grass.modulate = Color("222034")
			surface.modulate = Color("30303d")
		row.left_edge.position.x = centre_x - width / 2.0
		row.right_edge.position.x = centre_x + width / 2.0
		var white_kerb: bool = int((screen_y + scroll) / 8.0) % 2 == 0
		var kerb_colour: Color = Color("ffffff") if white_kerb else Color("b13e53")
		row.left_edge.modulate = kerb_colour
		row.right_edge.modulate = kerb_colour
		for index in range(3):
			var dash: Sprite2D = row.dashes[index]
			dash.position.x = centre_x - 56.0 + index * 56.0
			dash.visible = int((screen_y + scroll) / 8.0) % 4 < 2 and (width > 200.0 or index == 1)
			dash.modulate = Color("53536a") if section == Section.NIGHT else Color("eeeecc")
		var tree: Sprite2D = row.scenery
		tree.position.x = 8.0 if row.get_index() % 2 == 0 else 272.0
		tree.visible = int((screen_y + scroll) / 8.0) % 8 == 0
		tree.modulate = Color("777799") if section == Section.NIGHT else Color.WHITE

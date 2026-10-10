class_name RaceRoad
extends Node2D
## Scene-authored strips make the scrolling track inspectable without a shader.

enum Section { NORMAL, CURVES, NARROW, ICE, NIGHT }

const SECTION_NAMES: Array[String] = ["OPEN ROAD", "CURVES", "MOTORWAY", "ICE ROAD", "NIGHT RUN"]
const LANE_WIDTH: float = 56.0
const GRASS: Color = Color("55a049")
const ASPHALT: Color = Color("6c6c6c")

var section: int = Section.NORMAL
var scroll: float = 0.0
var width: float = 224.0
var curve_strength: float = 0.0
var headlight_x: float = 168.0
var playfield_top: float = 64.0
var playfield_bottom: float = 480.0
var player_y: float = 400.0
var rows: Array[RoadStrip] = []
var scenery: Array[RoadScenery] = []


func _ready() -> void:
	for child in $Rows.get_children():
		rows.append(child as RoadStrip)
	for child in $Scenery.get_children():
		scenery.append(child as RoadScenery)
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
	return centre_x(screen_y) + (coordinate - 1.5) * LANE_WIDTH


func curve_offset(screen_y: float) -> float:
	return sin((scroll + playfield_bottom - screen_y) / 100.0) * 19.0 * curve_strength


func centre_x(screen_y: float) -> float:
	return 140.0 + curve_offset(screen_y)


func offset_limit(car_half_width: float) -> float:
	# Keep the complete artwork on asphalt, with two pixels of clearance.
	return maxf(0.0, width * 0.5 - car_half_width - 2.0)


func minimum_lane() -> int:
	return 1 if section == Section.NARROW else 0


func maximum_lane() -> int:
	return 2 if section == Section.NARROW else 3


func refresh() -> void:
	for row in rows:
		var screen_y: float = playfield_top + float(row.get_index() * 8)
		row.position.y = screen_y + 4.0
		row.visible = screen_y < playfield_bottom
		if not row.visible:
			continue
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
		row.ice_mark.visible = (
			section == Section.ICE and int((screen_y + scroll) / 8.0) % 19 == 0
		)
		row.ice_mark.position.x = centre_x + float((row.get_index() * 17) % 70 - 35)
	refresh_scenery()


func refresh_scenery() -> void:
	# Twenty-four rows on each side recycle without allocating during gameplay.
	var spacing: float = 96.0
	var cycle_length: float = spacing * 24.0
	for index in range(scenery.size()):
		var prop: RoadScenery = scenery[index]
		var slot: int = index / 2
		var side: int = -1 if index % 2 == 0 else 1
		var distance: float = scroll + slot * spacing
		var screen_y: float = playfield_top - 24.0 + fposmod(distance, cycle_length)
		var edge_x: float = centre_x(screen_y) + side * width * 0.5
		var screen_x: float = edge_x + side * 14.0
		if slot % 2 != 0:
			screen_x = 12.0 if side < 0 else 268.0
		var fits: bool = screen_x >= 8.0 and screen_x <= 272.0
		var outside_road: bool = (
			screen_x + 8.0 <= edge_x - 4.0 if side < 0 else screen_x - 8.0 >= edge_x + 4.0
		)
		fits = fits and outside_road
		# Leave the repair bay and its label unobstructed.
		var covers_pit: bool = screen_x < 44.0 and absf(screen_y - player_y) < 60.0
		prop.visible = (
			fits and not covers_pit
			and screen_y >= playfield_top + 12.0 and screen_y <= playfield_bottom - 12.0
		)
		if not prop.visible:
			continue
		prop.position = Vector2(screen_x, screen_y)
		var cycle: int = floori(distance / cycle_length)
		var kind: int = (slot * 7 + index % 2 * 3 + cycle * 3) % 5
		prop.configure(kind, section)

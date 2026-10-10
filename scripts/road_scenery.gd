class_name RoadScenery
extends Node2D
## Eight pixel props share a texture; decorations never affect collision geometry.

@onready var sprite: Sprite2D = $Sprite
@onready var reflector: Sprite2D = $Reflector


func configure(kind: int, section: int) -> void:
	var frame: int = kind
	if section == RaceRoad.Section.ICE and kind <= 2:
		frame = kind + 5
	sprite.frame = frame
	sprite.modulate = (
		Color("687084") if section == RaceRoad.Section.NIGHT else Color.WHITE
	)
	reflector.visible = section == RaceRoad.Section.NIGHT and (kind == 2 or kind == 3 or kind == 4)
	reflector.position = Vector2(0.0, -2.0 if kind == 2 else -6.0)

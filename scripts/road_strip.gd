class_name RoadStrip
extends Node2D
## Cache scene nodes once; the scrolling track does not search the tree every frame.

@onready var grass: Sprite2D = $Grass
@onready var surface: Sprite2D = $Surface
@onready var left_edge: Sprite2D = $LeftEdge
@onready var right_edge: Sprite2D = $RightEdge
@onready var dashes: Array[Sprite2D] = [$Dash0, $Dash1, $Dash2]
@onready var scenery: Sprite2D = $Scenery

class_name SpriteAtlas
extends Resource
## Replace the two PNGs or edit the row map without changing simulation/renderers.
@export var body: Texture2D
@export var team_mask: Texture2D
@export var cell_size := 16
@export var frames := 4
@export var frame_ticks := 4
@export var rows: Dictionary = {}

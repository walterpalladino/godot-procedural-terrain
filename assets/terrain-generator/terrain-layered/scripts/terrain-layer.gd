@tool
extends Resource
class_name TerrainLayer


@export var start_height : float
@export var end_height : float
@export var texture : Texture2D
@export var normal : Texture2D
@export_range(0.0, 1.0) var normal_strength : float = 1.0
@export var tile_scale : float = 1.0

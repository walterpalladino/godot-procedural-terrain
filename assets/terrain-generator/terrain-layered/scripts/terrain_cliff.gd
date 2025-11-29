@tool
extends Resource
class_name TerrainCliff

@export var enabled : bool = false
@export_range(0.0, 90.0) var minimum_steepness : float = 60.0
@export var texture : Texture2D
@export var normal : Texture2D
@export_range(0.0, 5.0) var normal_strength : float = 1.0
@export_color_no_alpha var color : Color = Color.WHITE
@export var texture_scale : float = 1.0

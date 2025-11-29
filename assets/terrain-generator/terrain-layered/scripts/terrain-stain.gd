@tool
extends Resource
class_name TerrainStain

@export var texture : Texture2D
@export_color_no_alpha var color : Color = Color.WHITE
@export var texture_scale : float = 1.0
@export_range(0.0, 1.0) var strength : float = 0.5

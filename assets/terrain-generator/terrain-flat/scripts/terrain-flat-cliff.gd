@tool
extends Resource
class_name TerrainFlatCliff

@export var enabled : bool = false
@export_range(0.0, 90.0) var minimum_steepness : float = 60.0
@export_color_no_alpha var color : Color = Color.WHITE

@tool
extends MeshInstance3D

@export var update = false


# Called when the node enters the scene tree for the first time.
func _ready():
	generate_terrain()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if update:
		generate_terrain()
		update = false


func generate_terrain():
	
	var array_mesh = ArrayMesh.new()
	
	var vertices = PackedVector3Array(
		[
			Vector3(0,0,0),
			Vector3(1,0,0),
			Vector3(1,0,1),
			Vector3(0,0,1),
		]
	)
	
	var indices = PackedInt32Array(
		[
			0,1,2,
			0,2,3
		]
	)

	var uvs = PackedVector2Array(
		[
			Vector2(0,0),
			Vector2(1,0),
			Vector2(1,1),
			Vector2(0,1)
		]	
	)

	#var array = []
	#array.resize(Mesh.ARRAY_MAX)
	
	#array[Mesh.ARRAY_VERTEX] = vertices
	#array[Mesh.ARRAY_INDEX] = indices
	#array[Mesh.ARRAY_TEX_UV] = uvs
	
	#array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	
	#mesh = array_mesh

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(vertices.size()):
		surface_tool.set_uv(uvs[i])
		surface_tool.add_vertex(vertices[i])
	for i in indices:
		surface_tool.add_index(i)	
	surface_tool.generate_normals()
	array_mesh = surface_tool.commit()

	mesh = array_mesh

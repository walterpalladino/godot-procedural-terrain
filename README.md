# Godot Procedural Terrain

Creates Multimes3D meshes to be used as terrain.

### Features

- Flat terrain
- Automatic textured terrain
- Layer (splatmap) based terrain
- Custom LOD
- Mesh based LOD
- Cliff creation
- Custom shaders


## How to use it?

There are somples for the type of generators included in this project for easy testing but you can create a new scene and add the script that match better your requirements.
The available scripts are:
- terrain-layered-generator.gd
- terrain-generator.gd
- terrain-flat-generator.gd


### Terrain Layered

This type of terrain intends to mimic the splatmap desing used in Unity

### Terrain (Textured)

This type of terrain pass most of the logic to the shader so the generator just creates the heightmap.

### Terrain Flat

This type of terrain creates a flat terrain colored using Vertex colors assigned to the mesh when created.

## Thanks

Includes as part of this repo are some free assets including models and textures.

class_name ArchipelagoDirectorV3
extends "res://scripts/world/archipelago_director_v2.gd"

func _ready() -> void:
    # Une seule île est active à la fois : 56 subdivisions restent légères sur Android
    # tout en supprimant l'aspect polygonal grossier vu sur téléphone.
    terrain_resolution = 56
    super._ready()

# La V3 ne disperse plus des GLB sans normalisation via le vieux système.
# Le décor est construit par GLBSceneryDirector avec taille, placement au sol
# et zones de circulation mobile contrôlées.
func _scatter_real_props(_info: Dictionary) -> void:
    pass

func _build_terrain(info: Dictionary) -> void:
    super._build_terrain(info)
    if _island_root == null or not is_instance_valid(_island_root):
        return
    var terrain: MeshInstance3D = _island_root.get_node_or_null("TerrainRelief") as MeshInstance3D
    if terrain == null:
        return

    var shader: Shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 core_color : source_color = vec4(0.25, 0.55, 0.30, 1.0);
uniform vec4 coast_color : source_color = vec4(0.76, 0.62, 0.38, 1.0);
uniform vec4 rock_color : source_color = vec4(0.30, 0.29, 0.27, 1.0);
uniform vec2 island_half_size = vec2(600.0, 500.0);
varying vec3 local_pos;
void vertex() {
    local_pos = VERTEX;
}
void fragment() {
    vec2 normalized_xz = local_pos.xz / max(island_half_size, vec2(1.0));
    float radial = length(normalized_xz);
    float coast = smoothstep(0.68, 0.94, radial);
    float ridge = smoothstep(12.0, 32.0, local_pos.y);
    vec3 col = mix(core_color.rgb, coast_color.rgb, coast);
    col = mix(col, rock_color.rgb, ridge * (1.0 - coast * 0.55));
    float variation = sin(local_pos.x * 0.032) * cos(local_pos.z * 0.027) * 0.035;
    ALBEDO = clamp(col + vec3(variation), vec3(0.0), vec3(1.0));
    ROUGHNESS = 0.90;
    METALLIC = 0.0;
}
"""

    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    var palette: Dictionary = _terrain_palette(int(info["id"]), info["color"])
    material.set_shader_parameter("core_color", palette["core"])
    material.set_shader_parameter("coast_color", palette["coast"])
    material.set_shader_parameter("rock_color", palette["rock"])
    var size: Vector2 = info["size"]
    material.set_shader_parameter("island_half_size", size * 0.5)
    terrain.material_override = material

func _terrain_palette(island_id: int, base_color: Color) -> Dictionary:
    match island_id:
        2:
            return {"core": base_color, "coast": Color("e9b0c4"), "rock": Color("7a5967")}
        4:
            return {"core": base_color, "coast": Color("7f9bab"), "rock": Color("35434e")}
        5:
            return {"core": base_color, "coast": Color("6e737c"), "rock": Color("30343b")}
        6:
            return {"core": base_color, "coast": Color("b9b66a"), "rock": Color("53634f")}
        7:
            return {"core": base_color, "coast": Color("b89562"), "rock": Color("493d31")}
        8:
            return {"core": Color("d9edf6"), "coast": Color("c5e3ef"), "rock": Color("8297a3")}
        9:
            return {"core": Color("5a3630"), "coast": Color("7d4130"), "rock": Color("272222")}
        10:
            return {"core": base_color, "coast": Color("9b875d"), "rock": Color("413d32")}
        11:
            return {"core": base_color, "coast": Color("76664a"), "rock": Color("2f2b27")}
        _:
            return {"core": base_color, "coast": Color("c8ad72"), "rock": Color("55514a")}

# Le joueur ne démarre plus au bout étroit du quai entouré d'eau.
# Il arrive à l'entrée du port, sur une zone large, dégagée et orientée vers l'île.
func _safe_port_spawn(index: int) -> Vector3:
    var resolved: int = clampi(index, 0, WorldCatalog.island_count() - 1)
    var info: Dictionary = WorldCatalog.island(resolved)
    var size: Vector2 = info["size"]
    var local_z: float = size.y * 0.34
    return _positions[resolved] + Vector3(0.0, 10.0, local_z)

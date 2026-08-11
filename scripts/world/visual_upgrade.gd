extends Node

const WATER_SHADER_CODE := """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.015, 0.11, 0.24, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.02, 0.34, 0.52, 1.0);
uniform float daylight = 1.0;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float w1 = sin(world_pos.x * 0.035 + TIME * 0.58);
    float w2 = sin(world_pos.z * 0.047 - TIME * 0.74);
    float w3 = sin((world_pos.x + world_pos.z) * 0.021 + TIME * 0.41);
    float wave = (w1 + w2 + w3) / 3.0;
    float crest = smoothstep(0.48, 0.92, wave);
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
    vec3 water = mix(deep_color.rgb, shallow_color.rgb, wave * 0.5 + 0.5);
    water = mix(water, vec3(0.24, 0.48, 0.62), fresnel * 0.38);
    water += crest * vec3(0.10, 0.14, 0.16);
    water *= mix(0.48, 1.08, daylight);
    ALBEDO = water;
    METALLIC = 0.18;
    SPECULAR = 0.78;
    ROUGHNESS = mix(0.12, 0.28, crest);
    ALPHA = 0.93;
}
"""

const TERRAIN_SHADER_CODE := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 island_color : source_color = vec4(0.28, 0.48, 0.22, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    float h = world_pos.y;
    float slope = 1.0 - clamp(abs(world_normal.y), 0.0, 1.0);
    float broad = sin(world_pos.x * 0.031 + sin(world_pos.z * 0.017) * 1.7);
    float grain = sin(world_pos.x * 0.12) * sin(world_pos.z * 0.095);
    float fine = sin(world_pos.x * 0.53 + world_pos.z * 0.19) *
                 sin(world_pos.z * 0.47 - world_pos.x * 0.13);
    float cell = fract(sin(dot(floor(world_pos.xz * 0.38), vec2(12.9898, 78.233))) * 43758.5453);

    vec3 sand = mix(vec3(0.56, 0.39, 0.20), island_color.rgb, 0.22);
    vec3 grass = mix(vec3(0.10, 0.31, 0.09), island_color.rgb, 0.62);
    vec3 rock = mix(vec3(0.29, 0.27, 0.25), island_color.rgb, 0.20);
    vec3 summit = mix(vec3(0.62, 0.63, 0.61), island_color.rgb, 0.18);

    float land = smoothstep(-1.4, 4.5, h);
    vec3 color = mix(sand, grass, land);
    float soil_patch = smoothstep(0.73, 0.94, cell + broad * 0.10) * land;
    color = mix(color, mix(sand, rock, 0.28), soil_patch * 0.22);
    float rock_amount = clamp(smoothstep(0.22, 0.70, slope) + smoothstep(22.0, 48.0, h) * 0.42, 0.0, 1.0);
    color = mix(color, rock, rock_amount);
    color = mix(color, summit, smoothstep(42.0, 72.0, h));
    color *= 0.965 + broad * 0.028 + grain * 0.026 + fine * 0.012;

    ALBEDO = color;
    ROUGHNESS = mix(0.93, 0.72, rock_amount);
    METALLIC = 0.015;
    SPECULAR = 0.28;
}
"""

var _scan_clock := 0.0
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _water_material: ShaderMaterial
var _terrain_shader: Shader
var _active_island_id := 0
var _lanterns: Array[OmniLight3D] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _terrain_shader = Shader.new()
    _terrain_shader.code = TERRAIN_SHADER_CODE
    call_deferred("_refresh_visuals")

func _process(delta: float) -> void:
    _scan_clock += delta
    if _scan_clock >= 0.65:
        _scan_clock = 0.0
        _refresh_visuals()
    _update_atmosphere()

func _refresh_visuals() -> void:
    var root := get_tree().current_scene
    if root == null:
        return
    _ensure_environment(root)
    _ensure_ocean(root)
    var terrain := _find_mesh_by_name(root, "TerrainRelief")
    if terrain != null:
        var island := terrain.get_parent()
        if island != null and island.get_instance_id() != _active_island_id:
            _active_island_id = island.get_instance_id()
            _upgrade_island(island)

func _ensure_environment(root: Node) -> void:
    if _environment == null:
        var world_environment := _find_world_environment(root)
        if world_environment != null and world_environment.environment != null:
            _environment = world_environment.environment
    if _sun == null:
        _sun = _find_sun(root)
    if _environment == null:
        return
    if _sky_material == null:
        _sky_material = ProceduralSkyMaterial.new()
        _sky_material.sky_top_color = Color("1b4b78")
        _sky_material.sky_horizon_color = Color("88c9e8")
        _sky_material.ground_horizon_color = Color("7591a0")
        _sky_material.ground_bottom_color = Color("24343d")
        _sky_material.sky_curve = 0.11
        _sky_material.ground_curve = 0.08
        _sky_material.sun_angle_max = 18.0
        _sky_material.sun_curve = 0.09
        _sky_material.use_debanding = true
        var sky := Sky.new()
        sky.sky_material = _sky_material
        _environment.sky = sky
        _environment.background_mode = Environment.BG_SKY
        _environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        _environment.ambient_light_sky_contribution = 0.72
        _environment.adjustment_enabled = true
        _environment.adjustment_brightness = 1.03
        _environment.adjustment_contrast = 1.07
        _environment.adjustment_saturation = 1.08
        _environment.fog_sky_affect = 0.54
    if _sun != null:
        _sun.shadow_enabled = true
        _sun.shadow_bias = 0.035
        _sun.shadow_normal_bias = 1.1

func _ensure_ocean(root: Node) -> void:
    var ocean := _find_mesh_by_name(root, "OceanContinu")
    if ocean == null or ocean.has_meta("chk_visual_v8_water"):
        return
    var shader := Shader.new()
    shader.code = WATER_SHADER_CODE
    _water_material = ShaderMaterial.new()
    _water_material.shader = shader
    _water_material.set_shader_parameter("deep_color", Color(0.012, 0.10, 0.23, 1.0))
    _water_material.set_shader_parameter("shallow_color", Color(0.02, 0.36, 0.54, 1.0))
    ocean.material_override = _water_material
    ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ocean.set_meta("chk_visual_v8_water", true)

func _upgrade_island(island: Node) -> void:
    _lanterns.clear()
    var terrain := _find_mesh_by_name(island, "TerrainRelief")
    if terrain != null:
        _upgrade_terrain(terrain)
    var port := _find_by_name(island, "PortPrincipal")
    if port is Node3D:
        _upgrade_port(port as Node3D)
    _enable_prop_shadows(island)

func _upgrade_terrain(terrain: MeshInstance3D) -> void:
    if terrain.has_meta("chk_visual_v8_terrain"):
        return
    var base_color := Color(0.28, 0.48, 0.22, 1.0)
    var old_material := terrain.material_override
    if old_material is StandardMaterial3D:
        base_color = (old_material as StandardMaterial3D).albedo_color
    var material := ShaderMaterial.new()
    material.shader = _terrain_shader
    material.set_shader_parameter("island_color", base_color)
    terrain.material_override = material
    terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    terrain.set_meta("chk_visual_v8_terrain", true)

func _upgrade_port(port: Node3D) -> void:
    if port.has_meta("chk_visual_v8_port"):
        return
    port.set_meta("chk_visual_v8_port", true)
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color("4f2f1d")
    wood.roughness = 0.86
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("2d3136")
    metal.metallic = 0.62
    metal.roughness = 0.38
    var glow := StandardMaterial3D.new()
    glow.albedo_color = Color("ffd58a")
    glow.emission_enabled = true
    glow.emission = Color("ffb85c")
    glow.emission_energy_multiplier = 2.8

    for z in [4.0, 29.0]:
        for x in [-4.2, 4.2]:
            var post := MeshInstance3D.new()
            post.name = "PoteauPortV8"
            var post_mesh := BoxMesh.new()
            post_mesh.size = Vector3(0.42, 3.4, 0.42)
            post.mesh = post_mesh
            post.position = Vector3(x, 1.55, z)
            post.material_override = wood
            port.add_child(post)

            var cap := MeshInstance3D.new()
            cap.name = "LanternePortV8"
            var cap_mesh := SphereMesh.new()
            cap_mesh.radius = 0.22
            cap_mesh.height = 0.44
            cap_mesh.radial_segments = 10
            cap_mesh.rings = 5
            cap.mesh = cap_mesh
            cap.position = Vector3(x, 3.35, z)
            cap.material_override = glow
            port.add_child(cap)

            var frame := MeshInstance3D.new()
            frame.name = "CadreLanterneV8"
            var frame_mesh := CylinderMesh.new()
            frame_mesh.top_radius = 0.31
            frame_mesh.bottom_radius = 0.31
            frame_mesh.height = 0.08
            frame_mesh.radial_segments = 10
            frame.mesh = frame_mesh
            frame.position = Vector3(x, 3.36, z)
            frame.material_override = metal
            port.add_child(frame)

            var light := OmniLight3D.new()
            light.name = "LumierePortV8"
            light.position = Vector3(x, 3.35, z)
            light.light_color = Color("ffbf70")
            light.light_energy = 0.0
            light.omni_range = 12.0
            light.shadow_enabled = false
            port.add_child(light)
            _lanterns.append(light)

func _enable_prop_shadows(root: Node) -> void:
    if root is MeshInstance3D:
        var mesh := root as MeshInstance3D
        if mesh.name != "OceanContinu" and not mesh.name.contains("Horizon"):
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    for child in root.get_children():
        _enable_prop_shadows(child)

func _update_atmosphere() -> void:
    if _sun == null or _environment == null or _sky_material == null:
        return
    var daylight := clampf((_sun.light_energy - 0.15) / 1.25, 0.0, 1.0)
    var night_top := Color("071322")
    var day_top := Color("1b5f98")
    var night_horizon := Color("152b42")
    var day_horizon := Color("8fd4f1")
    var dusk := Color("f1a25f")
    var horizon := night_horizon.lerp(day_horizon, daylight)
    if daylight > 0.18 and daylight < 0.58:
        var dusk_strength := 1.0 - absf(daylight - 0.38) / 0.20
        horizon = horizon.lerp(dusk, clampf(dusk_strength * 0.42, 0.0, 0.42))
    var weather_strength := clampf(_environment.fog_density * 10.0, 0.0, 0.34)
    horizon = horizon.lerp(_environment.fog_light_color, weather_strength)
    _sky_material.sky_top_color = night_top.lerp(day_top, daylight).lerp(_environment.fog_light_color, weather_strength * 0.35)
    _sky_material.sky_horizon_color = horizon
    _sky_material.ground_horizon_color = horizon.darkened(0.28)
    _sky_material.ground_bottom_color = Color("081017").lerp(Color("263b3f"), daylight)
    _sky_material.energy_multiplier = 0.38 + daylight * 0.82
    _sun.light_color = Color("9db4d8").lerp(Color("fff1cf"), daylight)
    _environment.adjustment_saturation = 0.93 + daylight * 0.17
    if _water_material != null:
        _water_material.set_shader_parameter("daylight", 0.35 + daylight * 0.65)
    var lantern_energy := (1.0 - daylight) * 2.7
    for light in _lanterns:
        if is_instance_valid(light):
            light.light_energy = lantern_energy

func _find_world_environment(root: Node) -> WorldEnvironment:
    if root is WorldEnvironment:
        return root as WorldEnvironment
    for child in root.get_children():
        var found := _find_world_environment(child)
        if found != null:
            return found
    return null

func _find_sun(root: Node) -> DirectionalLight3D:
    if root is DirectionalLight3D and root.name == "SoleilDynamique":
        return root as DirectionalLight3D
    for child in root.get_children():
        var found := _find_sun(child)
        if found != null:
            return found
    return null

func _find_mesh_by_name(root: Node, target_name: String) -> MeshInstance3D:
    if root is MeshInstance3D and root.name == target_name:
        return root as MeshInstance3D
    for child in root.get_children():
        var found := _find_mesh_by_name(child, target_name)
        if found != null:
            return found
    return null

func _find_by_name(root: Node, target_name: String) -> Node:
    if root.name == target_name:
        return root
    for child in root.get_children():
        var found := _find_by_name(child, target_name)
        if found != null:
            return found
    return null

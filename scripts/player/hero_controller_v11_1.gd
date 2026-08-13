class_name HeroControllerV11_1
extends "res://scripts/player/hero_controller_v10.gd"

var _aura_root: Node3D
var _aura_rings: Array[Node3D] = []
var _aura_satellites: Array[Node3D] = []
var _aura_time := 0.0
var _attack_visual_boost := 0.0

func _ready() -> void:
    super._ready()
    _build_hero_aura.call_deferred()

func _process(delta: float) -> void:
    _aura_time += delta
    _attack_visual_boost = maxf(0.0, _attack_visual_boost - delta)
    _animate_hero_aura()

func basic_attack() -> void:
    super.basic_attack()
    _attack_visual_boost = 0.55
    _spawn_attack_signature(1, {
        "effect": str(hero_data.get("base_attack_effect", "basic")),
        "color": str(hero_data.get("base_attack_color", "ffffff")),
        "radius": float(hero_data.get("base_attack_radius", 3.0))
    })

func use_ability(index: int) -> bool:
    var abilities: Array = hero_data.get("abilities", [])
    var preview: Dictionary = {}
    if index >= 0 and index < abilities.size():
        preview = abilities[index]
    var used := super.use_ability(index)
    if used:
        _attack_visual_boost = 0.85 if index == 0 else 1.20
        _spawn_attack_signature(index + 2, preview)
    return used

func _on_hero_changed(hero_id: String) -> void:
    super._on_hero_changed(hero_id)
    _build_hero_aura.call_deferred()

func _build_hero_aura() -> void:
    if _aura_root != null and is_instance_valid(_aura_root):
        _aura_root.queue_free()
    _aura_rings.clear()
    _aura_satellites.clear()

    _aura_root = Node3D.new()
    _aura_root.name = "HeroAuraV11_1"
    add_child(_aura_root)

    var primary := Color(str(hero_data.get("aura_color", "ffffff")))
    var secondary := Color(str(hero_data.get("aura_secondary", "ffffff")))
    var style := str(hero_data.get("aura_style", "energy"))

    for i in range(3):
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.78 + float(i) * 0.24
        torus.outer_radius = torus.inner_radius + 0.055
        torus.rings = 24
        torus.ring_segments = 7
        ring.mesh = torus
        ring.position.y = 0.08 + float(i) * 0.035
        ring.material_override = _emissive_material(primary.lerp(secondary, float(i) * 0.30), 1.15, 0.56)
        _aura_root.add_child(ring)
        _aura_rings.append(ring)

    match style:
        "cerberus_fire":
            _build_cerberus_satellites(primary, secondary)
        "electric_storm":
            _build_electric_satellites(primary, secondary)
        "crystal_flame":
            _build_crystal_satellites(primary, secondary)
        _:
            _build_electric_satellites(primary, secondary)

func _build_cerberus_satellites(primary: Color, secondary: Color) -> void:
    # Trois foyers de feu = les trois têtes de Cerbère.
    for i in range(3):
        var orb := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.16
        sphere.height = 0.32
        sphere.radial_segments = 10
        sphere.rings = 5
        orb.mesh = sphere
        orb.material_override = _emissive_material(primary.lerp(secondary, float(i) * 0.35), 2.4, 0.18)
        _aura_root.add_child(orb)
        orb.set_meta("orbit_index", i)
        orb.set_meta("orbit_kind", "cerberus")
        _aura_satellites.append(orb)

func _build_electric_satellites(primary: Color, secondary: Color) -> void:
    # Étincelles séparées et rapides autour de Yvane, donnant une aura électrique.
    for i in range(10):
        var spark := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.055 if i % 3 else 0.085
        sphere.height = sphere.radius * 2.0
        sphere.radial_segments = 6
        sphere.rings = 3
        spark.mesh = sphere
        spark.material_override = _emissive_material(primary if i % 2 == 0 else secondary, 3.0, 0.10)
        _aura_root.add_child(spark)
        spark.set_meta("orbit_index", i)
        spark.set_meta("orbit_kind", "electric")
        _aura_satellites.append(spark)

func _build_crystal_satellites(primary: Color, secondary: Color) -> void:
    # Éclats violets et rouges : l'aura de Nelvyn n'utilise pas l'électricité.
    for i in range(7):
        var shard := MeshInstance3D.new()
        var crystal := CylinderMesh.new()
        crystal.top_radius = 0.02
        crystal.bottom_radius = 0.10
        crystal.height = 0.44 + float(i % 3) * 0.10
        crystal.radial_segments = 5
        shard.mesh = crystal
        shard.material_override = _emissive_material(primary if i % 2 == 0 else secondary, 2.1, 0.22)
        _aura_root.add_child(shard)
        shard.set_meta("orbit_index", i)
        shard.set_meta("orbit_kind", "crystal")
        _aura_satellites.append(shard)

func _animate_hero_aura() -> void:
    if _aura_root == null or not is_instance_valid(_aura_root):
        return
    var boost := 1.0 + minf(0.65, _attack_visual_boost)

    for i in range(_aura_rings.size()):
        var ring := _aura_rings[i]
        if ring == null or not is_instance_valid(ring):
            continue
        var pulse := 1.0 + sin(_aura_time * (2.0 + float(i) * 0.35) + float(i)) * 0.07
        ring.scale = Vector3.ONE * pulse * boost
        ring.rotation.y = _aura_time * (0.45 + float(i) * 0.22) * (-1.0 if i % 2 else 1.0)

    for satellite in _aura_satellites:
        if satellite == null or not is_instance_valid(satellite):
            continue
        var index := int(satellite.get_meta("orbit_index", 0))
        var kind := str(satellite.get_meta("orbit_kind", "energy"))
        match kind:
            "cerberus":
                var angle := _aura_time * 1.7 + TAU * float(index) / 3.0
                satellite.position = Vector3(cos(angle) * 0.88, 1.05 + sin(_aura_time * 3.0 + index) * 0.18, sin(angle) * 0.88)
                satellite.scale = Vector3.ONE * (1.0 + sin(_aura_time * 6.0 + index) * 0.18) * boost
            "electric":
                var angle := _aura_time * (2.8 + float(index % 3) * 0.33) + float(index) * 1.73
                var radius := 0.58 + float(index % 4) * 0.16
                var height := 0.35 + fmod(float(index) * 0.37 + _aura_time * 2.8, 1.65)
                satellite.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
                var flicker := 0.55 + absf(sin(_aura_time * 12.0 + float(index) * 2.1)) * 0.85
                satellite.scale = Vector3.ONE * flicker * boost
            "crystal":
                var angle := _aura_time * 0.75 + TAU * float(index) / maxf(1.0, float(_aura_satellites.size()))
                satellite.position = Vector3(cos(angle) * 1.02, 0.30 + sin(_aura_time * 1.8 + index) * 0.10, sin(angle) * 1.02)
                satellite.rotation_degrees = Vector3(18.0 + float(index) * 6.0, rad_to_deg(-angle), 10.0 * sin(_aura_time + index))
                satellite.scale = Vector3.ONE * boost

func _spawn_attack_signature(tier: int, attack: Dictionary) -> void:
    var effect := str(attack.get("effect", "energy"))
    var color := Color(str(attack.get("color", hero_data.get("base_attack_color", "ffffff"))))
    var radius := maxf(2.0, float(attack.get("radius", 3.0)))
    var hero_id := str(GameState.selected_hero)

    if hero_id == "cheikh":
        _spawn_cerberus_burst(color, radius, tier)
    elif hero_id == "yvane":
        _spawn_electric_burst(color, radius, tier)
    else:
        _spawn_crystal_burst(color, radius, tier, effect)

func _spawn_cerberus_burst(color: Color, radius: float, tier: int) -> void:
    var burst := Node3D.new()
    burst.name = "CerberusAttackFx"
    add_child(burst)
    for i in range(3):
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.55 + float(i) * 0.20
        torus.outer_radius = torus.inner_radius + 0.11
        torus.rings = 20
        torus.ring_segments = 7
        ring.mesh = torus
        ring.position.y = 0.18 + float(i) * 0.08
        ring.rotation.y = TAU * float(i) / 3.0
        ring.material_override = _emissive_material(color.lightened(float(i) * 0.12), 2.8, 0.22)
        burst.add_child(ring)
    var final_scale := minf(5.5, 1.0 + radius * (0.20 + float(tier) * 0.035))
    var tween := create_tween()
    tween.tween_property(burst, "scale", Vector3.ONE * final_scale, 0.38 + float(tier) * 0.06)
    tween.tween_callback(burst.queue_free)

func _spawn_electric_burst(color: Color, radius: float, tier: int) -> void:
    var burst := Node3D.new()
    burst.name = "ElectricAttackFx"
    add_child(burst)
    var count := 8 + tier * 4
    for i in range(count):
        var spark := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.07 + float(i % 3) * 0.018
        sphere.height = sphere.radius * 2.0
        sphere.radial_segments = 6
        sphere.rings = 3
        spark.mesh = sphere
        var angle := TAU * float(i) / float(count)
        var r := 0.6 + float(i % 4) * 0.22
        spark.position = Vector3(cos(angle) * r, 0.35 + float(i % 5) * 0.28, sin(angle) * r)
        spark.material_override = _emissive_material(color.lightened(0.12 * float(i % 2)), 3.4, 0.08)
        burst.add_child(spark)
    var final_scale := minf(6.2, 1.0 + radius * (0.24 + float(tier) * 0.045))
    var tween := create_tween()
    tween.tween_property(burst, "scale", Vector3.ONE * final_scale, 0.30 + float(tier) * 0.08)
    tween.tween_callback(burst.queue_free)

func _spawn_crystal_burst(color: Color, radius: float, tier: int, _effect: String) -> void:
    var burst := Node3D.new()
    burst.name = "CrystalAttackFx"
    add_child(burst)
    var count := 5 + tier * 3
    for i in range(count):
        var shard := MeshInstance3D.new()
        var crystal := CylinderMesh.new()
        crystal.top_radius = 0.015
        crystal.bottom_radius = 0.10 + float(tier) * 0.012
        crystal.height = 0.60 + float(tier) * 0.18
        crystal.radial_segments = 5
        shard.mesh = crystal
        var angle := TAU * float(i) / float(count)
        shard.position = Vector3(cos(angle) * (0.65 + 0.12 * i), 0.32, sin(angle) * (0.65 + 0.12 * i))
        shard.rotation_degrees = Vector3(18.0, -rad_to_deg(angle), 15.0 * sin(angle))
        shard.material_override = _emissive_material(color.lightened(0.15 * float(i % 2)), 2.7, 0.15)
        burst.add_child(shard)
    var final_scale := minf(5.8, 1.0 + radius * (0.22 + float(tier) * 0.04))
    var tween := create_tween()
    tween.tween_property(burst, "scale", Vector3.ONE * final_scale, 0.40 + float(tier) * 0.07)
    tween.tween_callback(burst.queue_free)

func _emissive_material(color: Color, energy_value: float, alpha_value: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(color.r, color.g, color.b, clampf(alpha_value, 0.05, 1.0))
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy_value
    material.roughness = 0.18
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if alpha_value < 0.99:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

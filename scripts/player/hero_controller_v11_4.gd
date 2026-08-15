class_name HeroControllerV11_4
extends "res://scripts/player/hero_controller_v11_1.gd"

var _coop_identity_root: Node3D

func _ready() -> void:
    super._ready()
    _rebuild_coop_identity.call_deferred()

func _on_hero_changed(hero_id: String) -> void:
    super._on_hero_changed(hero_id)
    _rebuild_coop_identity.call_deferred()

func _rebuild_coop_identity() -> void:
    if _coop_identity_root != null and is_instance_valid(_coop_identity_root):
        _coop_identity_root.queue_free()

    _coop_identity_root = Node3D.new()
    _coop_identity_root.name = "CoopIdentityV11_4"
    add_child(_coop_identity_root)

    var color := _identity_color(str(GameState.selected_hero))

    var ring := MeshInstance3D.new()
    ring.name = "HeroIdentityRing"
    var torus := TorusMesh.new()
    torus.inner_radius = 1.12
    torus.outer_radius = 1.22
    torus.rings = 28
    torus.ring_segments = 8
    ring.mesh = torus
    ring.position.y = 0.045
    ring.material_override = _identity_material(color, 2.2, 0.88)
    _coop_identity_root.add_child(ring)

    for i in range(3):
        var marker := MeshInstance3D.new()
        marker.name = "IdentityBeacon_%d" % i
        var sphere := SphereMesh.new()
        sphere.radius = 0.075
        sphere.height = 0.15
        sphere.radial_segments = 6
        sphere.rings = 3
        marker.mesh = sphere
        var angle := TAU * float(i) / 3.0
        marker.position = Vector3(cos(angle) * 1.22, 0.12, sin(angle) * 1.22)
        marker.material_override = _identity_material(color, 3.0, 1.0)
        _coop_identity_root.add_child(marker)

func _identity_color(hero_id: String) -> Color:
    if GameState.has_method("hero_identity_color"):
        return GameState.call("hero_identity_color", hero_id)
    match hero_id.to_lower():
        "cheikh": return Color("22c55e")
        "yvane": return Color("ef4444")
        "nelvyn": return Color("facc15")
        _: return Color.WHITE

func _identity_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(color.r, color.g, color.b, alpha)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    material.roughness = 0.15
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if alpha < 0.99:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

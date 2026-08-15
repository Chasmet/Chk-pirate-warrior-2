class_name RemotePlayerAvatarV11_4
extends "res://scripts/network/remote_player_avatar.gd"

var _identity_root: Node3D
var _identity_ring: MeshInstance3D
var _shared_vehicle_seat := -1

func setup(id_value: int, hero_value: String, name_value: String) -> void:
    super.setup(id_value, hero_value, name_value)
    _rebuild_identity_marker()

func update_identity(hero_value: String, name_value: String) -> void:
    super.update_identity(hero_value, name_value)
    _rebuild_identity_marker()

func set_shared_vehicle_state(style: String, seat_index: int) -> void:
    _shared_vehicle_seat = seat_index
    if _identity_ring != null and is_instance_valid(_identity_ring):
        _identity_ring.visible = seat_index < 0

    if seat_index > 0:
        if not _mount_style.is_empty():
            _set_mount_style("")
        _play_animation_by_keywords(["drive", "driving", "ride", "riding", "sit", "idle"], true)
    elif seat_index == 0 and not style.is_empty() and _mount_style != style:
        _set_mount_style(style)

func _rebuild_identity_marker() -> void:
    if _identity_root != null and is_instance_valid(_identity_root):
        _identity_root.queue_free()

    _identity_root = Node3D.new()
    _identity_root.name = "RemoteIdentityV11_4"
    add_child(_identity_root)

    var color := _identity_color(hero_id)

    _identity_ring = MeshInstance3D.new()
    _identity_ring.name = "RemoteIdentityRing"
    var torus := TorusMesh.new()
    torus.inner_radius = 0.72
    torus.outer_radius = 0.82
    torus.rings = 22
    torus.ring_segments = 7
    _identity_ring.mesh = torus
    _identity_ring.position.y = 0.06
    _identity_ring.material_override = _identity_material(color, 2.4, 0.82)
    _identity_ring.visible = _shared_vehicle_seat < 0
    _identity_root.add_child(_identity_ring)

    var beacon := MeshInstance3D.new()
    beacon.name = "RemoteIdentityBeacon"
    var sphere := SphereMesh.new()
    sphere.radius = 0.10
    sphere.height = 0.20
    sphere.radial_segments = 8
    sphere.rings = 4
    beacon.mesh = sphere
    beacon.position = Vector3(0.0, 2.74, 0.0)
    beacon.material_override = _identity_material(color, 3.2, 1.0)
    _identity_root.add_child(beacon)

    if _name_label != null and is_instance_valid(_name_label):
        _name_label.modulate = color
        _name_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.96)
        _name_label.text = "%s • %s" % [display_name, hero_id.to_upper()]

func _identity_color(value: String) -> Color:
    match value.to_lower():
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
    material.roughness = 0.12
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if alpha < 0.99:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

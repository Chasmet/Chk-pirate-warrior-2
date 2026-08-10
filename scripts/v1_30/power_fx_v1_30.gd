class_name PowerFXDirectorV130
extends Node3D

# Rend enfin les capacités déjà présentes dans heroes.json visibles à l'écran.
# Cette couche n'altère pas les dégâts/cooldowns : elle ajoute aura, lumière et
# onde d'énergie autour du héros quand un vrai pouvoir est déclenché.
var _player: CharacterBody3D
var _aura_root: Node3D
var _aura_light: OmniLight3D
var _bursts: Array[Node3D] = []
var _time := 0.0
var _boost_remaining := 0.0

func _ready() -> void:
    add_to_group("power_fx_v1_30")
    if GameState.has_signal("hero_changed"):
        GameState.hero_changed.connect(_on_hero_changed)
    _bind_player.call_deferred()

func _process(delta: float) -> void:
    _time += delta
    _boost_remaining = maxf(0.0, _boost_remaining - delta)
    if _player == null or not is_instance_valid(_player):
        _bind_player()
        return
    _animate_aura(delta)
    _animate_bursts(delta)

func _bind_player() -> void:
    _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if _player == null:
        return
    var ability_callable := Callable(self, "_on_ability_used")
    if _player.has_signal("ability_used") and not _player.is_connected("ability_used", ability_callable):
        _player.connect("ability_used", ability_callable)
    _rebuild_aura()

func _on_hero_changed(_hero_id: String) -> void:
    _rebuild_aura.call_deferred()

func _rebuild_aura() -> void:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if _player == null:
        return
    if _aura_root != null and is_instance_valid(_aura_root):
        _aura_root.queue_free()

    _aura_root = Node3D.new()
    _aura_root.name = "AuraEnergieV130"
    _aura_root.position = Vector3(0.0, 0.10, 0.0)
    _player.add_child(_aura_root)

    var color := _hero_energy_color()
    for i in range(3):
        var ring := MeshInstance3D.new()
        ring.name = "AnneauAura_%02d" % i
        var torus := TorusMesh.new()
        torus.inner_radius = 0.48 + float(i) * 0.14
        torus.outer_radius = 0.55 + float(i) * 0.14
        torus.rings = 20
        torus.ring_segments = 7
        ring.mesh = torus
        ring.position.y = 0.03 + float(i) * 0.10
        ring.material_override = _energy_material(color, 1.8 - float(i) * 0.22, 0.70 - float(i) * 0.12)
        _aura_root.add_child(ring)

    var core := MeshInstance3D.new()
    core.name = "CoeurAura"
    var sphere := SphereMesh.new()
    sphere.radius = 0.34
    sphere.height = 0.68
    sphere.radial_segments = 16
    sphere.rings = 8
    core.mesh = sphere
    core.position = Vector3(0.0, 1.05, 0.0)
    core.scale = Vector3(1.15, 2.2, 1.15)
    core.material_override = _energy_material(color, 1.35, 0.10)
    _aura_root.add_child(core)

    _aura_light = OmniLight3D.new()
    _aura_light.name = "LumierePouvoir"
    _aura_light.light_color = color
    _aura_light.light_energy = 0.65
    _aura_light.omni_range = 4.5
    _aura_light.shadow_enabled = false
    _aura_light.position = Vector3(0.0, 1.1, 0.0)
    _aura_root.add_child(_aura_light)

func _animate_aura(_delta: float) -> void:
    if _aura_root == null or not is_instance_valid(_aura_root):
        return
    var boosted := _boost_remaining > 0.0
    var pulse := 1.0 + sin(_time * (8.0 if boosted else 3.2)) * (0.08 if boosted else 0.025)
    _aura_root.scale = Vector3.ONE * pulse
    for i in range(_aura_root.get_child_count()):
        var child := _aura_root.get_child(i)
        if child is MeshInstance3D and child.name.begins_with("AnneauAura"):
            child.rotation.y += (0.035 + float(i) * 0.018) * (2.4 if boosted else 1.0)
            child.rotation.z = sin(_time * 1.7 + float(i)) * 0.12
    if _aura_light != null:
        _aura_light.light_energy = 2.4 if boosted else 0.65 + sin(_time * 4.0) * 0.12
        _aura_light.omni_range = 8.5 if boosted else 4.5

func _on_ability_used(index: int, ability: Dictionary) -> void:
    _boost_remaining = 0.95
    _spawn_energy_burst(index, ability)
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", "POUVOIR • %s" % str(ability.get("name", "Capacité")), 1.25)

func _spawn_energy_burst(index: int, ability: Dictionary) -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var burst := Node3D.new()
    burst.name = "ImpactPouvoir_%d" % Time.get_ticks_msec()
    burst.position = Vector3(0.0, 0.18, 0.0)
    burst.set_meta("life", 0.0)
    burst.set_meta("duration", 0.55 if index == 0 else 0.78)
    burst.set_meta("radius", 4.0 if index == 0 else 6.5)
    _player.add_child(burst)

    var color := _hero_energy_color()
    var ring := MeshInstance3D.new()
    ring.name = "OndeEnergie"
    var torus := TorusMesh.new()
    torus.inner_radius = 0.82
    torus.outer_radius = 1.02
    torus.rings = 28
    torus.ring_segments = 8
    ring.mesh = torus
    ring.material_override = _energy_material(color, 3.2, 0.82)
    burst.add_child(ring)

    var flash := MeshInstance3D.new()
    flash.name = "FlashPouvoir"
    var sphere := SphereMesh.new()
    sphere.radius = 0.55
    sphere.height = 1.10
    sphere.radial_segments = 18
    sphere.rings = 9
    flash.mesh = sphere
    flash.position.y = 0.95
    flash.material_override = _energy_material(color.lerp(Color.WHITE, 0.20), 3.8, 0.38)
    burst.add_child(flash)

    var label := Label3D.new()
    label.name = "NomPouvoir"
    label.text = str(ability.get("name", "POUVOIR")).to_upper()
    label.position = Vector3(0.0, 2.55, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.font_size = 28
    label.outline_size = 7
    label.modulate = color.lerp(Color.WHITE, 0.25)
    label.outline_modulate = Color(0.0, 0.0, 0.0, 0.92)
    burst.add_child(label)

    _bursts.append(burst)

func _animate_bursts(delta: float) -> void:
    for i in range(_bursts.size() - 1, -1, -1):
        var burst := _bursts[i]
        if burst == null or not is_instance_valid(burst):
            _bursts.remove_at(i)
            continue
        var life := float(burst.get_meta("life", 0.0)) + delta
        var duration := maxf(0.1, float(burst.get_meta("duration", 0.6)))
        var target_radius := float(burst.get_meta("radius", 4.0))
        burst.set_meta("life", life)
        var t := clampf(life / duration, 0.0, 1.0)
        var scale_value := lerpf(0.18, target_radius, 1.0 - pow(1.0 - t, 2.0))
        var wave := burst.get_node_or_null("OndeEnergie") as MeshInstance3D
        if wave != null:
            wave.scale = Vector3(scale_value, 1.0, scale_value)
            wave.rotation.y += delta * 5.0
        var flash := burst.get_node_or_null("FlashPouvoir") as MeshInstance3D
        if flash != null:
            var flash_scale := lerpf(1.0, 0.15, t)
            flash.scale = Vector3.ONE * flash_scale
        if life >= duration:
            burst.queue_free()
            _bursts.remove_at(i)

func _hero_energy_color() -> Color:
    match str(GameState.selected_hero).to_lower():
        "yvane":
            return Color("4da6ff")
        "nelvyn":
            return Color("a46cff")
        _:
            return Color("ff8a3d")

func _energy_material(color: Color, emission_energy: float, alpha: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(color.r, color.g, color.b, clampf(alpha, 0.04, 1.0))
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = emission_energy
    if alpha < 0.99:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.no_depth_test = true
    return material

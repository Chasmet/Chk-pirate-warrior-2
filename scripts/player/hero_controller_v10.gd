class_name HeroControllerV10
extends "res://scripts/player/hero_controller_v3.gd"

const CERBERUS_SWORD_PATH := "res://assets/equipements/armes/glb/epee_trois_cerberes.glb"

var _cerberus_equipped := false

func _ready() -> void:
    super._ready()
    _stabilize_backpack_visual()

func basic_attack() -> void:
    if GameState.selected_hero == "cheikh":
        _equip_cerberus_sword()
    super.basic_attack()

func use_ability(index: int) -> bool:
    if GameState.selected_hero == "cheikh":
        _equip_cerberus_sword()
    return super.use_ability(index)

func _on_hero_changed(hero_id: String) -> void:
    _cerberus_equipped = false
    super._on_hero_changed(hero_id)
    _stabilize_backpack_visual()

func _attach_backpack(backpack_visual: Node3D) -> void:
    # Une ancienne ancre peut rester jusqu'à la fin de la frame après un
    # changement de héros. La masquer immédiatement évite deux sacs superposés.
    for child in get_children():
        if child is Node3D and str(child.name).begins_with("BackpackAnchor"):
            (child as Node3D).visible = false
            child.queue_free()

    super._attach_backpack(backpack_visual)
    _stabilize_backpack_visual()

func _stabilize_backpack_visual() -> void:
    if backpack_node == null or not is_instance_valid(backpack_node):
        return

    var hero_id := str(GameState.selected_hero).to_lower()
    # +Z correspond au dos du contrôleur après l'alignement V3 des modèles.
    # Le sac est volontairement plus bas que les épaules afin de ne jamais
    # traverser la tête ou le visage pendant les rotations de caméra.
    match hero_id:
        "cheikh":
            backpack_node.position = Vector3(0.0, 1.08, 0.38)
            backpack_node.rotation_degrees = Vector3(0.0, 180.0, 0.0)
        "yvane":
            backpack_node.position = Vector3(0.0, 1.04, 0.34)
            backpack_node.rotation_degrees = Vector3.ZERO
        "nelvyn":
            backpack_node.position = Vector3(0.0, 1.03, 0.34)
            backpack_node.rotation_degrees = Vector3.ZERO
        _:
            backpack_node.position = Vector3(0.0, 1.06, 0.34)

    backpack_node.visible = not _mount_pose_active

func _equip_cerberus_sword() -> void:
    if _cerberus_equipped and weapon_node != null and is_instance_valid(weapon_node):
        weapon_node.visible = not _mount_pose_active
        return
    if not ResourceLoader.exists(CERBERUS_SWORD_PATH):
        push_warning("Épée des Trois Cerbères absente : %s" % CERBERUS_SWORD_PATH)
        return

    if weapon_node != null and is_instance_valid(weapon_node):
        var old_parent := weapon_node.get_parent()
        weapon_node.visible = false
        if old_parent is BoneAttachment3D:
            old_parent.queue_free()
        else:
            weapon_node.queue_free()
        weapon_node = null

    var packed = load(CERBERUS_SWORD_PATH)
    if not packed is PackedScene:
        push_warning("Le GLB Cerbères n'est pas importé comme PackedScene.")
        return

    var sword := packed.instantiate() as Node3D
    if sword == null:
        return
    sword.name = "EpeeTroisCerberes"
    sword.set_meta("cerberus_weapon", true)
    weapon_node = sword
    _attach_to_bone_or_fallback(
        weapon_node,
        ["hand.R", "RightHand", "Hand.R", "mixamorig_RightHand", "hand_r"],
        Vector3(0.0, 0.50, 0.0),
        Vector3.ZERO,
        true
    )
    _normalize_weapon_visual()
    weapon_node.visible = not _mount_pose_active
    _cerberus_equipped = true

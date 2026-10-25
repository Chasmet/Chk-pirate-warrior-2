extends SceneTree
## CHK MCP 3: autonomous gameplay smoke test, run on a disposable Godot profile.
## godot --headless --path . --script res://scripts/tests/mcp3_autoplay_audit.gd
## It DOES NOT measure phone GPU performance or replace a visual playtest.

const REPORT_PATH := "user://chk_mcp3_playtest_report.json"
var _checks: Array[Dictionary] = []
var _errors: Array[String] = []
var _started_us := 0

func _initialize() -> void:
    _started_us = Time.get_ticks_usec()
    call_deferred("_run")

func _record(name: String, ok: bool, detail: Variant = "") -> void:
    _checks.append({"name": name, "passed": ok, "detail": str(detail)})
    if not ok:
        _errors.append(name + ": " + str(detail))
        push_error("MCP3 PLAYTEST ECHEC: " + name + ": " + str(detail))
    else:
        print("MCP3 PLAYTEST OK: " + name)

func _run() -> void:
    var state := root.get_node_or_null("GameState")
    _record("GameState charge", state != null)
    if state == null:
        _finish()
        return

    state.call("new_game", "cheikh", "aventure")
    var packed := load("res://scenes/main/main.tscn") as PackedScene
    _record("Scene principale chargee", packed != null)
    if packed == null:
        _finish()
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    for _i in range(8):
        await process_frame

    # MainMenu suspends gameplay; this runner deliberately dismisses it.
    var menu := root.find_child("MainMenu", true, false)
    if menu != null:
        menu.queue_free()
    await process_frame
    paused = false

    var player := get_first_node_in_group("player") as CharacterBody3D
    _record("Hero instancie", player != null)
    _record("Camera 3D disponible", root.get_viewport().get_camera_3d() != null)
    _record("Interface mobile presente", root.find_child("MobileInputOverlay", true, false) != null)
    _record("HUD present", get_first_node_in_group("hud") != null)
    _record("Monde instancie", get_first_node_in_group("world_director") != null)

    if player == null:
        scene.queue_free()
        await process_frame
        _finish()
        return

    # Wait for the hero to reach the first island before probing collisions.
    var grounded := false
    for _frame in range(300):
        await physics_frame
        if not is_instance_valid(player):
            break
        if player.is_on_floor():
            grounded = true
            break
    _record("Atterrissage sur collision", grounded, "timeout de 300 frames")

    if is_instance_valid(player):
        var initial: Vector3 = player.global_position
        if player.has_method("set_virtual_move"):
            player.call("set_virtual_move", Vector2(0.0, -1.0))
            for _frame in range(72):
                await physics_frame
            player.call("set_virtual_move", Vector2.ZERO)
            for _frame in range(5):
                await physics_frame
            var moved: Vector3 = player.global_position - initial
            var planar_distance := Vector2(moved.x, moved.z).length()
            _record("Deplacement joystick virtuel", planar_distance > 0.45, "distance horizontale %.2f m" % planar_distance)
        else:
            _record("Deplacement joystick virtuel", false, "set_virtual_move introuvable")

        if InputMap.has_action("jump") and player.is_on_floor():
            var before_y := player.global_position.y
            Input.action_press("jump")
            for _frame in range(3):
                await physics_frame
            Input.action_release("jump")
            var airborne := player.global_position.y > before_y + 0.02 or player.velocity.y > 0.5
            _record("Saut", airborne, "vitesse verticale %.2f" % player.velocity.y)
        else:
            _record("Saut", false, "action absente ou personnage non au sol")

        if player.has_method("basic_attack"):
            player.call("basic_attack")
            _record("Attaque declenchable", true)
        else:
            _record("Attaque declenchable", false, "basic_attack absent")

        if player.has_method("use_ability"):
            var energy_before := float(player.get("energy"))
            var ability_ok: Variant = player.call("use_ability", 0)
            var energy_after := float(player.get("energy"))
            _record("Pouvoir 1 activable", ability_ok == true, "energie %.1f -> %.1f" % [energy_before, energy_after])
        else:
            _record("Pouvoir 1 activable", false, "use_ability absent")

        _record("Position joueur valide", player.global_position.is_finite(), player.global_position)
        _record("Vie du personnage positive", float(player.get("health")) > 0.0)

    if is_instance_valid(scene):
        scene.queue_free()
    await process_frame
    paused = false
    _finish()

func _finish() -> void:
    var elapsed_ms := float(Time.get_ticks_usec() - _started_us) / 1000.0
    var report := {
        "schema": 1,
        "suite": "chk_mcp3_autoplay",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "platform": OS.get_name(),
        "mode": "headless_smoke_test",
        "elapsed_ms": roundf(elapsed_ms),
        "passed": _errors.is_empty(),
        "checks": _checks,
        "errors": _errors,
        "notice": "Ne mesure ni les FPS reels Android ni les performances GPU sur telephone."
    }
    var payload := JSON.stringify(report)
    print("CHK_MCP3_PLAYTEST_JSON=" + payload)
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  "))
        file.close()
        print("CHK_MCP3_PLAYTEST_REPORT=" + ProjectSettings.globalize_path(REPORT_PATH))
    else:
        push_warning("Impossible d'ecrire le rapport local MCP 3")
    if _errors.is_empty():
        print("CHK_MCP3_AUTOPLAY_OK")
        quit(0)
    else:
        print("CHK_MCP3_AUTOPLAY_FAILED count=", _errors.size())
        quit(12)

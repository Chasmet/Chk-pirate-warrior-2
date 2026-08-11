extends SceneTree

func _initialize() -> void:
    var failures: Array[String] = []
    if WorldCatalog.island_count() != 11:
        failures.append("Le catalogue doit contenir exactement 11 royaumes.")
    if WorldCatalog.SEA_GAPS.size() != 10:
        failures.append("Le catalogue doit contenir exactement 10 distances maritimes.")

    for path in WorldCatalog.required_asset_paths():
        var absolute := ProjectSettings.globalize_path(path)
        if not FileAccess.file_exists(absolute):
            failures.append("Asset obligatoire absent: %s" % path)

    var roots := [
        "res://assets/audio",
        "res://assets/bateaux_glb",
        "res://assets/branding",
        "res://assets/cinematiques",
        "res://assets/decors_glb",
        "res://assets/effets_visuels",
        "res://assets/ennemis_et_boss",
        "res://assets/equipages_libres",
        "res://assets/gameplay",
        "res://assets/interface",
        "res://assets/objets_et_recompenses",
        "res://assets/pnj_et_quetes",
        "res://assets/royaumes",
        "res://assets/vrac"
    ]
    for path in roots:
        if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
            failures.append("Dossier d'assets absent: %s" % path)

    var glb_count := _count_extension("res://assets", ".glb")
    var audio_count := _count_extension("res://assets/audio", ".ogg")
    var image_count := _count_images("res://assets")
    print("AUDIT: %d GLB, %d OGG, %d images" % [glb_count, audio_count, image_count])
    if glb_count < 35:
        failures.append("Trop peu de GLB détectés: %d" % glb_count)
    if audio_count < 20:
        failures.append("Trop peu d'audios OGG détectés: %d" % audio_count)
    if image_count < 20:
        failures.append("Trop peu d'images détectées: %d" % image_count)

    if failures.is_empty():
        print("AUDIT COMPLET OK: 11 royaumes et arborescence d'assets validés.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(2)

func _count_images(root: String) -> int:
    return _count_extension(root, ".png") + _count_extension(root, ".jpg") + _count_extension(root, ".jpeg") + _count_extension(root, ".webp")

func _count_extension(root: String, extension: String) -> int:
    var directory := DirAccess.open(root)
    if directory == null:
        return 0
    var count := 0
    directory.list_dir_begin()
    var name := directory.get_next()
    while name != "":
        if name != "." and name != "..":
            var path := root.path_join(name)
            if directory.current_is_dir():
                count += _count_extension(path, extension)
            elif name.to_lower().ends_with(extension):
                count += 1
        name = directory.get_next()
    directory.list_dir_end()
    return count

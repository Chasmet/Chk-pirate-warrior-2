class_name CHKSaveFiles
extends RefCounted

# Keep existing filenames and JSON schema. Android replacement retains user://.
static func read_json(path: String) -> Dictionary:
    for candidate in [path, path + ".bak"]:
        if not FileAccess.file_exists(candidate):
            continue
        var file := FileAccess.open(candidate, FileAccess.READ)
        if file == null:
            continue
        var data = JSON.parse_string(file.get_as_text())
        file.close()
        if data is Dictionary and not data.is_empty():
            return data
    return {}

static func write_json(path: String, data: Dictionary) -> Error:
    var temp := path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(data, "  "))
    file.flush()
    var status := file.get_error()
    file.close()
    if status != OK:
        return status
    if FileAccess.file_exists(path):
        # Never replace a valid backup with an already damaged primary file.
        var previous := FileAccess.open(path, FileAccess.READ)
        if previous != null:
            var valid = JSON.parse_string(previous.get_as_text())
            previous.close()
            if valid is Dictionary and not valid.is_empty():
                status = DirAccess.copy_absolute(path, path + ".bak")
                if status != OK:
                    return status
    return DirAccess.rename_absolute(temp, path)

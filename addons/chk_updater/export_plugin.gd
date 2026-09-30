@tool
extends EditorPlugin

var _exporter: EditorExportPlugin

func _enter_tree() -> void:
    _exporter = CHKAndroidExport.new()
    add_export_plugin(_exporter)

func _exit_tree() -> void:
    remove_export_plugin(_exporter)

class CHKAndroidExport extends EditorExportPlugin:
    func _get_name() -> String:
        return "CHKUpdater"

    func _supports_platform(platform: EditorExportPlatform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
        return PackedStringArray(["chk_updater/CHKUpdater.aar"])

    func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
        return PackedStringArray(["androidx.core:core:1.12.0"])

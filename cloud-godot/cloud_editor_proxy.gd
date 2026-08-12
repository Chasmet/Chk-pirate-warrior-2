@tool
extends EditorPlugin

# Lightweight EditorPlugin-shaped object for the upstream command router.
# It is intentionally not registered as a normal editor plugin: the cloud
# bootstrap owns it directly, avoiding docks/debug UI and recovery-mode issues.
var activity_log: Node = null
var debugger_bridge: Variant = null

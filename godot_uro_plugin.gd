tool
extends EditorPlugin

const uro_logo_const = preload("uro_logo.png")
var editor_interface: EditorInterface = null
var button: Button = null


func _init() -> void:
	print("Initialising GodotUro plugin")


func _notification(p_notification: int):
	match p_notification:
		NOTIFICATION_PREDELETE:
			print("Destroying GodotUro plugin")


func get_name() -> String:
	return "GodotUro"


func _enter_tree() -> void:
	editor_interface = get_editor_interface()

	add_autoload_singleton("GodotUro", "res://addons/godot_uro/godot_uro.gd")


func _exit_tree() -> void:
	remove_autoload_singleton("GodotUro")

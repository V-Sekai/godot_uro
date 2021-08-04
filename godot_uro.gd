@tool
extends Node

const godot_uro_helper_const = preload("godot_uro_helper.gd")

@export var renewal_token: String:
	get:
		return GodotUroData.get("renewal_token")
	set(t):
		GodotUroData.set("renewal_token", t)
@export var access_token: String:
	get:
		return GodotUroData.get("access_token")
	set(t):
		GodotUroData.set("access_token", t)
var cfg: ConfigFile = null

var use_localhost: bool = true
var uro_host: String = godot_uro_helper_const.DEFAULT_URO_HOST
var uro_port: int = godot_uro_helper_const.DEFAULT_URO_PORT
var uro_using_ssl: bool = true

const EDITOR_CONFIG_FILE_PATH = "user://uro_editor.ini"
const GAME_CONFIG_FILE_PATH = "user://uro.ini"
const godot_uro_api_const = preload("godot_uro_api.gd")
const godot_uro_request_const = preload("godot_uro_requester.gd")

var godot_uro_api: RefCounted = null

func get_uro_config_path() -> String:
	if Engine.is_editor_hint():
		return EDITOR_CONFIG_FILE_PATH
	else:
		return GAME_CONFIG_FILE_PATH

func get_base_url() -> String:
	if use_localhost:
		# "http://localhost:" does not work
		return "http://127.0.0.1:" + str(uro_port)
	else:
		return uro_host

func get_host_and_port() -> Dictionary:
	var host: String = ""
	var port: int = 0

	if use_localhost:
		host = godot_uro_helper_const.LOCALHOST_HOST
		port = godot_uro_helper_const.LOCALHOST_PORT
	else:
		host = uro_host
		port = uro_port

	return {"host": host, "port": port}


func using_ssl() -> bool:
	return uro_using_ssl
	
func create_requester(): # godot_uro_request_const
	var host_and_port: Dictionary = get_host_and_port()

	var new_requester = godot_uro_request_const.new(
		host_and_port.host, host_and_port.port, using_ssl()
	)
	
	return new_requester

func setup_configuration() -> void:
	if ! ProjectSettings.has_setting("services/uro/use_localhost"):
		ProjectSettings.set_setting("services/uro/use_localhost", use_localhost)
	else:
		use_localhost = ProjectSettings.get_setting("services/uro/use_localhost")

	if ! ProjectSettings.has_setting("services/uro/host"):
		ProjectSettings.set_setting("services/uro/host", uro_host)
	else:
		uro_host = ProjectSettings.get_setting("services/uro/host")

	if ! ProjectSettings.has_setting("services/uro/port"):
		ProjectSettings.set_setting("services/uro/port", uro_port)
	else:
		uro_port = ProjectSettings.get_setting("services/uro/port")

	if ! ProjectSettings.has_setting("services/uro/use_ssl"):
		ProjectSettings.set_setting("services/uro/use_ssl", uro_using_ssl)
	else:
		uro_using_ssl = ProjectSettings.get_setting("services/uro/use_ssl")

func _init():
	cfg = ConfigFile.new()
	if cfg.load(get_uro_config_path()) == OK:
		setup_configuration()
	else:
		printerr("GodotUro: can't load configuration file")
		
	if godot_uro_api == null:
		godot_uro_api = godot_uro_api_const.new(self)

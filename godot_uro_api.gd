tool
extends Reference

const godot_uro_requester_const = preload("godot_uro_requester.gd")
const godot_uro_helper_const = preload("godot_uro_helper.gd")

const USER_NAME = "user"
const SHARD_NAME = "shard"
const AVATAR_NAME = "avatar"
const MAP_NAME = "map"

var requester = null

func cancel_async() -> void:
	yield(requester.cancel(), "completed")


static func bool_to_string(p_bool: bool) -> String:
	if p_bool:
		return "true"
	else:
		return "false"

static func populate_query(p_query_name: String, p_query_dictionary: Dictionary) -> Dictionary:
	var query: Dictionary = {}

	for key in p_query_dictionary.keys():
		query["%s[%s]" % [p_query_name, key]] = p_query_dictionary[key]

	return query

func get_profile_async() -> Dictionary:
	var query: Dictionary = {}
	
	requester.call(
		"request",
		godot_uro_helper_const.get_api_path()\
		+ godot_uro_helper_const.PROFILE_PATH,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)


func renew_session_async():
	var query: Dictionary = {}
	
	requester.call(
		"request",
		godot_uro_helper_const.get_api_path()\
		+ godot_uro_helper_const.SESSION_PATH + godot_uro_helper_const.RENEW_PATH,
		query,
		godot_uro_requester_const.TokenType.RENEWAL_TOKEN,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)

func sign_in_async(p_username_or_email: String, p_password: String):
	var query: Dictionary = {
		"user[username_or_email]": p_username_or_email,
		"user[password]": p_password,
	}
	
	var new_requester = GodotUro.create_requester()

	new_requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.SESSION_PATH,
		query,
		godot_uro_requester_const.TokenType.NO_TOKEN,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(new_requester, "completed")
	requester.term()
	
	requester = new_requester

	return _handle_result(result)
	
func sign_out_async():
	var query: Dictionary = {}

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.SESSION_PATH,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_DELETE, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
func register_async(p_username: String, p_email: String, p_password: String, p_password_confirmation: String, p_email_notifications: bool):
	var query: Dictionary = {
		"user[username]": p_username,
		"user[email]": p_email,
		"user[password]": p_password,
		"user[password_confirmation]": p_password_confirmation,
		"user[email_notifications]": bool_to_string(p_email_notifications)
	}

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.REGISTRATION_PATH,
		query,
		godot_uro_requester_const.TokenType.NO_TOKEN,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)

func create_identity_proof_for_async(p_id: String) -> String:
	var query: Dictionary = {
		"identity_proof[user_to]": p_id,
	}

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.IDENTITY_PROOFS_PATH,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
func get_identity_proof_async(p_id: String) -> String:
	var query: Dictionary = {
	}

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.IDENTITY_PROOFS_PATH + "/" + p_id,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)

func create_shard_async(p_query: Dictionary):
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, p_query)

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.SHARDS_PATH,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)
	var result = yield(requester, "completed")

	return _handle_result(result)


func delete_shard_async(p_id: String, p_query: Dictionary):
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, p_query)

	requester.call(
		"request",
		(
			"%s%s/%s"
			% [godot_uro_helper_const.get_api_path(), godot_uro_helper_const.SHARDS_PATH, p_id]
		),
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_DELETE, "encoding": "form"}
	)
	var result = yield(requester, "completed")

	return _handle_result(result)


func update_shard_async(p_id: String, p_query: Dictionary):
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, p_query)

	requester.call(
		"request",
		(
			"%s%s/%s"
			% [godot_uro_helper_const.get_api_path(), godot_uro_helper_const.SHARDS_PATH, p_id]
		),
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_PUT, "encoding": "form"}
	)
	var result = yield(requester, "completed")

	return _handle_result(result)


func get_shards_async():
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, {})

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.SHARDS_PATH,
		query,
		godot_uro_requester_const.TokenType.NO_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)
	var result = yield(requester, "completed")

	return godot_uro_helper_const.process_shards_json(_handle_result(result))

func get_avatar_async(p_id: String) -> String:
	var query: Dictionary = {
	}

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.AVATARS_PATH + "/" + p_id,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
func get_map_async(p_id: String) -> String:
	var query: Dictionary = {
	}

	requester.call(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.MAPS_PATH + "/" + p_id,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
"""
Dashboard Avatar
"""

func dashboard_get_avatars_async() -> String:
	var query: Dictionary = {}
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.AVATARS_PATH
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)

func dashboard_create_avatar_async(p_query: Dictionary) -> String:
	var query: Dictionary = godot_uro_helper_const.populate_query(AVATAR_NAME, p_query)
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.AVATARS_PATH
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_POST, "encoding": "multipart"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
func dashboard_update_avatar_async(p_id: String, p_query: Dictionary) -> String:
	var query: Dictionary = godot_uro_helper_const.populate_query(AVATAR_NAME, p_query)
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.AVATARS_PATH +\
		"/" + str(p_id)
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_PUT, "encoding": "multipart"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
func dashboard_get_avatar_async(p_id: String) -> String:
	var query: Dictionary = {}
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.AVATARS_PATH +\
		"/" + str(p_id)
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)

"""
Dashboard Map
"""

func dashboard_get_maps_async() -> String:
	var query: Dictionary = {}
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.MAPS_PATH
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)

func dashboard_create_map_async(p_query: Dictionary) -> String:
	var query: Dictionary = godot_uro_helper_const.populate_query(MAP_NAME, p_query)
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.MAPS_PATH
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_POST, "encoding": "multipart"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
func dashboard_update_map_async(p_id: String, p_query: Dictionary) -> String:
	var query: Dictionary = godot_uro_helper_const.populate_query(MAP_NAME, p_query)
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.MAPS_PATH +\
		"/" + str(p_id)
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_PUT, "encoding": "multipart"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)
	
func dashboard_get_map_async(p_id: String) -> String:
	var query: Dictionary = {}
	
	var path: String = godot_uro_helper_const.get_api_path() +\
		godot_uro_helper_const.DASHBOARD_PATH +\
		godot_uro_helper_const.MAPS_PATH +\
		"/" + str(p_id)
	
	requester.call(
		"request",
		path,
		query,
		godot_uro_requester_const.TokenType.ACCESS_TOKEN,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(requester, "completed")

	return _handle_result(result)

static func _handle_result(result) -> Dictionary:
	var result_dict: Dictionary = {
		"code": -1, "output": null
	}

	if result:
		result_dict["code"] = result["code"]
		result_dict["output"] = result["data"]

	return result_dict
	
func _init(p_godot_uro):
	requester = p_godot_uro.create_requester()

extends Reference

const godot_uro_request_const = preload("godot_uro_requestor.gd")
const godot_uro_helper_const = preload("godot_uro_helper.gd")

const USER_NAME = "user"
const SHARD_NAME = "shard"

#func cancel_async() -> void:
#	yield(requestor.cancel(), "completed")

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


func renew_session_async(p_requester : godot_uro_request_const, p_renew_token: String):
	var query: Dictionary = {}
	
	p_requester.call_deferred(
		"request",
		godot_uro_helper_const.get_api_path()\
		+ godot_uro_helper_const.SESSION_PATH + godot_uro_helper_const.RENEW_PATH,
		query,
		p_renew_token,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict

func sign_in_async(p_requester : godot_uro_request_const, p_username_or_email: String, p_password: String):
	var query: Dictionary = {
		"user[username_or_email]": p_username_or_email,
		"user[password]": p_password,
	}

	p_requester.call_deferred(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.SESSION_PATH,
		query,
		"",
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict
	
func register_async(p_requester : godot_uro_request_const, p_username: String, p_email: String, p_password: String, p_password_confirmation: String, p_email_notifications: bool):
	var query: Dictionary = {
		"user[username]": p_username,
		"user[email]": p_email,
		"user[password]": p_password,
		"user[password_confirmation]": p_password_confirmation,
		"user[email_notifications]": bool_to_string(p_email_notifications)
	}

	p_requester.call_deferred(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.REGISTRATION_PATH,
		query,
		"",
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict

func create_identity_proof_for_async(p_requester : godot_uro_request_const, p_id: String, p_authorization_token: String) -> String:
	var query: Dictionary = {
		"identity_proof[user_to]": p_id,
	}

	p_requester.call_deferred(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.IDENTITY_PROOFS_PATH,
		query,
		p_authorization_token,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)

	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict
	
func get_identity_proof_async(p_requester : godot_uro_request_const, p_id: String, p_authorization_token: String) -> String:
	var query: Dictionary = {
	}

	p_requester.call_deferred(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.IDENTITY_PROOFS_PATH + "/" + p_id,
		query,
		p_authorization_token,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)

	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict

func create_shard_async(p_requester : godot_uro_request_const, p_authorization_token : String, p_query: Dictionary):
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, p_query)

	p_requester.call_deferred(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.SHARDS_PATH,
		query,
		p_authorization_token,
		{"method": HTTPClient.METHOD_POST, "encoding": "form"}
	)
	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict


func delete_shard_async(p_requester : godot_uro_request_const, p_id: String, p_authorization_token: String, p_query: Dictionary):
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, p_query)

	p_requester.call_deferred(
		"request",
		(
			"%s%s/%s"
			% [godot_uro_helper_const.get_api_path(), godot_uro_helper_const.SHARDS_PATH, p_id]
		),
		query,
		p_authorization_token,
		{"method": HTTPClient.METHOD_DELETE, "encoding": "form"}
	)
	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict


func update_shard_async(p_requester : godot_uro_request_const, p_id: String, p_authorization_token: String, p_query: Dictionary):
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, p_query)

	p_requester.call_deferred(
		"request",
		(
			"%s%s/%s"
			% [godot_uro_helper_const.get_api_path(), godot_uro_helper_const.SHARDS_PATH, p_id]
		),
		query,
		p_authorization_token,
		{"method": HTTPClient.METHOD_PUT, "encoding": "form"}
	)
	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)

	return result_dict


func get_shards(p_requester : godot_uro_request_const, p_authorization_token: String):
	var query: Dictionary = godot_uro_helper_const.populate_query(SHARD_NAME, {})

	p_requester.call_deferred(
		"request",
		godot_uro_helper_const.get_api_path() + godot_uro_helper_const.SHARDS_PATH,
		query,
		p_authorization_token,
		{"method": HTTPClient.METHOD_GET, "encoding": "form"}
	)
	var result = yield(p_requester, "completed")
	p_requester.term()

	var result_dict: Dictionary = _handle_result(result)
	result_dict = godot_uro_helper_const.process_shards_json(result_dict)

	return result_dict


static func _handle_result(result) -> Dictionary:
	var result_dict: Dictionary = {
		"code": -1, "output": null
	}

	if result:
		result_dict["code"] = result["code"]
		result_dict["output"] = result["data"]

	return result_dict

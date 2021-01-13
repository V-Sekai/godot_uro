extends Reference

enum UroUserContentType {
	UNKNOWN,
	AVATAR,
	MAP,
	PROP
}

const LOCALHOST_HOST = "127.0.0.1"
const LOCALHOST_PORT = 4000

const DEFAULT_URO_HOST = LOCALHOST_HOST
const DEFAULT_URO_PORT = LOCALHOST_PORT

const API_PATH = "/api"
const API_VERSION = "/v1"

const SHOW_PATH = "/show"
const NEW_PATH = "/new"
const RENEW_PATH = "/renew"

const PROFILE_PATH = "/profile"
const SESSION_PATH = "/session"
const REGISTRATION_PATH = "/registration"
const IDENTITY_PROOFS_PATH = "/identity_proofs"
const AVATARS_PATH = "/avatars"
const MAPS_PATH = "/maps"
const SHARDS_PATH = "/shards"

const DEFAULT_ACCOUNT_ID = "UNKNOWN_ID"
const DEFAULT_ACCOUNT_USERNAME = "UNKNOWN_USERNAME"
const DEFAULT_ACCOUNT_DISPLAY_NAME = "UNKNOWN_DISPLAY_NAME"

const UNTITLED_SHARD = "UNTITLED_SHARD"
const UNKNOWN_MAP = "UNKNOWN_MAP"

static func populate_query(p_query_name: String, p_query_dictionary: Dictionary) -> Dictionary:
	var query: Dictionary = {}

	for key in p_query_dictionary.keys():
		query["%s[%s]" % [p_query_name, key]] = p_query_dictionary[key]

	return query

static func get_api_path() -> String:
	return API_PATH + API_VERSION

static func get_value_of_type(p_data: Dictionary, p_key: String, p_type: int, p_default_value):
	var value = p_data.get(p_key, p_default_value)
	if typeof(value) == p_type:
		return value
	else:
		return p_default_value

static func process_session_json(p_input: Dictionary) -> Dictionary:
	var http_response_code: int = p_input["code"]
	if http_response_code != -1:
		if http_response_code == HTTPClient.RESPONSE_OK:
			var data = p_input["output"].get("data")
			if data is Dictionary:
				var renewel_token: String = get_value_of_type(data, "renewal_token", TYPE_STRING, GodotUro.renewal_token)
				var access_token: String = get_value_of_type(data, "access_token", TYPE_STRING, GodotUro.access_token)
				
				var user: Dictionary = get_value_of_type(data, "user", TYPE_DICTIONARY, {})
				
				var user_id: String = get_value_of_type(user, "id", TYPE_STRING, DEFAULT_ACCOUNT_ID)
				var user_username: String = get_value_of_type(user, "username", TYPE_STRING, DEFAULT_ACCOUNT_USERNAME)
				var user_display_name: String = get_value_of_type(user, "display_name", TYPE_STRING, DEFAULT_ACCOUNT_DISPLAY_NAME)
				
				return {"code":http_response_code, "message": "Success!",\
				"renewel_token":renewel_token,\
				"access_token":access_token,\
				"user_id":user_id,\
				"user_username":user_username,\
				"user_display_name":user_display_name}
		else:
			var output = p_input.get("output")
			if output:
				var error = output.get("error")
				if error is Dictionary:
					var message = error.get("message")
					if message is String:
						return {"code":http_response_code, "message": message}
			
			return {"code":http_response_code, "message":"error_code: %s" % http_response_code}
			
	return {"code":http_response_code, "message":""}

static func process_shards_json(p_input: Dictionary) -> Dictionary:
	var result_dict: Dictionary = {}
	var new_shards: Array = []

	var data = p_input["output"].get("data")
	if data is Dictionary:
		var shards = data.get("shards")
		if shards is Array:
			for shard in shards:
				if shard is Dictionary:
					var new_shard: Dictionary
					new_shard["user"] = get_value_of_type(shard, "user", TYPE_STRING, "")
					new_shard["address"] = get_value_of_type(shard, "address", TYPE_STRING, "")
					new_shard["port"] = get_value_of_type(shard, "port", TYPE_REAL, -1)
					new_shard["map"] = get_value_of_type(shard, "map", TYPE_STRING, UNKNOWN_MAP)
					new_shard["name"] = get_value_of_type(shard, "name", TYPE_STRING, UNTITLED_SHARD)
					new_shard["current_users"] = get_value_of_type(shard, "current_users", TYPE_REAL, 0)
					new_shard["max_users"] = get_value_of_type(shard, "max_users", TYPE_REAL, 0)
					
					new_shards.push_back(new_shard)
					

	result_dict["code"] = p_input["code"]
	result_dict["output"] = {"data":{"shards": new_shards}}
	return result_dict

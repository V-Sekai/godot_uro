tool
extends Reference

const godot_uro_helper_const = preload("godot_uro_helper.gd")
const random_const = preload("res://addons/gdutil/random.gd")

const BOUNDARY_STRING_PREFIX = "UroFileUpload"
const BOUNDARY_STRING_LENGTH = 32
const YIELD_PERIOD_MS = 50

class Result:
	var requester_code: int = -1
	var generic_code: int = -1
	var response_code: int = -1
	var data: Dictionary = {}

	func _init(p_requester_code: int, p_generic_code: int, p_response_code: int, p_data = {}) -> void:
		self.requester_code = p_requester_code
		self.generic_code = p_generic_code
		self.response_code = p_response_code
		self.data = p_data


const DEFAULT_OPTIONS = {
	"method": HTTPClient.METHOD_GET,
	"encoding": "query",
	"token": null,
	"download_to": null,
}

var http: HTTPClient = HTTPClient.new()
var busy: bool = false
var cancelled: bool = false
var terminated: bool = false

var hostname: String = ""
var port: int = -1
var use_ssl: bool = true

##
var has_enhanced_qs_from_dict: bool = false
##


func _init(p_hostname: String, p_port: int = -1, p_use_ssl: bool = true) -> void:
	hostname = p_hostname
	port = p_port
	use_ssl = p_use_ssl

	has_enhanced_qs_from_dict = http.query_string_from_dict({"a": null}) == "a"
	
	
func cancel():
	if busy:
		print("uro request cancelled!")
		cancelled = true
	else:
		call_deferred("emit_signal", "completed", null)
	yield(self, "completed")
	
	
func term() -> void:
	terminated = true
	http.close()
	
enum TokenType {
	NO_TOKEN,
	RENEWAL_TOKEN,
	ACCESS_TOKEN
}

static func get_status_error_response(p_status: int) -> Result:
	match p_status:
		HTTPClient.STATUS_CANT_CONNECT:
			return Result.new(godot_uro_helper_const.RequesterCode.CANT_CONNECT, FAILED, -1)
		HTTPClient.STATUS_CANT_RESOLVE:
			return Result.new(godot_uro_helper_const.RequesterCode.CANT_RESOLVE, FAILED, -1)
		HTTPClient.STATUS_SSL_HANDSHAKE_ERROR:
			return Result.new(godot_uro_helper_const.RequesterCode.SSL_HANDSHAKE_ERROR, FAILED, -1)
		HTTPClient.STATUS_DISCONNECTED:
			return Result.new(godot_uro_helper_const.RequesterCode.DISCONNECTED, FAILED, -1)
		HTTPClient.STATUS_CONNECTION_ERROR:
			return Result.new(godot_uro_helper_const.RequesterCode.CONNECTION_ERROR, FAILED, -1)
		_:
			return Result.new(godot_uro_helper_const.RequesterCode.UNKNOWN_STATUS_ERROR, FAILED, -1)
	
func request(p_path: String, p_payload: Dictionary, p_use_token: int, p_options: Dictionary = DEFAULT_OPTIONS) -> Result:
	while busy and ! terminated:
		yield(Engine.get_main_loop(), "idle_frame")
		if terminated:
			return
			
	var status: int = HTTPClient.STATUS_DISCONNECTED
	busy = true
	
	if cancelled:
		cancelled = false
		busy = false
		return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
		
	var reconnect_tries: int = 3
	while reconnect_tries:
		http.poll()
		if http.get_status() != HTTPClient.STATUS_CONNECTED:
			http.connect_to_host(hostname, port, use_ssl, false)  # verify_host = false
			while true:
				yield(Engine.get_main_loop(), "idle_frame")
				if terminated:
					return
				http.poll()
				status = http.get_status()
				
				if cancelled:
					cancelled = false
					busy = false
					return null
					
				if (
					status
					in [
						HTTPClient.STATUS_CANT_CONNECT,
						HTTPClient.STATUS_CANT_RESOLVE,
						HTTPClient.STATUS_SSL_HANDSHAKE_ERROR,
					]
				):
					busy = false
					return get_status_error_response(status)
					
				if status == HTTPClient.STATUS_CONNECTED:
					break
					
		if cancelled:
			cancelled = false
			busy = false
			return null
			
		var uri: String = p_path
		var encoded_payload: PoolByteArray = PoolByteArray()
		var headers: Array = []
		
		if p_use_token != TokenType.NO_TOKEN:
			match p_use_token:
				TokenType.RENEWAL_TOKEN:
					headers.push_back("Authorization: %s" % GodotUro.renewal_token)
				TokenType.ACCESS_TOKEN:
					headers.push_back("Authorization: %s" % GodotUro.access_token)
			
		if p_payload:
			var encoding: String = _get_option(p_options, "encoding")
			match encoding:
				"query":
					uri += "?%s" % _dict_to_query_string(p_payload)
				"json":
					headers.append("Content-Type: application/json")
					var payload_string: String = to_json(p_payload)
					encoded_payload = payload_string.to_utf8()
				"form":
					headers.append("Content-Type: application/x-www-form-urlencoded")
					var payload_string: String = _dict_to_query_string(p_payload)
					encoded_payload = payload_string.to_utf8()
				"multipart":
					var boundary_string: String = BOUNDARY_STRING_PREFIX + random_const.generate_unique_id(BOUNDARY_STRING_LENGTH)
					headers.append("Content-Type: multipart/form-data; boundary=%s" % boundary_string)
					encoded_payload = _compose_multipart_body(p_payload, boundary_string)
				_:
					printerr("Unknown encoding type!")
					break
				
		var token = _get_option(p_options, "token")
		if token and token is String:
			headers.append("Authorization: Bearer %s" % token)
			
		http.request_raw(_get_option(p_options, "method"), uri, headers, encoded_payload)
		http.poll()
		status = http.get_status()
		if (
			status
			in [
				HTTPClient.STATUS_CONNECTED,
				HTTPClient.STATUS_BODY,
				HTTPClient.STATUS_REQUESTING,
			]
		):
			break
			
		reconnect_tries -= 1
		http.close()
		
		if reconnect_tries == 0:
			pass
			
	if cancelled:
		cancelled = false
		busy = false
		return null
		
	while true:
		yield(Engine.get_main_loop(), "idle_frame")
		if terminated:
			return
		if cancelled:
			http.close()
			cancelled = false
			busy = false
			return null
			
		http.poll()
		status = http.get_status()
		if (
			status
			in [
				HTTPClient.STATUS_DISCONNECTED,
				HTTPClient.STATUS_CONNECTION_ERROR,
			]
		):
			busy = false
			return get_status_error_response(status)
			
		if (
			status
			in [
				HTTPClient.STATUS_CONNECTED,
				HTTPClient.STATUS_BODY,
			]
		):
			break
			
	var response_code: int = http.get_response_code()
	var response_headers: Dictionary = http.get_response_headers_as_dictionary()
	
	var response_body
	
	var file
	var bytes
	var total_bytes
	var out_path = _get_option(p_options, "download_to")
	
	if out_path:
		bytes = 0
		if response_headers.has("Content-Length"):
			total_bytes = int(response_headers["Content-Length"])
		else:
			total_bytes = -1
			
		file = File.new()
		var err: int = file.open(out_path, File.WRITE)
		if err != OK:
			busy = false
			return Result.new(godot_uro_helper_const.RequesterCode.FILE_ERROR, err, -1)
			
	var last_yield = OS.get_ticks_msec()
	
	while status == HTTPClient.STATUS_BODY:
		var chunk = http.read_response_body_chunk()
		
		if file:
			file.store_buffer(chunk)
			bytes += chunk.size()
			emit_signal("download_progressed", bytes, total_bytes)
		else:
			response_body = response_body if response_body else ""
			response_body += chunk.get_string_from_utf8()
			
		var time = OS.get_ticks_msec()
		if time - last_yield > YIELD_PERIOD_MS:
			yield(Engine.get_main_loop(), "idle_frame")
			last_yield = time
			if terminated:
				if file:
					file.close()
				return
			if cancelled:
				http.close()
				if file:
					file.close()
				cancelled = false
				busy = false
				return null
				
		http.poll()
		status = http.get_status()
		if (
			status in [
				HTTPClient.STATUS_DISCONNECTED,
				HTTPClient.STATUS_CONNECTION_ERROR
				]
			and ! terminated
			and ! cancelled
		):
			if file:
				file.close()
			busy = false
			return get_status_error_response(status)
			
	yield(Engine.get_main_loop(), "idle_frame")
	if terminated:
		if file:
			file.close()
		return
	if cancelled:
		http.close()
		if file:
			file.close()
		cancelled = false
		busy = false
		return null
		
	busy = false
	
	if file:
		file.close()
		
	var data = null
	if file:
		data = bytes
	else:
		if response_body:
			var json_validation_result: String = validate_json(response_body)
			if json_validation_result == "":
				var json_parse_result: JSONParseResult = JSON.parse(response_body)
				if json_parse_result.error == OK:
					data = json_parse_result.result
			else:
				printerr("JSON validation result: %s" % json_validation_result)
				
	if response_code == HTTPClient.RESPONSE_OK:
		return Result.new(godot_uro_helper_const.RequesterCode.OK, OK, response_code, data)
	else:
		return Result.new(godot_uro_helper_const.RequesterCode.HTTP_RESPONSE_NOT_OK, FAILED, response_code, data)
	
	
func _get_option(options, key):
	return options[key] if options.has(key) else DEFAULT_OPTIONS[key]
	
static func _compose_multipart_body(p_dictionary: Dictionary, p_boundary_string: String) -> PoolByteArray:
	var buffer: PoolByteArray = PoolByteArray()
	for key in p_dictionary.keys():
		buffer.append_array(("\r\n--" + p_boundary_string + "\r\n").to_ascii())
		var value = p_dictionary[key]
		if value is String:
			var disposition: PoolByteArray = ("Content-Disposition: form-data; name=\"%s\"\r\n\r\n" % key).to_ascii()
			var body: PoolByteArray = value.to_utf8()
			
			buffer.append_array(disposition)
			buffer.append_array(body)
		elif value is Dictionary:
			var content_type: String = value.get("content_type")
			var filename: String = value.get("filename")
			var data: PoolByteArray = value.get("data")
			
			var disposition = ("Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [key, filename, content_type]).to_ascii()
			var body: PoolByteArray = data

			buffer.append_array(disposition)
			buffer.append_array(body)
		
	buffer.append_array(("\r\n--" + p_boundary_string + "--\r\n").to_ascii())

	return buffer
	
func _dict_to_query_string(p_dictionary: Dictionary) -> String:
	if has_enhanced_qs_from_dict:
		return http.query_string_from_dict(p_dictionary)
		
	# For 3.0
	var qs = ""
	for key in p_dictionary:
		var value = p_dictionary[key]
		if typeof(value) == TYPE_ARRAY:
			for v in value:
				qs += "&%s=%s" % [key.percent_encode(), v.percent_encode()]
		else:
			qs += "&%s=%s" % [key.percent_encode(), String(value).percent_encode()]
	qs.erase(0, 1)
	return qs

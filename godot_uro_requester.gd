@tool
extends RefCounted

const godot_uro_helper_const = preload("godot_uro_helper.gd")
const random_const = preload("res://addons/gd_util/random.gd")

const BOUNDARY_STRING_PREFIX = "UroFileUpload"
const BOUNDARY_STRING_LENGTH = 32
const YIELD_PERIOD_MS = 50

class Result:
	var requester_code: int = -1
	var generic_code: int = -1
	var response_code: int = -1
	var data: Dictionary = {}

	func _init(p_requester_code: int, p_generic_code: int, p_response_code: int, p_data: Dictionary = {}):
		requester_code = p_requester_code
		generic_code = p_generic_code
		response_code = p_response_code
		data = p_data


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


func _init(p_hostname: String, p_port: int = -1, p_use_ssl: bool = true):
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
	await self.completed
	
	
func term() -> void:
	terminated = true
	http.close()
	
class  TokenType :
	const NO_TOKEN=0
	const RENEWAL_TOKEN=1
	const ACCESS_TOKEN=2


static func get_status_error_response(p_status: int):
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
		await Engine.get_main_loop().process_frame
		if terminated:
			return Result.new(godot_uro_helper_const.RequesterCode.TERMINATED, OK, -1)
			
	var status: int = HTTPClient.STATUS_DISCONNECTED
	busy = true
	
	var _poll_error: int = OK
	
	if cancelled:
		cancelled = false
		busy = false
		return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
		
	var reconnect_tries: int = 3
	while reconnect_tries:
		_poll_error = http.poll()
		if http.get_status() != HTTPClient.STATUS_CONNECTED:
			print("Connecting to " + str(hostname) + ":" + str(port) + " on ssl:" + str(use_ssl))
			if http.connect_to_host(hostname, port, use_ssl, use_ssl) == OK: # verify_host = false
				while true:
					await Engine.get_main_loop().process_frame
					
					if terminated:
						return Result.new(godot_uro_helper_const.RequesterCode.TERMINATED, OK, -1)
									
					_poll_error = http.poll()
						
					status = http.get_status()
					
					if cancelled:
						cancelled = false
						busy = false
						return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
						
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
			else:
				printerr("GodotUroRequester: could not connect to host")
				return Result.new(godot_uro_helper_const.RequesterCode.FAILED_TO_CONNECT, OK, -1)
					
		if cancelled:
			cancelled = false
			busy = false
			return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
			
		var uri: String = p_path
		var encoded_payload: PackedByteArray = PackedByteArray()
		var headers: Array = []
		
		if p_use_token != TokenType.NO_TOKEN:
			match p_use_token:
				TokenType.RENEWAL_TOKEN:
					headers.push_back("Authorization: %s" % GodotUroData.renewal_token)
				TokenType.ACCESS_TOKEN:
					headers.push_back("Authorization: %s" % GodotUroData.access_token)
			
		if p_payload:
			var encoding: String = _get_option(p_options, "encoding")
			match encoding:
				"query":
					uri += "?%s" % _dict_to_query_string(p_payload)
				"json":
					headers.append("Content-Type: application/json")
					var payload_string: String = JSON.print(p_payload)
					encoded_payload = payload_string.to_utf8_buffer()
				"form":
					headers.append("Content-Type: application/x-www-form-urlencoded")
					var payload_string: String = _dict_to_query_string(p_payload)
					encoded_payload = payload_string.to_utf8_buffer()
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
			
		assert(http.request_raw(_get_option(p_options, "method"), uri, headers, encoded_payload) == OK)
		
		_poll_error = http.poll()
			
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
		return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
		
	while true:
		await Engine.get_main_loop().process_frame
		if terminated:
			return Result.new(godot_uro_helper_const.RequesterCode.TERMINATED, OK, -1)
		if cancelled:
			http.close()
			cancelled = false
			busy = false
			return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
			
		_poll_error = http.poll()
			
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
			
	var last_yield = Time.get_ticks_msec()
	
	while status == HTTPClient.STATUS_BODY:
		var chunk = http.read_response_body_chunk()
		
		if file:
			file.store_buffer(chunk)
			bytes += chunk.size()
			emit_signal("download_progressed", bytes, total_bytes)
		else:
			response_body = response_body if response_body else ""
			response_body += chunk.get_string_from_utf8()
			
		var time = Time.get_ticks_msec()
		if time - last_yield > YIELD_PERIOD_MS:
			await Engine.get_main_loop().process_frame
			last_yield = time
			if terminated:
				if file:
					file.close()
				return Result.new(godot_uro_helper_const.RequesterCode.TERMINATED, OK, -1)
			if cancelled:
				http.close()
				if file:
					file.close()
				cancelled = false
				busy = false
				return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
				
		_poll_error = http.poll()
			
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
			
	await Engine.get_main_loop().process_frame
	if terminated:
		if file:
			file.close()
		return Result.new(godot_uro_helper_const.RequesterCode.TERMINATED, OK, -1)
	if cancelled:
		http.close()
		if file:
			file.close()
		cancelled = false
		busy = false
		return Result.new(godot_uro_helper_const.RequesterCode.CANCELLED, OK, -1)
		
	busy = false
	
	if file:
		file.close()
		
	var data: Dictionary = {}
	if response_body:
		var json_parse_result = JSON.new()
		if json_parse_result.parse(response_body) == OK:
			if typeof(json_parse_result.get_data()) == TYPE_DICTIONARY:
				data = json_parse_result.get_data()
			else:
				data = {"data":str(json_parse_result.get_data())}
			
			if response_code == HTTPClient.RESPONSE_OK:
				return Result.new(godot_uro_helper_const.RequesterCode.OK, OK, response_code, data)
			else:
				return Result.new(godot_uro_helper_const.RequesterCode.HTTP_RESPONSE_NOT_OK, FAILED, response_code, data)
		else:
			printerr("GodotUroRequester: JSON parse result: %s" % str(json_parse_result.error))
			return Result.new(godot_uro_helper_const.RequesterCode.JSON_PARSE_ERROR, FAILED, response_code, data)
		#else:
		#	printerr("GodotUroRequester: JSON validation result: %s" % json_validation_result)
		#	return Result.new(godot_uro_helper_const.RequesterCode.JSON_VALIDATE_ERROR, FAILED, response_code, data)
	else:
		printerr("GodotUroRequester: No response body!")
		return Result.new(godot_uro_helper_const.RequesterCode.NO_RESPONSE_BODY, FAILED, response_code, data)
	
	
func _get_option(options, key):
	return options[key] if options.has(key) else DEFAULT_OPTIONS[key]
	
static func _compose_multipart_body(p_dictionary: Dictionary, p_boundary_string: String) -> PackedByteArray:
	var buffer: PackedByteArray = PackedByteArray()
	for key in p_dictionary.keys():
		buffer.append_array(("\r\n--" + p_boundary_string + "\r\n").to_ascii_buffer())
		var value = p_dictionary[key]
		if value is String:
			var disposition: PackedByteArray = ("Content-Disposition: form-data; name=\"%s\"\r\n\r\n" % key).to_ascii()
			var body: PackedByteArray = value.to_utf8()
			
			buffer.append_array(disposition)
			buffer.append_array(body)
		elif value is Dictionary:
			var content_type: String = value.get("content_type")
			var filename: String = value.get("filename")
			var data: PackedByteArray = value.get("data")
			
			var disposition = ("Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [key, filename, content_type]).to_ascii_buffer()
			var body: PackedByteArray = data

			buffer.append_array(disposition)
			buffer.append_array(body)
		
	buffer.append_array(("\r\n--" + p_boundary_string + "--\r\n").to_ascii_buffer())

	return buffer
	
func _dict_to_query_string(p_dictionary: Dictionary) -> String:
	if has_enhanced_qs_from_dict:
		return http.query_string_from_dict(p_dictionary)
		
	# For 3.0
	var qs: String = ""
	for key in p_dictionary:
		var value = p_dictionary[key]
		if typeof(value) == TYPE_ARRAY:
			for v in value:
				qs += "&%s=%s" % [key.uri_encode(), v.uri_encode()]
		else:
			qs += "&%s=%s" % [key.uri_encode(), String(value).uri_encode()]
	qs = qs.substr(1)
	return qs

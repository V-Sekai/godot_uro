extends Reference

signal completed(p_result)

const YIELD_PERIOD_MS = 50


class Result:
	var ok setget , _is_ok
	var code: int
	var data

	func _init(code: int, data = null) -> void:
		self.code = code
		self.data = data

	func _is_ok():
		return code >= 0


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
	
func request(p_path: String, p_payload: Dictionary, p_use_token: int, p_options: Dictionary = DEFAULT_OPTIONS) -> void:
	while busy and ! terminated:
		yield(Engine.get_main_loop(), "idle_frame")
		if terminated:
			return
			
	var status: int = HTTPClient.STATUS_DISCONNECTED
	busy = true
	
	if cancelled:
		cancelled = false
		busy = false
		emit_signal("completed", null)
		return
		
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
					emit_signal("completed", null)
					return
					
				if (
					status
					in [
						HTTPClient.STATUS_CANT_CONNECT,
						HTTPClient.STATUS_CANT_RESOLVE,
						HTTPClient.STATUS_SSL_HANDSHAKE_ERROR,
					]
				):
					busy = false
					emit_signal("completed")
					return
					
				if status == HTTPClient.STATUS_CONNECTED:
					break
					
		if cancelled:
			cancelled = false
			busy = false
			emit_signal("completed", null)
			
		var uri: String = p_path
		var encoded_payload: String = ""
		var headers: Array = []
		
		if p_use_token != TokenType.NO_TOKEN:
			match p_use_token:
				TokenType.RENEWAL_TOKEN:
					headers.push_back("Authorization: %s" % GodotUro.renewal_token)
				TokenType.ACCESS_TOKEN:
					headers.push_back("Authorization: %s" % GodotUro.access_token)
			
		if p_payload:
			var encoding = _get_option(p_options, "encoding")
			if encoding == "query":
				uri += "?%s" % _dict_to_query_string(p_payload)
			elif encoding == "json":
				headers.append("Content-Type: application/json")
				encoded_payload = to_json(p_payload)
			elif encoding == "form":
				headers.append("Content-Type: application/x-www-form-urlencoded")
				encoded_payload = _dict_to_query_string(p_payload)
				
		var token = _get_option(p_options, "token")
		if token:
			headers.append("Authorization: Bearer %s" % token)
			
		http.request(_get_option(p_options, "method"), uri, headers, encoded_payload)
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
		emit_signal("completed", null)
		return
		
	while true:
		yield(Engine.get_main_loop(), "idle_frame")
		if terminated:
			return
		if cancelled:
			http.close()
			cancelled = false
			busy = false
			emit_signal("completed", null)
			return
			
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
			emit_signal("completed", Result.new(-1))
			return
			
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
		if file.open(out_path, File.WRITE) != OK:
			busy = false
			emit_signal("completed", Result.new(-1))
			return
			
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
				emit_signal("completed", null)
				return
				
		http.poll()
		status = http.get_status()
		if (
			status in [HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR]
			and ! terminated
			and ! cancelled
		):
			if file:
				file.close()
			busy = false
			emit_signal("completed", Result.new(-1))
			return
			
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
		emit_signal("completed", null)
		return
		
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
				
	emit_signal("completed", Result.new(response_code, data))
	
	
func _get_option(options, key):
	return options[key] if options.has(key) else DEFAULT_OPTIONS[key]
	
	
func _dict_to_query_string(p_dictionary) -> String:
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

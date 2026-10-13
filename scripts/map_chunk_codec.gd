extends RefCounted

static func encode(value):
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return value
		TYPE_FLOAT:
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0,value)
			return {"@":"f","v":bytes.hex_encode()}
		TYPE_INT:
			return {"@": "i", "v": str(value)}
		TYPE_STRING_NAME:
			return {"@": "name", "v": str(value)}
		TYPE_VECTOR2:
			return {"@": "v2", "v": [value.x,value.y]}
		TYPE_VECTOR2I:
			return {"@": "v2i", "v": [value.x,value.y]}
		TYPE_VECTOR3:
			return {"@": "v3", "v": [value.x,value.y,value.z]}
		TYPE_VECTOR3I:
			return {"@": "v3i", "v": [value.x,value.y,value.z]}
		TYPE_RECT2:
			return {"@": "r2", "v": [value.position.x,value.position.y,value.size.x,value.size.y]}
		TYPE_RECT2I:
			return {"@": "r2i", "v": [value.position.x,value.position.y,value.size.x,value.size.y]}
		TYPE_COLOR:
			return {"@": "color", "v": [value.r,value.g,value.b,value.a]}
		TYPE_AABB:
			return {"@": "aabb", "v": [value.position.x,value.position.y,value.position.z,value.size.x,value.size.y,value.size.z]}
		TYPE_ARRAY:
			return value.map(encode)
		TYPE_DICTIONARY:
			if value.keys().all(func(key): return key is String and key != "@"):
				var result := {}
				for key in value:
					result[key] = encode(value[key])
				return result
			var pairs := []
			for key in value:
				pairs.append([encode(key),encode(value[key])])
			return {"@": "map", "v": pairs}
	push_error("Map chunks contain an unsupported value type: " + type_string(typeof(value)))
	return null

static func decode(value) -> Dictionary:
	return _decode(value,0,{"remaining":200000})

static func _decode(value, depth: int, budget: Dictionary) -> Dictionary:
	budget.remaining -= 1
	if depth > 48 or budget.remaining < 0:
		return {"ok":false,"error":"Map chunk exceeds decoding limits"}
	if value == null or value is bool or value is String or value is int or value is float:
		if value is float and not is_finite(value):
			return {"ok":false,"error":"Map chunk has a nonfinite number"}
		return {"ok":true,"value":value}
	if value is Array:
		var items := []
		for item in value:
			var decoded := _decode(item,depth + 1,budget)
			if not decoded.ok:
				return decoded
			items.append(decoded.value)
		return {"ok":true,"value":items}
	if not value is Dictionary:
		return {"ok":false,"error":"Invalid map chunk value"}
	if not value.has("@"):
		var result := {}
		for key in value:
			var decoded := _decode(value[key],depth + 1,budget)
			if not decoded.ok:
				return decoded
			result[key] = decoded.value
		return {"ok":true,"value":result}
	var tag = value.get("@")
	var parts = value.get("v")
	if value.size() != 2 or not tag is String:
		return {"ok":false,"error":"Invalid map chunk tag"}
	if tag == "i":
		if not parts is String or not parts.is_valid_int() or parts.length() > 20:
			return {"ok":false,"error":"Invalid map integer"}
		return {"ok":true,"value":parts.to_int()}
	if tag == "f":
		if not parts is String or parts.length() != 16 or not parts.is_valid_hex_number():
			return {"ok":false,"error":"Invalid map floating point value"}
		var number: float = parts.hex_decode().decode_double(0)
		if not is_finite(number):
			return {"ok":false,"error":"Map chunk has a nonfinite number"}
		return {"ok":true,"value":number}
	if tag == "name":
		if not parts is String or parts.length() > 10000:
			return {"ok":false,"error":"Invalid map string name"}
		return {"ok":true,"value":StringName(parts)}
	if tag == "map":
		if not parts is Array:
			return {"ok":false,"error":"Invalid map dictionary"}
		var result := {}
		for pair in parts:
			if not pair is Array or pair.size() != 2:
				return {"ok":false,"error":"Invalid map dictionary pair"}
			var key := _decode(pair[0],depth + 1,budget)
			var item := _decode(pair[1],depth + 1,budget)
			if not key.ok or not item.ok or result.has(key.get("value")):
				return {"ok":false,"error":"Invalid or duplicate map key"}
			result[key.value] = item.value
		return {"ok":true,"value":result}
	var sizes := {"v2":2,"v2i":2,"v3":3,"v3i":3,"r2":4,"r2i":4,"color":4,"aabb":6}
	if not sizes.has(tag) or not parts is Array or parts.size() != sizes[tag] or not parts.all(func(number): return (number is int or number is float) and is_finite(float(number)) and absf(float(number)) <= 1000000000):
		return {"ok":false,"error":"Invalid map vector or geometry"}
	if tag in ["v2i","v3i","r2i"] and not parts.all(func(number): return number == floorf(number)):
		return {"ok":false,"error":"Map integer geometry contains fractions"}
	match tag:
		"v2": return {"ok":true,"value":Vector2(parts[0],parts[1])}
		"v2i": return {"ok":true,"value":Vector2i(parts[0],parts[1])}
		"v3": return {"ok":true,"value":Vector3(parts[0],parts[1],parts[2])}
		"v3i": return {"ok":true,"value":Vector3i(parts[0],parts[1],parts[2])}
		"r2": return {"ok":true,"value":Rect2(parts[0],parts[1],parts[2],parts[3])}
		"r2i": return {"ok":true,"value":Rect2i(parts[0],parts[1],parts[2],parts[3])}
		"color": return {"ok":true,"value":Color(parts[0],parts[1],parts[2],parts[3])}
		"aabb": return {"ok":true,"value":AABB(Vector3(parts[0],parts[1],parts[2]),Vector3(parts[3],parts[4],parts[5]))}
	return {"ok":false,"error":"Unsupported map value"}

extends RefCounted

static func valid(value) -> bool:
	if not value is String or not value.is_valid_int():
		return false
	var negative: bool = value.begins_with("-")
	var digits: String = value.trim_prefix("-").trim_prefix("+").lstrip("0")
	var limit := "9223372036854775808" if negative else "9223372036854775807"
	return digits.length() < 19 or (digits.length() == 19 and digits <= limit)

static func bounded(value, maximum: float) -> bool:
	return valid(value) and absf(value.to_float()) <= maximum

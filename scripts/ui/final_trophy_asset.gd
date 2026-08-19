extends RefCounted

const PART_0 = preload("res://scripts/ui/final_trophy_small_0.gd")
const PART_1 = preload("res://scripts/ui/final_trophy_small_1.gd")

static func webp_base64() -> String:
	return PART_0.DATA + PART_1.DATA

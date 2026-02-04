extends Node
class_name JournalSystem

signal entry_documented(entry_id: String)

# This persists across cycle resets
var documented_entries: Dictionary = {}

func has_entry(entry_id: String) -> bool:
	return documented_entries.get(entry_id, false)

func add_entry(entry_id: String) -> void:
	if has_entry(entry_id):
		print("Already documented:", entry_id)
		return
	
	documented_entries[entry_id] = true
	print("Documented:", entry_id)
	entry_documented.emit(entry_id)

func get_all_entries() -> Array:
	return documented_entries.keys()

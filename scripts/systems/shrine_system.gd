extends Node
class_name ShrineSystem

signal shrine_activated(shrine_id: String)

# shrine_id -> activated?
var activated: Dictionary = {}

# shrine_id -> required journal entries
var requirements := {
	"trade_wind": [
		"fish_tropical_01",
		"coral_01",
		"bird_migrant_01"
	]
}

@onready var journal: JournalSystem = $"../JournalSystem"

func is_activated(shrine_id: String) -> bool:
	return activated.get(shrine_id, false)

func can_activate(shrine_id: String) -> bool:
	if is_activated(shrine_id):
		return false
	
	var reqs: Array = requirements.get(shrine_id, [])
	for entry_id in reqs:
		if not journal.has_entry(entry_id):
			return false
	
	return true

func activate(shrine_id: String) -> void:
	if not can_activate(shrine_id):
		print("Cannot activate shrine:", shrine_id)
		return
	
	activated[shrine_id] = true
	print("Shrine activated:", shrine_id)
	shrine_activated.emit(shrine_id)

func active_count() -> int:
	var count := 0
	for k in activated.keys():
		if activated[k]:
			count += 1
	return count

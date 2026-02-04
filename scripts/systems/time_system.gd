extends Node

## 28-day cycle time system.
##
## Days advance automatically on a real-time timer.
## Press SPACE for manual advance (for testing).
## The cycle drives weather, ocean, and cataclysm intensity.

const DAYS_PER_CYCLE := 28
const DAYS_PER_WEEK := 7
const CONVERGENCE_WARNING_DAY := 22

## How many real seconds = one in-game day
## 120 = 2 minutes per day, so a full 28-day cycle = ~56 minutes
## Adjust for pacing: 60 = fast (28 min cycle), 180 = slow (84 min cycle)
@export var seconds_per_day: float = 300.0

var absolute_day: int = 1
var cycle_day: int = 1
var cycle_count: int = 1
var cataclysm_intensity: float = 0.0

## Progress through the current day (0.0 → 1.0)
var day_progress: float = 0.0
var _day_timer: float = 0.0

signal day_advanced(cycle_day: int, cycle_count: int)
signal cataclysm_building(intensity: float)
signal cataclysm_triggered()

func _ready() -> void:
	print("⏳ TimeSystem initialized — %d sec/day" % int(seconds_per_day))
	print_state()
	# Emit initial state so listeners get correct values at startup
	day_advanced.emit(cycle_day, cycle_count)
	_update_cataclysm_intensity()

func _process(delta: float) -> void:
	# Auto-advance timer
	_day_timer += delta
	day_progress = clampf(_day_timer / seconds_per_day, 0.0, 1.0)

	if _day_timer >= seconds_per_day:
		_day_timer -= seconds_per_day
		advance_day()


func advance_day() -> void:
	absolute_day += 1
	cycle_day += 1

	if cycle_day > DAYS_PER_CYCLE:
		cycle_day = 1
		cycle_count += 1
		trigger_cataclysm()

	_update_cataclysm_intensity()
	day_advanced.emit(cycle_day, cycle_count)
	print_state()

func _update_cataclysm_intensity() -> void:
	if cycle_day < CONVERGENCE_WARNING_DAY:
		cataclysm_intensity = 0.0
		cataclysm_building.emit(cataclysm_intensity)
		return

	var days_past_warning: int = cycle_day - CONVERGENCE_WARNING_DAY
	var total_warning_days: int = DAYS_PER_CYCLE - CONVERGENCE_WARNING_DAY
	var base_progress: float = float(days_past_warning) / float(total_warning_days)
	var escalation_multiplier: float = 1.0 + (cycle_count - 1) * 0.25

	cataclysm_intensity = clampf(base_progress * escalation_multiplier, 0.0, 1.0)
	cataclysm_building.emit(cataclysm_intensity)

func trigger_cataclysm() -> void:
	print("💥 CATACLYSM TRIGGERED — Cycle: %d" % cycle_count)
	cataclysm_triggered.emit()

func reset_cycle(was_stabilized: bool) -> void:
	cycle_day = 1
	if not was_stabilized:
		cycle_count += 1
	cataclysm_intensity = 0.0
	day_advanced.emit(cycle_day, cycle_count)
	print("Cycle reset. Stabilized: %s, New cycle: %d" % [str(was_stabilized), cycle_count])

## Returns a display string for the HUD
func get_day_string() -> String:
	return "Day %d / %d" % [cycle_day, DAYS_PER_CYCLE]

## Returns the week name
func get_week_name() -> String:
	var week: int = ((cycle_day - 1) / DAYS_PER_WEEK) + 1
	match week:
		1: return "Calm Winds"
		2: return "Fair Seas"
		3: return "Rising Tides"
		4: return "Convergence"
		_: return "Week %d" % week

func print_state() -> void:
	print("Day %d (Cycle %d) — %s — Intensity: %.2f" % [cycle_day, cycle_count, get_week_name(), cataclysm_intensity])

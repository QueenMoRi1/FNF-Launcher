class_name PlayMode
extends RefCounted
## Scoring for the chart viewer's secret play mode (hold M for 5 seconds):
## you play BF's side with D F J K. Judging uses Psych Engine's defaults.

## [window ms, popup text, points, accuracy weight]
const RATINGS := [[45.0, "SICK!!", 350, 1.0], [90.0, "GOOD", 200, 0.67], [135.0, "BAD", 100, 0.34], [166.0, "SHIT", 50, 0.0]]
const MISS_WINDOW := 166.0

## chart note index -> 0 waiting, 1 hit, 2 missed (player notes only)
var state := {}
var player: Array[int] = [] # chart note indices of BF's notes, in time order
var score := 0
var misses := 0
var combo := 0
var max_combo := 0
var judged := 0
var accuracy_sum := 0.0
var last_end := 0.0
var _notes: Array


func _init(chart_notes: Array) -> void:
	_notes = chart_notes
	for i in chart_notes.size():
		var n: Array = chart_notes[i]
		if n[1] == 1:
			player.append(i)
			state[i] = 0
			last_end = maxf(last_end, n[0] + n[3])


func is_empty() -> bool:
	return player.is_empty()


## A key press in `lane` at song time `t`. Returns [rating text, note index]
## or ["", -1] when there was nothing to hit (ghost tapping: no penalty).
func press(lane: int, t: float) -> Array:
	var best := -1
	for i in player:
		if state[i] != 0 or _notes[i][2] != lane:
			continue
		var n: Array = _notes[i]
		if absf(n[0] - t) <= MISS_WINDOW:
			best = i
			break # player is in time order: the first one in the window is the earliest
		if n[0] > t + MISS_WINDOW:
			break
	if best < 0:
		return ["", -1]
	state[best] = 1
	var diff := absf(_notes[best][0] - t)
	var text := ""
	for r in RATINGS:
		if diff <= r[0]:
			score += r[2]
			accuracy_sum += r[3]
			text = r[1]
			break
	judged += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	return [text, best]


## Notes that went past without being hit. Returns how many new misses.
func check_misses(now: float) -> int:
	var count := 0
	for i in player:
		if _notes[i][0] >= now - MISS_WINDOW:
			break
		if state[i] == 0:
			_miss(i)
			count += 1
	return count


## The song ended: anything never reached counts as missed.
func finish() -> void:
	for i in player:
		if state[i] == 0:
			_miss(i)


func _miss(i: int) -> void:
	state[i] = 2
	misses += 1
	judged += 1
	combo = 0
	score -= 10


func accuracy() -> float:
	return accuracy_sum / judged * 100.0 if judged > 0 else 100.0


func rank() -> String:
	var acc := accuracy()
	if misses == 0 and acc >= 99.9:
		return "PERFECT!!"
	if misses == 0:
		return "FULL COMBO"
	if acc >= 90.0:
		return "SICK"
	if acc >= 80.0:
		return "GREAT"
	if acc >= 65.0:
		return "GOOD"
	return "NICE TRY"


static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out

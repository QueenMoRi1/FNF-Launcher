class_name Quips
extends RefCounted
## Intro quips, shown two lines at a time like FNF's introText.txt.

const LIST := [
	["beep bop", "skee dah"],
	["blue balled", "again"],
	["the orang", "is watching"],
	["skill issue", "detected"],
	["downscroll", "superior"],
	["upscroll", "also fine"],
	["ghost tapping", "on"],
	["pico", "funny"],
	["made in godot", "not haxeflixel"],
	["ge proton", "is required"],
	["spooky month", "every month"],
	["week seven", "was worth the wait"],
	["boyfriend", "still cant talk"],
	["girlfriend", "sits on speakers professionally"],
	["monster", "did nothing wrong"],
	["ugh", "ugh"],
	["press enter", "you wont"],
	["lag train", "never stops"],
	["sick sick sick", "sick sick"],
	["full combo", "in your dreams"],
	["week six", "in pixels"],
	["senpai", "noticed you"],
	["dad", "disapproves"],
	["mom", "has a car"],
	["the speakers", "are load bearing"],
	["mic", "check one two"],
	["erect mode", "unlocked"],
	["ludum dare", "we remember"],
	["fnf soft", "very soft"],
	["psych engine", "goes brrr"],
	["botplay", "is cheating"],
	["eight keys", "no thank you"],
	["your keybinds", "are wrong"],
	["dfjk", "forever"],
	["trending", "on fnf twitter"],
	["the fnf idiots", "we love them"],
	["orang entertainment", "est today"],
	["note spam", "is not a chart"],
	["hit your notes", "or else"],
	["tankman", "ugh"],
	["bopeebo", "fresh"],
	["keep funkin", "always"],
]


static func pick() -> Array:
	return LIST.pick_random()

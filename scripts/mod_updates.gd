class_name ModUpdates
extends Node
## Checks GameBanana for newer uploads of the installed mods.
##
## Each mod remembers the upload date of its newest file it has seen
## (entry.gb_seen, unix time): set when it's installed through the download
## queue, or on the first check for mods that were already there. A newer
## upload sets entry.update_available. Checked at most every CHECK_HOURS.

signal finished(count: int)

const CHECK_HOURS := 12

var gamebanana: GameBanana
var running := false


func due(settings: Dictionary) -> bool:
	return Time.get_unix_time_from_system() - float(settings.get("mod_updates_checked", 0)) > CHECK_HOURS * 3600.0


## Checks every mod that has a GameBanana page. Emits finished(number with updates).
func check_all(library: Library) -> void:
	if running:
		return
	running = true
	var count := 0
	for path in library.games.keys():
		if not library.games.has(path):
			continue
		var entry: Dictionary = library.games[path]
		if await check_one(entry):
			count += 1
	library.settings.mod_updates_checked = int(Time.get_unix_time_from_system())
	library.save()
	running = false
	finished.emit(count)


## Returns true if the mod has an update. Changes entry.gb_seen / update_available.
func check_one(entry: Dictionary) -> bool:
	var id := int(entry.get("gb", {}).get("id", 0))
	if id <= 0:
		return false
	var mod: Dictionary = await gamebanana.get_mod_files(id)
	if mod.is_empty() or mod.files.is_empty():
		return entry.has("update_available") # offline: keep what we knew
	var newest := 0
	for f in mod.files:
		newest = maxi(newest, int(f.get("date", 0)))
	if not entry.has("gb_seen"):
		entry.gb_seen = newest
	if newest > int(entry.gb_seen):
		entry.update_available = newest
		return true
	entry.erase("update_available")
	return false


## After an update was installed: it's the newest now.
static func mark_updated(entry: Dictionary, file_date: int) -> void:
	entry.gb_seen = maxi(file_date, int(entry.get("update_available", 0)))
	entry.erase("update_available")

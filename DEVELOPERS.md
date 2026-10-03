# Info for anyone wanting to work on the project too.

hi. it's joey (orang entertainment). i'm typing this up at work. on my break. ok not entirely on my break. if my manager is reading this: hello, i am being very productive right now. 🍊

this is the "how does any of this work" doc for **FNF Launcher**. if you want to fix a bug, add a skin, steal my code (it's licensed, read LICENSE), or just understand why there are 50 gdscript files for a program that opens other programs, it's all here. i tried to put **everything** in it. it's long. get a snack.

fair warning, same as the website: this project is partially vibecoded. an AI (Claude) wrote a lot of the code with me directing, testing, fixing and yelling. type `artificial` in the launcher for the full speech. so the code is consistent-ish and commented-ish, and the commit history is me going "ok now do this".

---

## tl;dr

- it's a **Godot 4.7.2** project, written in **GDScript**. no C#, no plugins, no addons, no build step.
- it's a launcher for **Friday Night Funkin' mods** (windows .exe games) that runs them on **Linux** through **GE-Proton + Steam Linux Runtime**, like Steam would.
- the whole UI is styled like FNF (or Steam Big Picture, or the Xbox 360 dashboard, pick your poison).
- there's a separate **Windows Beta** in its own folder (`fnf-launcher-windows-beta`). it runs mods directly. it'll get merged into this one in **v2**. until then, every change has to go into **both**. yes, by hand. yes, it sucks. see "the two folders" below.
- FunkinCrew's assets (the font, menu music, sounds, alphabet...) are **never** shipped. the installer downloads them. don't commit them. seriously.

---

## running it

1. get Godot **4.7.2** (the standard one, not .NET). i use the AppImage.
2. get FunkinCrew's assets into `assets/funkin/` (they're gitignored). easiest way: run the real installer once and copy `~/.local/share/fnf-launcher/app/assets/funkin/` over. or grab the files listed in `FNF_ASSET_FILES` in `tools/installer_header.sh` from `https://raw.githubusercontent.com/FunkinCrew/Funkin.assets/main/` and put them in that folder **flat** (just the file names, no subfolders).
3. `godot --path .` (or open it in the editor and press play).
4. for actually launching mods you need Steam with **GE-Proton** in `compatibilitytools.d` and the **Steam Linux Runtime 4** installed. the launcher yells at you if you don't.

renderer is `gl_compatibility` on purpose: it runs on everything, including a potato and the Steam Deck.

---

## how it's put together (the big picture)

```
intro.tscn (intro.gd)   FNF-style title intro, beat-synced to Freaky Menu
        │
        ▼
main.tscn (main.gd)     THE controller. owns the library, input, overlays,
        │               launching, downloads, settings... 2000+ lines. sorry.
        ├── a SkinView (skins/*.gd)      draws the game list. that's ALL it does.
        ├── ThemeRuntime                 paints a custom theme on top
        ├── ChartViewer                  full-screen chart viewer + secret play mode
        ├── ThemeEditor                  the drag & drop theme editor
        ├── Downloader / GameBanana      download queue + GameBanana API
        ├── FriendsService               friends server client
        ├── ModUpdates                   GameBanana update checker
        └── overlays (UiKit.Overlay)     every popup: settings, edit, leaderboard...

autoloads (always there): Music, Cheats, Discord, Achievements
```

the rule that keeps this from becoming spaghetti: **skins only draw**. input, selection, launching, overlays, all of it is `main.gd`. a skin gets a list of items and a selected index and makes it pretty. that's how there can be three completely different looking skins without three copies of the logic.

### the life of a click on PLAY (linux)

1. `main._launch_selected()` checks there's a Proton (`_proton_for(entry)`: the mod's own pick or the newest GE-Proton) and an exe, plays the confirm sound, and asks the skin for its launch animation.
2. `main._start_game(entry)`:
   - `ModSaves.backup(entry)`: backs up the mod's `.sol` saves.
   - `Keybinds.apply(...)`: if global keybinds are on, rewrites the saved controls.
   - `ModSaves.snapshot()`: on Windows, remembers AppData so it can learn where the mod saves.
   - `Proton.launch(...)`: builds the command **as a list** and runs it through `sh -c 'cd "$d" && exec "$@"'`. never paste paths into shell strings. ever. i learned.
   - the command is basically `env STEAM_COMPAT_DATA_PATH=<prefix> ... [gamescope -f -r 60 --] SteamLinuxRuntime_4/_v2-entry-point --verb=waitforexitandrun -- GE-Proton/proton waitforexitandrun Game.exe <args>`. that's what Steam does too. each mod gets its own Wine prefix in `~/.local/share/fnf-launcher/prefixes/<slug>/`.
   - output goes to `user://logs/<slug>.log`.
3. music pauses, Discord shows "playing X", `run_timer` polls the pid.
4. `main._check_game()` notices the game closed: music comes back, `Stats.add_session()` logs play time for Funkin' Wrapped, the window grabs focus back so the controller works.

if Steam Linux Runtime isn't installed it falls back to `umu-run`. most people won't hit that path.

---

## folders

| folder | what's in it |
|---|---|
| `scenes/` | `intro.tscn` (start), `main.tscn` (the launcher), `installer.tscn` (the graphical installer). that's it, everything else is built in code. |
| `scripts/` | all the code. one class per file, mostly with `class_name`. |
| `scripts/skins/` | the three skins + their base class |
| `scripts/themes/` | custom themes: reading, applying, editing, particles, seasonal extras |
| `scripts/android/` | the android build's library (installed FNF apks). unreleased, don't worry about it |
| `shaders/` | the chart viewer's PS3-style background and its trippy post effect |
| `assets/orang/`, `assets/jim/`, `assets/compost/` | our own stuff (the orang, easter egg videos/sounds) |
| `assets/funkin/` | FunkinCrew's assets. **gitignored. downloaded at install. never commit.** |
| `themes_examples/` | the 28 example themes, copied into the user's themes folder (new ones only) |
| `server/worker.js` | the friends server + theme gallery (Cloudflare Worker) |
| `tools/` | installer, release, update and versioning scripts, the discord helper, steam art maker |
| `wiki/` | the GitHub wiki pages (synced to the separate wiki repo by hand) |
| `_demo/` | my test harnesses and screenshot dumps. **gitignored**, not in builds. |

---

## every script, explained (i'm so tired)

### the core
- **`main.gd`**: the launcher controller. builds the hint bar, loads the library, applies the skin and theme, handles every input, opens every overlay (settings, edit, leaderboard, achievements, downloads, friends, update prompts...), launches games, watches them. it's huge because overlays are just functions that build UI in code. if you're looking for "where does X happen", it's here 80% of the time. sections are marked with `# --- Something ---` comments.
- **`intro.gd`**: the FNF intro (credits, quips, "FRIDAY NIGHT FUNKIN'" title words), synced to Freaky Menu's BPM. custom themes can change or skip it. it switches to `main.tscn` at the end.
- **`library.gd`** (`Library`): the mod list. scans the games folder (one folder per mod), picks the exe (`pick_exe`: name-matches-folder > shallowest > biggest), finds songs (`Inst*.ogg/mp3`), and saves everything in `user://library.json` (`games` keyed by folder path, plus `settings`). `prefixes_dir()` is where the data folder lives; lots of stuff uses its parent.
- **`ui_kit.gd`** (`UiKit`): the shared Godot `Theme` (VCR font, button styles) and the overlay helpers (`make_overlay`, `add_label`, `add_button`, `add_row`). `UiKit.Overlay` is the popup type; `main.overlay` holds the open one, and while one's open the menu ignores input.
- **`input_setup.gd`**: binds keyboard + controller actions once. controller events use device -1 because handhelds (ROG Ally!) don't always show up as pad #0.

### skins (`scripts/skins/`)
- **`skin_view.gd`** (`SkinView`): base class. `build(items, selected, empty_hint)`, `set_selected`, `set_art`, `play_launch`. skins expose `background_nodes` and `mod_art_nodes` so themes can paint between them.
- **`freeplay_view.gd`**: FNF Freeplay list with the Alphabet font and health icons.
- **`steam_view.gd`**: Steam Big Picture: hero art, a row of covers, PLAY button, clock.
- **`blades_view.gd`**: Xbox 360 2005 "blades" dashboard. yes, really.
- **`alphabet.gd`**: draws FNF's bold Alphabet text from `alphabet.png/xml`.

to add a skin: extend `SkinView`, add it to `SKINS`/`SKIN_NAMES` in main.gd, `BASES`/`BASE_NAMES` in custom_theme.gd and `SKINS` in achievements.gd (that's the "try every skin" achievement).

### custom themes (`scripts/themes/`)
- **`custom_theme.gd`** (`CustomTheme`): a theme is a folder with `theme.txt` (`key: value` lines). parses it, writes it back, resolves files, `style()` turns it into a Godot Theme, export/import `.fnftheme` (a zip, import is sanitised: no `..`, only safe file types). `session_id()` picks the theme for this launch (manual / random / daily / seasonal). `HEADER` is the documentation that gets written at the top of every theme.txt, so keep it in sync with new keys.
- **`theme_runtime.gd`** (`ThemeRuntime`): applies a theme to the live menu: background (image/video/pattern/gradient), particles, logo, cursor, UI scale, and the "move/hide parts" layout (`move <part>: dx% dy% scale%`).
- **`theme_editor.gd`** (`ThemeEditor`): the side panel editor. colours, files (browse or drag & drop on the window), sliders, MOVE THINGS mode (drag parts, drag corners to resize). saves on every change. always uses the launcher's own font so wide theme fonts can't break it.
- **`theme_particles.gd`** (`ThemeParticles`): the animated backgrounds (snow, bubbles, notes, bats...). one Control drawing everything in `_draw`. bats are drawn as triangles with `draw_primitive` because a flapping polygon can self-intersect and Godot screams.
- **`seasonal_extras.gd`**: snow + christmas lights in december, bats in october, etc. only when no custom theme is active. preview with `--season=christmas` (or newyear, halloween, valentine, stpatrick, aprilfools).

new theme key checklist: parse/use it in `theme_runtime.gd` (or wherever), add it to the `HEADER` docs, add a control in `theme_editor.gd`, document it in `wiki/Custom-Themes.md`. if it's a colour, add it to `COLOR_KEYS` **and** the editor's `COLOR_NAMES` (if you forget, the editor crashes on open. ask me how i know).

### music & the chart viewer
- **`music.gd`** (autoload `Music`): Freaky Menu during the intro, then a shuffled playlist of every mod's instrumentals. handles pausing while a game runs, themes' menu music, `.mp3` loading. `track_changed` signal.
- **`now_playing.gd`**: the corner jukebox widget.
- **`chart.gd`** (`Chart`): finds and reads charts for a song from its Inst path. understands the old format (base game, Psych, Kade), Psych 1.0, V-Slice (0.3+) and Codename. a loaded chart is `{notes: [[time_ms, side, dir, length_ms, special]], bpms, speed}`. side 0 = opponent, 1 = BF.
- **`chart_viewer.gd`** (`ChartViewer`): the full-screen PS3-CD-player-looking viewer. plays Inst + Voices, auto-hits every note, spectrum visualizer, shaders. also houses the **secret play mode**: hold M 5 s → setup card (side / speed / difficulty) → countdown → you play with DFJK. speed uses `pitch_scale`, so the song clock (`now_ms`) moves at `delta * rate`.
- **`play_mode.gd`** (`PlayMode`): scoring for play mode. Psych Engine's windows and points; windows scale with speed so they feel the same in real time.
- **`play_scores.gd`** (`PlayScores`): best play mode runs in `user://playmode_scores.json`.

### mods: downloads, gamebanana, updates, saves
- **`downloader.gd`** (`Downloader`): the download queue. GameBanana page or direct link → download (HTTPRequest to a `.part` file) → sniff the archive type by magic bytes → unpack with 7-Zip **on a thread** → step into wrapper folders → find an exe → move into the games folder. `add_url(url, update_of)` replaces an installed mod (old one goes to `<games>/.old/`). deletes are restricted to `.downloads` / `.old` and never follow symlinks.
- **`gamebanana.gd`** (`GameBanana`): GameBanana API v11. search, `auto_match` (fuzzy name matching ignoring "fnf", "vs", "mod"...), mod files with upload dates, art download + cache.
- **`mod_updates.gd`** (`ModUpdates`): compares the newest GameBanana upload date with `entry.gb_seen`. newer = `entry.update_available`. checked every 12 h.
- **`mod_saves.gd`** (`ModSaves`): where a mod's saves are (linux: its prefix's AppData; windows: learned by watching which `.sol` files change during play) and save **backups** (`<data>/backups/<slug>/<timestamp>/` + `backup.json`). restore can only write inside the mod's own save folders.
- **`save_file.gd`** (`SaveFile`): reads and writes Haxe-serialized `.sol` files **losslessly**: keeps every value's exact type and re-emits string back-references (`R0`, `R1`...) and escaping exactly like Haxe, so an untouched save comes out **byte for byte identical**. (tested on every save on my PC). if it sees a format it doesn't understand, it refuses and leaves the file alone. don't loosen that.
- **`scores.gd`** (`Scores`): the leaderboard. reads `songScores` out of every save, sums each song's best difficulty. has its own tiny read-only unserializer.
- **`keybinds.gd`** (`Keybinds`): global note keys. writes FlxKey codes/names into Psych 0.6+ (`controls_v2.sol`), Psych 0.4/0.5 (`controls.sol`) and Kade (`leftBind`...) saves. only the main key of each note changes.
- **`mod_health.gd`** (`ModHealth`): the health check. PE header check for the exe, engine guessing, lime.ndll, manifest-vs-disk capitalisation (`case_mismatches`, the thing i found while losing my mind over Tricky), proton/runtime/prefix/disk checks.
- **`icon_loader.gd`** (`IconLoader`): a mod's icon: user override > `.ico`/`icon*.png` > the icon embedded in the exe (parses PE resources!) > FNF face. includes an `.ico` decoder because godot can't read them.

### proton & linux stuff
- **`proton.gd`** (`Proton`): finds Steam installs, GE-Proton (newest that's x86_64), the Steam Linux Runtime its `toolmanifest.vdf` asks for, every installed Proton (`list_all`, for per-mod picks), gamescope, and `launch()`. `split_args` handles launch options with quotes.
- **`proton_popup.gd`**: the "this launcher only uses GE-Proton" popup on first launch.
- **`steam_friends.gd`** (`SteamFriends`): reads your Steam id and friends list straight from the Steam client's local files. no API key.
- **`friends_service.gd`** (`FriendsService`): posts your status to the friends server and polls friends. heartbeat every 5 min, polls every minute while the page is open.
- **`discord.gd`** (autoload `Discord`): rich presence. linux: spawns `tools/discord_rpc.py` (stdlib-only python) and sends it JSON lines. windows beta: talks to Discord's named pipe itself on a thread.

### fun stuff
- **`achievements.gd`** (autoload `Achievements`): the `LIST` of achievements (`id: [title, description, hint]`; a non-empty hint = secret, shown as ??? until found), toasts, unlock sounds (FNF/Xbox/Steam/PS3/Newgrounds, the non-FNF ones downloaded on first pick), saved in `user://achievements.json`. Completionist counts `LIST.size()` automatically.
- **`cheats.gd`** (autoload `Cheats`): typed codes (`fafa`, `deltarune`, `gooseworx`, `jim`/`JIM`, `compost`, `artificial`, `chromatics`, `yearofthelinuxdesktop`). listens to every key press globally (not in text boxes), keeps the last 32 characters, checks `ends_with`. `active` blocks the menu while an egg is on screen. android gets a text box instead (tap the orange in Settings 5 times).
- **`chromatics.gd`** (`Chromatics`): the BF piano. downloads BF's sprite sheet + Tutorial vocals from FunkinCrew on first use, parses the Sparrow XML into SpriteFrames, pitches one sung note per key. custom chromatic slot: `assets/chromatics/` or the user `chromatics` folder + `chromatic.txt` (`note:`, `start:`, `length:`, `credit:`).
- **`xp_popup.gd`**: the "Where'd you go?????" Windows XP popup after an hour idle.
- **`quips.gd`**: the intro's two-line quips (one is misspelled on purpose).
- **`stats.gd`** (`Stats`): play sessions + jukebox listens for Wrapped, in `user://stats.json`. times are UTC in the file; convert with the time zone bias when showing them (Godot's unix-time functions are UTC, i got bitten).
- **`wrapped.gd`** (`Wrapped`): Funkin' Wrapped. it's an `UiKit.Overlay` so the menu treats it like any popup.
- **`theme_gallery.gd`** (`ThemeGallery`): browse/share/install themes via the friends server.
- **`tools_ui.gd`** (`ToolsUI`): the edit dialog's UPDATES / PROTON & PERFORMANCE / SAVE BACKUPS / HEALTH CHECK sections and Settings' KEYBINDS / MOD TOOLS / FUN STUFF rows. kept out of main.gd so main.gd doesn't hit 3000 lines.
- **`updater.gd`** (`Updater`): the launcher's own update notifier. two channels: **github** (any new commit on main; `tools/update.sh` downloads the code and **builds an installer on the spot**) and **release** (newest GitHub release = the itch build).

### installer
- **`installer.gd`** + `scenes/installer.tscn`: the graphical installer UI. the real work is `tools/installer_header.sh`; this just runs its steps and shows progress.

---

## where stuff lives on a user's machine (linux)

| what | where |
|---|---|
| the app | `~/.local/share/fnf-launcher/app/` (this project) |
| godot | `~/.local/share/fnf-launcher/godot/godot` |
| the `fnf-launcher` command | `~/.local/bin/fnf-launcher` (`exec godot --path app`) |
| wine prefixes | `~/.local/share/fnf-launcher/prefixes/<mod slug>/` |
| custom themes | `~/.local/share/fnf-launcher/themes/<id>/` |
| save backups | `~/.local/share/fnf-launcher/backups/<mod slug>/` |
| bundled 7-Zip | `~/.local/share/fnf-launcher/bin/7zz` (SteamOS doesn't ship 7z) |
| `user://` (library.json, achievements.json, stats.json, logs, caches) | `~/.local/share/godot/app_userdata/FNF Launcher/` |
| mods | `~/Games/FNF/` by default |

windows beta: data in `%APPDATA%\fnf-launcher`, app in `%LOCALAPPDATA%\Programs\FNF Launcher`, FNF assets in `<install>\funkin\`.

---

## the two folders (linux + windows beta)

- `fnf-launcher/`: this, the main project. linux. what gets released.
- `fnf-launcher-windows-beta/`: the windows beta. its own version numbers ("Windows Beta v1.2.0"). **separate on purpose until v2.**

what's different in the windows one:
- `scripts/platform.gd` (`Platform`): paths per OS (`data_dir`, `install_dir`, `funkin_dir`).
- `scripts/fnf_assets.gd` (`FnfAssets`): loads FunkinCrew's assets from `<install>/funkin/` at runtime (they can't be in the .exe), so everything does `FnfAssets.res("vcr.ttf")` instead of `load("res://assets/funkin/...")`.
- `scripts/self_test.gd`: `"FNF Launcher.exe" -- --selftest` checks everything and writes `logs/selftest.log`. use it under Proton/Wine to test without owning windows.
- `proton.gd` launches with `cmd /c start "" /wait` instead of Proton.
- `windows_setup/`: a **separate godot project** that becomes `FNF-Launcher-Windows-Beta-Setup.exe`. it unpacks the launcher (payload.zip inside its pck), downloads FunkinCrew's assets, makes shortcuts, a `.bat` uninstaller, registers in Installed apps (via a `.reg` import because quotes + reg.exe = pain), and can add itself to Steam by writing `shortcuts.vdf` (`steam_shortcut.gd`, binary VDF, Steam must be closed). `--update` mode is what the updater runs.
- `tools/build_windows.sh`: exports the launcher exe, zips it with the example themes into `windows_setup/payload.zip`, exports Setup. needs the Windows export templates.

**porting rule:** every change to the main project gets applied to the windows one too, minus the linux-only bits. i do it with little python patch scripts that run on both folders with exact-match find/replace (they assert the text is there exactly once, so they fail loudly instead of silently doing nothing). recommended.

---

## data formats you'll run into

- **library.json**: `{games_dir, settings: {...}, games: {"<folder>": {name, exe, icon_override, slug, prefix, songs, gb, source, favorite, hidden, args, cover, color, options, plays, last_played, gb_seen, update_available, save_dirs}}}`. new settings just get added with a `.get(key, default)` wherever they're read; there's no migration system and you don't need one.
- **theme.txt**: see `CustomTheme.HEADER` / the wiki's Custom Themes page.
- **.sol saves**: Haxe serialization. `o...g` object, `b...h` map, `a...h` array, `y<len>:<urlencoded>` string, `R<n>` back-reference to the n-th string, `i`/`d`/`z`/`t`/`f`/`n` numbers/bools/null. `save_file.gd`'s header has the node format.
- **charts**: see `chart.gd`'s header.
- **.fnftheme**: a zip of a theme folder.
- **friends server API**: see the top of `server/worker.js`.

---

## releasing (versions are GREATER.LESSER.SMALL)

- **GREATER**: big/breaking. **LESSER** (X.Y.0): feature update, gets an installer. **SMALL** (X.Y.Z): fixes, GitHub only (commit + tag, no build).
- `bash tools/version.sh lesser` (or small / greater / set X.Y.Z): bumps `config/version` in project.godot, the only place the version lives.
- add a `## vX.Y.Z (date)` section to `CHANGELOG.md`.
- `bash tools/release.sh`: makes `~/Desktop/FNF Launcher vX.Y.Z/` with `COMMIT_MESSAGE_vX.Y.Z.txt` (from the changelog section) and, for X.Y.0, builds `FNF-Launcher-Installer.sh` (a bash script with the project appended as a tar.gz) + the SteamOS `.desktop`.
- upload the installer to a GitHub release (tag `vX.Y.Z`) and itch.io.
- **windows beta**: bump its `project.godot` **and** `windows_setup/project.godot`, `setup.gd`'s `VERSION`, and the `file_version`/`product_version` in both `export_presets.cfg`. then `bash tools/build_windows.sh`. for the in-app updater to see it, publish a GitHub release tagged **`windows-vX.Y.Z`** with **`FNF-Launcher-Windows-Beta-Setup.exe`** attached (exact name).
- the friends server is deployed by whoever runs one (it's in the wiki: Friends Page). if you change `worker.js`, say so in the changelog so people redeploy.

---

## testing (how i actually do it)

there's no unit test framework. there's `_demo/` (gitignored), where i keep **harness scenes**: a boot scene adds a driver Node to the root, then switches to `main.tscn`; the driver waits for main, pokes it (calls its functions, sends fake input with `Input.parse_input_event`), takes screenshots with `get_viewport().get_texture().get_image().save_png()`, prints PASS/FAIL, and quits. run them with:

```
godot --path . --audio-driver Dummy --resolution 1280x720 res://_demo/<harness>.tscn
```

rules i learned the hard way:
- **back up `~/.local/share/godot/app_userdata/FNF Launcher/` before a test and restore it after.** the launcher writes library.json etc. like normal. also delete the test's themes/backups folders after.
- **`--audio-driver Dummy`**. trust me. the jumpscare egg exists.
- **turn discord rich presence off in your test copy of the settings** (or your real one before testing). otherwise every test run tells your discord you're "playing FNF Launcher", and a killed test never clears it. ask me how i know. (fix: restart vesktop/discord.)
- **godot compiles scripts lazily.** a script with a parse error doesn't complain until something uses it. `_demo/compile_all.tscn` loads every script so errors show up. run it before shipping.
- **type inference**: `var x := some_dict.key` or `var x := untyped_array[0]` is a **parse error** in 4.x. use `var x: int = ...`. this is 90% of my "why won't it start" moments.
- **`pkill -f` / `pgrep -f` match your own shell** if the pattern appears anywhere in the command line. i killed my own terminal like six times. use a script file or the PID.
- godot's `--` user args: the AppImage swallows the `--`, so check `OS.get_cmdline_args()` too.
- `Time.get_datetime_*_from_unix_time` is UTC.
- testing windows stuff without windows: run the exported exe with GE-Proton's `proton waitforexitandrun` and `STEAM_COMPAT_DATA_PATH` pointing at a scratch prefix, then `--selftest`. kill the scratch prefix's wineserver after (`WINEPREFIX=... wineserver -k`), or it sits there forever.
- headless game testing under linux: `gamescope --backend headless` + `gamescopectl screenshot` + `xdotool` on gamescope's Xwayland display. that's how i poked at Tricky without windows popping up on my screen.
- Godot's Movie Maker (`--write-movie out.avi` + an `override.cfg` for 1080p) is how the showcase videos were recorded.

---

## known issues / cursed knowledge

- **The Full-Ass Tricky Mod** freezes on its own "Done!" loading screen under Proton (GE and Valve both). not a crash: the main thread is in lime's frame limiter, the game just never moves on to the title screen. not audio, not input, not focus, not the capitalisation thing. **unfixed.** if you figure it out you're my hero. full story in the v1.7.0 devlog.
- FNF mods built with old lime sometimes eat 2.7 GB of RAM caching art at startup. on a handheld with 12 GB shared with the GPU, that's a lot.
- Steam's Game Mode is gamescope already: per-mod gamescope options don't apply there, and native file dialogs don't exist there (the launcher uses Godot's own dialog in game mode).
- some mods ship the same base-game songs; the jukebox dedupes by title + file size.
- the friends server trusts nothing: it only stores GameBanana links (so a status can't point launchers at random downloads) and only zips under 1.5 MB for themes.

---

## legal-ish

- our code: GPLv3, see `LICENSE`.
- FunkinCrew's assets (font, menu music, sounds, images): **not ours, not shipped**, downloaded from their official repo at install time. keep it that way.
- the Xbox / PS3 / Newgrounds achievement sounds are downloaded on first pick, never shipped. Steam's is read from the user's Steam install.
- example theme fonts are SIL OFL (licence file next to each font). keep the licence with the font if you copy one.
- don't bundle anyone's fan-made stuff (chromatics, mods, art) without permission. credit is not permission.

---

ok that's everything i can think of. my break ended like 20 minutes ago. if something's missing, open an issue and i'll add it when i'm, again, totally not at work.

– joey / orang entertainment 🍊

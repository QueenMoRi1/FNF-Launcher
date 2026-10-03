# Changelog

Versions are GREATER.LESSER.SMALL:
- GREATER: big or breaking changes
- LESSER: a new feature update
- SMALL: smaller additions and fixes on top of a feature update

Only GREATER.LESSER versions (X.Y.0) get builds: an installer on GitHub Releases
and itch.io. SMALL versions are GitHub-only (a commit and a tag). People on the
GitHub update channel get them, and stable-channel users get them in the next build.

Bump with `bash tools/version.sh small` (or lesser / greater), add a section
here, then run `bash tools/release.sh`.

## v1.7.0 (2026-10-02)

Mod tools, play mode upgrades and Funkin' Wrapped.

- **Mod updates:** the launcher checks GameBanana for newer uploads of your
  mods (twice a day, or on demand) and shows ⬆ UPDATE next to them. UPDATE NOW
  swaps in the newest download, keeps your saves, and keeps the old version
  in `.old/`.
- **Save backups:** a mod's saves are backed up every time it starts (last 10
  kept, duplicates skipped). Restore any of them from the edit dialog.
- **Same keybinds everywhere:** pick your four note keys once (Settings >
  KEYBINDS) and they're written into every Psych / Kade Engine mod's saved
  controls before it starts. The save writer keeps every file byte for byte
  identical apart from the keys (tested on every save on my machine).
- **Health check:** finds the usual reasons a mod won't start (missing exe or
  lime.ndll, wrong exe, wrong capitals in file names, missing Proton or
  runtime, full disk...) in plain English, with fixes for some. Also guesses
  the engine.
- **Per-mod Proton & performance:** pick any installed Proton per mod
  (GE-Proton, Valve Proton, Experimental), run it in gamescope with
  fullscreen and an FPS limit, and set environment variables.
- **Play mode:** after holding M, a setup card picks the side (BF or the
  opponent), the speed (0.5x-2.0x) and the difficulty. Best runs are saved
  and shown on the leaderboard (PLAY MODE BESTS).
- **Funkin' Wrapped:** your year in FNF mods as a slideshow: time played, top
  mods, jukebox songs on repeat, fun facts. Save any card as an image.
- **Theme gallery:** share your custom themes and install other people's,
  hosted on your friends server (update `server/worker.js` to get it).
- **10 new achievements** (40 in all): Muscle Memory, Time Traveller,
  Check-Up, Patch Notes, That's a Wrap, Window Shopping, and four secret ones
  in play mode.
- The edit dialog scrolls now, so it fits any screen.
- Launching builds the command as a list, so names with spaces or quotes
  can't break it. Launch options can quote part of a word (`VAR="a b"`).
- Fixed: backup and Wrapped times were in UTC instead of your time zone.
- Known issue: The Full-Ass Tricky Mod freezes on its "Done!" loading screen
  under Proton (GE and Valve). Investigated, not fixed. Details in the devlog.

## v1.6.0 (2026-10-02)

Ultimate customizability.

- **26 new example themes** (28 in all): Neon Arcade, Spooky Month, Notebook,
  Terminal, Pocket Green, Sunset Drive, High Contrast, Winter Wonderland,
  Cherry Blossom, Deep Sea, Lava, Rainy Day, Starry Night, Candy Shop, Autumn
  Leaves, Valentine, Forest Camp, Blueprint, Retro Desktop, Bubblegum Pop,
  Midnight Jazz, Monochrome, Ocean Breeze, Cyber Grid, Golden Hour and Party
  Time. Their fonts are open-licensed (SIL OFL, licence included). New example
  themes now arrive with updates, and deleted ones stay deleted.
- **Animated backgrounds:** snow, bubbles, notes, stars, confetti, leaves,
  petals, bats, hearts, rain, embers or fireflies, with colour, amount, speed
  and size. Themes can also have a gradient background and pattern opacity.
- **Themes can change the intro** (skip it, credits, title words, logo,
  quips) **and the chart viewer** (arrow colours, visualizer colours,
  kaleidoscope, beat shake, ribbons, effect strength).
- **Themes can set** a mouse cursor, the achievement sound, popup position
  and colour, the UI size, and a season.
- **Theme mode:** pick yourself, random each launch, theme of the day, or
  seasonal.
- **Seasonal extras** for the plain skins (Settings, on by default): snow and
  lights in December, confetti at New Year, bats in October, hearts for
  Valentine's, green for St Patrick's, and an April Fools' gag.
- **UI size** setting (80-150%).
- **Game list:** favourites (★, always on top), hidden mods, sorting by name,
  recently played or most played, launch options, and custom cover art and
  name colour per mod.
- **Theme editor:** controls for all of the above. It now always uses the
  launcher's font, so wide theme fonts can't push it off screen. The "Darken"
  label no longer squashes into one letter per line.
- **Hint bar:** shrinks its text to fit when a theme's font is wide.
- **New easter eggs:** `artificial` (a note from Joey) and `chromatics` (a piano
  sung by Boyfriend, with his real voice from FunkinCrew's Tutorial vocals;
  his sprite and voice are downloaded from FunkinCrew the first time). Two new
  secret achievements, 30 in all.

## v1.5.1 (2026-10-02)

Bug fixes from a full sweep: every screen in every skin and theme.

- Steam skin: long mod titles no longer run under the jukebox widget. The
  title stops short of it at any screen width. This has been a bug since the
  jukebox moved under the clock in v1.4.0.
- Themes: text on buttons now picks black or white, whichever is readable,
  when a theme sets button colours. Before, highlighted rows could be yellow
  on orange (Orang Juice) or dark on blue (Midnight).
- Orang Juice example theme: dropped the logo, which sat on top of the
  Freeplay game list.

## v1.5.0 (2026-10-02)

Custom themes.

Custom themes (new)
- Themes are a folder in ~/.local/share/fnf-launcher/themes/ with a
  plain "key: value" theme.txt and its files (scripts/themes/). They can set:
  - colours: accent, text, popups, buttons, selected button, background
  - a background image or .ogv video, a tiled pattern, and dimming
  - mod art on or off
  - a logo, a font, menu music (replaces Freaky Menu) and menu sounds
  - the layout underneath: Freeplay, Steam or Xbox 360
- Layout: move, resize or hide parts of the menu (game list/row, header,
  clock, blades, art & details, jukebox, hint bar, version, logo). Shifts
  are in % of the screen, so themes fit any resolution.
- Theme editor (Settings > THEME > NEW / EDIT):
  - colour pickers and file slots
  - drag and drop files onto the window; it asks where they go if there's
    more than one choice
  - MOVE THINGS mode: drag to move, drag the corner or scroll to resize,
    right-click to reset, tick boxes to hide
  - every change saves and shows immediately
- Sharing: EXPORT saves a .fnftheme (a zip). Drop one on the window, or use
  IMPORT, to install it. Only theme files, images, fonts, sounds and .ogv
  are taken, and nothing can be written outside the theme's folder.
- Two example themes: Orang Juice and Midnight.
- Skins now expose their movable parts and background layers (SkinView.parts,
  background_nodes, mod_art_nodes) for themes.
- New achievement: Interior Designer (open the theme editor). 28 in total.

Achievement sounds
- New unlock sound: Newgrounds, the medal chime FNF plays when you earn a
  Newgrounds medal (NGFadeIn from FunkinCrew's assets, pinned to a commit).
  Like the Xbox 360 and PS3 sounds, it's downloaded on first use and cached.
- Downloaded sounds keep their own file type (.wav or .ogg).

## v1.4.1 (2026-10-01)

Secret chart viewer play mode, an update notifier, and fixes.

Chart viewer
- Secret play mode: hold M for 5 seconds in the chart viewer. The song
  restarts with FNF's 3, 2, 1, GO countdown (sounds and Ready/Set/Go images),
  shows the D F J K keys, and you play BF's side:
  - Psych Engine timing windows (sick/good/bad/shit/miss) and ghost tapping
  - score, misses, accuracy and combo
  - a results card with a rank at the end
  Scoring lives in scripts/play_mode.gd. The countdown assets are FunkinCrew's
  and are fetched by the installer like the other FNF assets.
- The chart viewer's arrow drawing (ChartViewer.draw_arrow) and the
  broken-difficulty fallback (Chart.load_readable) are now shared helpers.

Achievements
- New secret achievement "Off the Clock" for the play mode (27 in total,
  11 of them secret).

Update notifier (new)
- On first launch the launcher asks how you want updates. You can change
  it later in Settings → UPDATES, with CHECK NOW:
  - GitHub (newest first): any new commit on main; updating downloads the
    code, builds an installer on the spot, and installs it
  - Itch (stable): only new released versions (GitHub Releases, the same
    build as itch.io); updating installs that release's installer, or opens
    the itch page
  - Off
- It checks once per launch and shows what's new. Updating runs in the
  background (tools/update.sh, scripts/updater.gd) and keeps games, saves
  and settings, then offers to restart.
- The settings popup now scrolls, so it fits any screen.
- build_installer.sh no longer needs ffmpeg (it falls back to Pillow, or
  copies the icon as is), so on-the-spot builds work on SteamOS.


## v1.4.0 (2026-10-01)

Chart viewer, leaderboard, achievements, Xbox 360 skin, new easter eggs,
and a lighter installer.

Chart viewer (new, F6 / L3)
- Plays any song from your mods in full (Inst + Voices) and scrolls its
  chart with every note auto-hit, with the opponent on the left and the
  player on the right.
- scripts/chart.gd reads:
  - classic charts (base game before v0.3, Psych, Kade, most older mods)
  - Psych Engine 1.0 charts
  - base game v0.3+ "V-Slice" (-chart.json + -metadata.json)
  - Codename Engine charts
- Also: BPM changes, sustains, special/hurt notes, split vocal tracks,
  and NUL-padded or UTF-16 chart files. Dialogue/event/meta JSON is
  skipped.
- PS3-CD-player-style visualizer (scripts/chart_viewer.gd, shaders/):
  - XMB-style glowing ribbons that cycle colour
  - a spinning rainbow disc inside a live spectrum ring
  - sparkle bursts when notes hit
  - zoom punch and RGB split on the beat
  - kaleidoscope during busy sections
- Controls:
  - up/down: change song (every song from every mod, starting with the
    selected one)
  - left/right: seek 5 s (repeats while held)
  - Q/W or LB/RB: change difficulty
  - Space/A: pause
  - Esc/B: back
  - plays the next song automatically when one ends
- The jukebox pauses while it's open and resumes after.
- Charts with junk values are read defensively. Text where a number or
  true/false belongs, null sections, a BPM of zero and so on now fall back
  to sane defaults instead of breaking the whole chart.
- If a mod ships a broken difficulty, the viewer falls back to the next one
  that reads (fixes Whitty's Remorse, whose hard chart is corrupt).

Leaderboard (new, F7 / Friends page)
- Ranks your mods by total score: the sum of the best score of every song
  you've played (each song once, at its best difficulty). Pick a mod to see
  each song's best score and difficulty.
- scripts/scores.gd reads the high scores the mods save themselves: the
  "songScores" map in HaxeFlixel .sol save files (Haxe-serialized) under
  AppData in each mod's Wine prefix. Week scores are left out.
- Rows follow the active skin's button colours, so they're readable in
  every skin. Desktop-only for now.

Achievements (new, F8 / Friends page)
- 26 achievements (scripts/achievements.gd, new "Achievements" autoload):
  - library: first mod, adding a mod, 10 mods, installing a download
  - playing: launching a mod, launching between midnight and 4 AM
  - features: editing a mod, opening the chart viewer, listening to a
    whole song, skipping 10 jukebox tracks, trying every skin, checking the
    leaderboard, a 1,000,000 total in one mod, the friends page,
    exporting a collection
  - a secret one for every easter egg: fafa, deltarune, gooseworx, jim,
    JIM, compost, yearofthelinuxdesktop ("Cope"), the idle popup, and its
    "Maybe" and "Kill him" answers
  - Completionist for unlocking all the others
- Secret achievements show as "???" with a vague hint until unlocked.
- Unlocks show an "Achievement unlocked" toast at the top of the screen.
  The achievements screen lists unlocked ones first (newest on top) with
  their local unlock date.
- The unlock sound can be picked in Settings, with a preview:
  - FNF: the menu confirm sound
  - Xbox 360 and PS3: downloaded on first use from pinned PCSX2 commits and
    cached; not shipped
  - Steam: loaded from the Steam install
  Falls back to the FNF sound, with a message, if one isn't available.
- Saved in achievements.json in the launcher's data folder.

Xbox 360 skin (new)
- New "XBOX 360" skin (scripts/skins/blades_view.gd) styled after the 2005
  Blades dashboard:
  - stacked blades on the left
  - a glossy white games list with the green highlight
  - the mod's art in a white frame
  - dark, green-edged popups and jukebox widget
- The real Blades wallpaper is downloaded from the Internet Archive on
  first use and cached. It isn't shipped with the launcher.

Easter eggs
- "jim": plays "I'm Jim and I Live in the Bin" (Caddicarus) on the
  jukebox, then carries on with the playlist (new Music.play_now()).
- "JIM" in all caps: plays the video full-screen instead.
- "compost": plays "Hi I'm Compost" (Caddicarus) full-screen.
- 42 more intro quips (84 total), about the new features plus general FNF
  and Linux jokes.
- "yearofthelinuxdesktop": unlocks the secret "Cope" achievement. Cheat
  codes can now be up to 32 letters long.
- Cheat codes keep track of capital letters. Videos share one player that
  pauses the music and fades back afterwards.

Launcher
- Version number (v1.4.0) in the bottom-right corner;
  application/config/version set in project.godot.
- New "charts" input action: F6 / L3 (left stick click), and
  "leaderboard": F7 and "achievements": F8 (the hint bar shows F7 SCORES
  and F8 AWARDS).
- Music.load_stream() opens a song file without playing it.
- Click a game to select it, click it again to play, and drag to
  scroll (SkinView.item_at() tells main.gd which game was clicked).
  Skin controls no longer swallow mouse clicks.
- Steam skin: the jukebox widget now sits under the clock instead of
  covering the game capsules and the version number (new
  SkinView.widget_top).

Downloads
- Mods are unpacked with whichever 7-Zip is available (7z, 7za or 7zz), or
  the standalone 7zz the installer puts in the launcher's data folder,
  because SteamOS doesn't ship 7-Zip. Clear error if none is found.

Installer
- Downloads the official standalone 7-Zip (7zz) when the system doesn't
  have one.
- No longer needs git, unzip or 7z: the FNF assets are fetched over plain
  HTTPS, and Godot is unpacked with Python's zipfile.
- Uninstall also removes the bundled 7-Zip.
- New "Install FNF Launcher.desktop" for SteamOS/Steam Deck desktop mode:
  it runs the installer next to it, or downloads the latest one from
  GitHub Releases.
- build_installer.sh leaves the wiki, the showcase-recording folder and
  the unpublished Android build files out of the installer.

Versioning
- Versions are MAJOR.MINOR.PATCH, with one source of truth:
  application/config/version in project.godot.
- tools/version.sh shows or bumps it (patch / minor / major / set X.Y.Z).
- tools/release.sh builds the installer and makes the release folder with
  the installer, the SteamOS .desktop file, and a commit message taken from
  this version's section of the new CHANGELOG.md.
- The installer has the version stamped in at build time
  (FNF-Launcher-Installer.sh --version).

Docs
- README: link to the wiki, plus SteamOS/Steam Deck, chart viewer,
  leaderboard and achievements sections, and the new files in the code layout.
- .gitignore: Godot cache, borrowed FNF assets, dist/, the demo-recording
  folder.
- TLS certificate bundle (assets/ca-certificates.crt) used for HTTPS, so
  GameBanana works even where the system certificates are outdated.
- Godot 4 .uid files for every script.

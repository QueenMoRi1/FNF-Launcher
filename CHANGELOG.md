# Changelog

Versions are MAJOR.MINOR.PATCH: MAJOR for big or breaking changes, MINOR for new
features, PATCH for bug fixes only. Bump with `bash tools/version.sh minor` (or patch/major),
add a section here, then run `bash tools/release.sh`.

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

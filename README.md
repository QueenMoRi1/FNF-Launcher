# FNF Launcher

A Friday Night Funkin' mod launcher for Linux, styled like FNF itself. Drop in Windows FNF mods (or download them from inside the launcher) and play them through GE-Proton, with a controller-friendly menu, an instrumental jukebox, Steam friends integration and Discord Rich Presence.

📖 **[Read the Wiki](https://github.com/QueenMoRi1/FNF-Launcher/wiki)** for guides, customization and troubleshooting.

Built with Godot 4.7 for handheld and couch PCs. It was made on a ROG Ally running Bazzite, but works on any x86_64 Linux with Steam.

## Features

- **An FNF-style menu.**
  - A beat-synced intro like the real game, with random quips.
  - A Freeplay-style game list written in the bold Alphabet font.
  - Each game's background is tinted to match its icon.
- **Automatic game detection.** Put each FNF game in its own folder under `~/Games/FNF`.
  - The launcher finds the `.exe` and skips uninstallers and crash handlers.
  - It pulls the game's icon out of the `.exe`.
  - You can rename any entry.
- **GE-Proton launching.** Games run the same way Steam runs them: Steam Linux Runtime 4 → GE-Proton → game. Each game gets its own Wine prefix and a log file.
- **Jukebox.** It finds the instrumentals (`Inst.ogg`) inside every installed mod and plays them shuffled, with a now-playing widget for skip, pause and time left.
- **Chart viewer (F6 / L3).** Plays any song from your mods in full, instrumental and vocals, and scrolls its chart with every note auto-hit, over a PS3-CD-player-style visualizer.
- **Leaderboard (F7).** Your mods ranked by total score (the best score of every song you've played), read straight from each mod's own save file, with a per-song breakdown.
- **Achievements (F8).** 26 of them, including a secret one for every easter egg, shown as ??? with a vague hint until found. Unlocks pop up with your pick of sound: FNF, Xbox 360, Steam or PS3.
- **Collection lists.** Export your whole library as a `.txt` of download links, then import it on another PC or share it with a friend to install everything in one go.
- **GameBanana integration.**
  - Every game is matched to its GameBanana page automatically, and that page's art becomes the menu background. You can pick the right page by hand if the guess is wrong.
  - **Download queue:** paste GameBanana links or direct `.zip`/`.7z`/`.rar` links. They download and install in the background while you keep browsing.
- **Skins:** **Freeplay** (default) or **Steam** (a Big Picture-style layout that uses Steam's own UI sounds).
- **Friends page.** See which Steam friends are also on FNF Launcher and what they're playing, and grab their mod with one button. This needs a free server you deploy yourself; see [Friends page](#friends-page).
- **Discord Rich Presence.** Shows "Playing <mod>" with the mod's art and a **Download on GameBanana** button.
- **Full controller support**, plus keyboard and mouse.
- **Easter eggs.** A few are hidden; see the spoiler below.

## Install

### Graphical installer (recommended)

1. Download `FNF-Launcher-Installer.sh` from [itch.io](https://queenmori1.itch.io/fnf-launcher) or the [Releases](../../releases) page.
2. Double-click it. If your file manager opens it as text instead, right-click → Properties → enable **Is executable**, then try again.
3. A small window gets things ready, then the FNF-styled installer opens. Choose your options and press **INSTALL**.

The installer:
- installs the launcher to `~/.local/share/fnf-launcher`
- downloads the FNF menu assets from [FunkinCrew/Funkin.assets](https://github.com/FunkinCrew/Funkin.assets)
- downloads [Godot 4.7.2](https://godotengine.org) and [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom), checking both against their published checksums
- offers to install Steam Linux Runtime 4.0 through Steam
- creates `~/Games/FNF` and an app-menu entry
- adds the launcher to Steam with custom covers, a banner and a logo, so it looks right in Game Mode

Running it again updates the launcher and keeps your games, saves and settings.

### SteamOS / Steam Deck

In Desktop Mode, download **`Install FNF Launcher.desktop`** and double-click it. If `FNF-Launcher-Installer.sh` is in the same folder, it runs that; otherwise it downloads the latest installer from this repo's Releases. Then switch back to Game Mode: the installer adds FNF Launcher to Steam with its artwork.

### Text installer

```sh
bash FNF-Launcher-Installer.sh --cli          # asks before optional steps
bash FNF-Launcher-Installer.sh --cli --yes    # no questions
bash FNF-Launcher-Installer.sh --uninstall    # keeps your games and saves
```

### Requirements

- x86_64 Linux with **Steam** installed
- `curl`, `tar`, `xz`, `python3` (SteamOS and Bazzite already have these). If 7-Zip isn't installed, the installer downloads the official standalone build for the launcher to use.
- Optional: `zenity` for the graphical installer, and `python3-pillow` for the Steam artwork

## Adding games

- **Download them:** press **F4** (or **R3** on a controller), paste a link such as `https://gamebanana.com/mods/523551`, and press **ADD TO QUEUE**. Add as many as you like, then close the window; the downloads keep going. Progress shows in the bottom-left corner.
- **From a file:** in the same window, **FROM FILE...** installs a `.zip`, `.7z` or `.rar` you already downloaded.
- **By hand:** extract the mod into its own folder under `~/Games/FNF/` and press **F5** to rescan.

Links to sites with download pages (Mediafire, Google Drive and so on) can't be downloaded directly. Download those in your browser and use **FROM FILE...**.

### Sharing your collection

In the Downloads window (**F4**):
- **EXPORT LIST...** saves a `.txt` with one download link per game (its GameBanana page, or the link you installed it from).
- **IMPORT LIST...** reads a list like that and queues every game you don't already have. Use it to set up a new PC, or to grab a friend's whole collection.

The list is plain text, so you can edit it by hand. Lines starting with `#` are ignored:

```
https://gamebanana.com/mods/523551   # FNF Soft
https://gamebanana.com/mods/44683    # Arcade Showdown - VS. Kapi
```

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | Arrow keys / mouse wheel | D-pad / left stick |
| Play | Enter | A |
| Edit game (name, exe, icon, GameBanana page) | F2 | Y |
| Friends | F3 | Start |
| Downloads | F4 | R3 |
| Rescan games | F5 | X |
| Settings / back | Esc | B |
| Pause music | Space | Select |
| Previous / next song | Q / W | LB / RB |

The launcher ignores all input while a game is running or while its window isn't focused, so it never reacts to button presses meant for the game.

## Settings

Open Settings with **Esc** or **B**:

- **Games folder:** change it, open it, rescan, or download a game.
- **Skin:** Freeplay or Steam.
- **Discord Rich Presence:** turn it on and paste your Application ID (see below).
- **Friends server:** the URL of your friends server, and whether to share your status.
- **GE-Proton info and logs:** each game's output goes to a log you can open from here, which helps when a mod won't start.

### Discord Rich Presence

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications) → **New Application** and name it `Friday Night Funkin'`. Friends see "Playing <that name>".
2. Copy its **Application ID** into **Settings → Discord Rich Presence**, switch it **ON** and press **SAVE**.
3. Optional: under **Rich Presence → Art Assets**, upload an image named `logo`. It shows while you're in the menu.

Discord doesn't show Rich Presence buttons on your own profile, but your friends will see them.

### Friends page

The friends page reads your Steam friends list from your local Steam install (no login or API key needed). To know who's online, it needs a small shared server. `server/worker.js` is a ready-made [Cloudflare Worker](https://workers.cloudflare.com) that fits in the free tier:

1. In the Cloudflare dashboard: **Storage & Databases → KV → Create** a namespace called `fnf_status`.
2. **Workers & Pages → Create → Worker**, deploy it, then **Edit code**. Paste in `server/worker.js` and deploy again.
3. In the Worker's **Settings → Bindings → Add → KV namespace**, set the variable name to `STATUS` and the namespace to `fnf_status`.
4. Paste the `https://….workers.dev` URL into **Settings → Friends server** in the launcher, and give the same URL to your friends.

The server only accepts GameBanana links, so a friend's status can never point your launcher at an arbitrary download. There's no login, so statuses aren't verified. That's fine among friends, but keep it in mind.

## Troubleshooting

- **"This launcher requires GE-Proton":** install a numbered x86_64 GE-Proton such as `GE-Proton11-7` with ProtonPlus or ProtonUp-Qt, or run the installer again.
  - Avoid ProtonPlus's "Proton-GE Latest" option. It can install the ARM build, which doesn't run on PC; the launcher detects and ignores it.
- **A game won't start:** check **Settings → OPEN LOGS**. The first launch of each game takes a little longer while its Wine prefix is set up.
- **Steam artwork doesn't show:** Steam only loads custom artwork when it starts, so restart Steam. To add the small list icon, go to **Properties** and pick `~/.local/share/fnf-launcher/app/icon.png`.

<details>
<summary><b>Easter eggs (spoilers!)</b></summary>

Type these anywhere in the launcher:

- `fafa`: you'll see.
- `deltarune`: opens DELTARUNE if you have it on Steam. If you don't... Kris hears about it.
- `gooseworx`: plays *No More Tears*, then sends you back to the menu.

Also, don't leave the menu alone for an hour. It gets lonely.

</details>

## Development

Clone it with `git clone https://github.com/QueenMoRi1/FNF-Launcher.git`, then open the folder in Godot 4.7 or run it directly:

```sh
godot --path /path/to/fnf-launcher
```

The FNF menu assets aren't in this repo (see [Credits](#credits--licensing)). To get them for development, fetch them the same way the installer does:

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/FunkinCrew/Funkin.assets /tmp/fnf-assets
git -C /tmp/fnf-assets sparse-checkout set --no-cone /fonts/vcr.ttf /preload/images/menuBG.png \
  /preload/images/menuBGMagenta.png /preload/images/menuDesat.png /preload/images/alphabet.png \
  /preload/images/alphabet.xml /preload/images/logoBumpin.png /preload/images/logoBumpin.xml \
  /preload/images/gfDanceTitle.png /preload/images/gfDanceTitle.xml /preload/images/icons/icon-face.png \
  /preload/music/freakyMenu/freakyMenu.ogg /preload/sounds/scrollMenu.ogg \
  /preload/sounds/confirmMenu.ogg /preload/sounds/cancelMenu.ogg
mkdir -p assets/funkin && find /tmp/fnf-assets -type f -not -path '*/.git/*' -exec cp {} assets/funkin/ \;
```

Build the installer with:

```sh
bash tools/build_installer.sh    # -> dist/FNF-Launcher-Installer.sh
```

### Project layout

| Path | What it is |
|---|---|
| `scenes/intro.tscn` | Beat-synced intro (main scene) |
| `scenes/main.tscn` | The launcher menu |
| `scenes/installer.tscn` | The graphical installer screen |
| `scripts/main.gd` | Menu controller: input, overlays, launching, settings |
| `scripts/skins/` | Freeplay and Steam skins (`SkinView` base class) |
| `scripts/library.gd` | Game scanning, exe and instrumental detection, `library.json` |
| `scripts/proton.gd` | GE-Proton detection and launching through Steam Linux Runtime |
| `scripts/downloader.gd` | Download queue: fetch, 7z unpack, install |
| `scripts/gamebanana.gd` | GameBanana search, matching and art cache |
| `scripts/friends_service.gd`, `scripts/steam_friends.gd` | Friends page and local Steam friends parsing |
| `scripts/music.gd` | Jukebox autoload |
| `scripts/chart.gd`, `chart_viewer.gd`, `shaders/` | Chart reading, and the chart viewer and its visualizer |
| `scripts/achievements.gd` | Achievements autoload: the list, unlocking, saving, the toast and the unlock sounds |
| `scripts/scores.gd` | Reads high scores from mods' save files (Haxe-serialized `.sol`) for the leaderboard |
| `scripts/discord.gd`, `tools/discord_rpc.py` | Discord Rich Presence bridge (Python standard library only) |
| `scripts/cheats.gd`, `scripts/xp_popup.gd` | Easter eggs |
| `scripts/icon_loader.gd` | `.ico` and PE (exe) icon extraction |
| `server/worker.js` | Friends server (Cloudflare Worker) |
| `tools/installer_header.sh`, `tools/build_installer.sh` | The installer and its build script |
| `tools/make_steam_art.py` | Generates the Steam library artwork |

## Credits & licensing

- **Friday Night Funkin'** by [The Funkin' Crew](https://github.com/FunkinCrew/funkin). The menu art, music, fonts and sprites the launcher uses come from [Funkin.assets](https://github.com/FunkinCrew/Funkin.assets). They're downloaded to your PC at install time and aren't included in this repo, because they're not freely redistributable.
- **[GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom)** by GloriousEggroll, **[Godot Engine](https://godotengine.org)**, and Valve's Steam Linux Runtime.
- Mod pages, art and downloads come from **[GameBanana](https://gamebanana.com)**.
- FNF Launcher is a fan project. It isn't affiliated with The Funkin' Crew, Valve, Discord or GameBanana.

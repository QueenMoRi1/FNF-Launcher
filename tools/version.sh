#!/usr/bin/env bash
# The launcher's version lives in one place: application/config/version in
# project.godot. Everything else (the corner label, the installer, the release
# folder, the commit message) reads it from there.
#
#   bash tools/version.sh              show the version
#   bash tools/version.sh small        1.4.1 -> 1.4.2   smaller additions and fixes
#   bash tools/version.sh lesser       1.4.1 -> 1.5.0   a new feature update
#   bash tools/version.sh greater      1.4.1 -> 2.0.0   big or breaking changes
#   bash tools/version.sh set 1.5.0    set it exactly
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/project.godot"
current=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$FILE")
[ -n "$current" ] || { echo "No config/version in project.godot" >&2; exit 1; }
IFS=. read -r major minor patch <<<"$current"
case "${1:-}" in
	"") echo "$current"; exit 0 ;;
	small | patch) patch=$((patch + 1)) ;;
	lesser | minor) minor=$((minor + 1)); patch=0 ;;
	greater | major) major=$((major + 1)); minor=0; patch=0 ;;
	set) [[ "${2:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Use: set X.Y.Z" >&2; exit 1; }
		IFS=. read -r major minor patch <<<"$2" ;;
	*) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
new="$major.$minor.$patch"
sed -i "s/^config\/version=\".*\"$/config\/version=\"$new\"/" "$FILE"
echo "$current -> $new"
grep -q "^## v$new" "$ROOT/CHANGELOG.md" 2>/dev/null || echo "Now add a '## v$new' section to CHANGELOG.md."

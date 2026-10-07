#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version> [app-path] [output-directory]" >&2
  exit 64
}

[[ $# -ge 1 && $# -le 3 ]] || usage

version="$1"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid package version: $version" >&2
  exit 64
}

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
app_path="${2:-$project_root/build/macos/Build/Products/Release/DComicReborn.app}"
output_directory="${3:-$project_root/build/macos/packages}"
archive_base="DComicReborn-${version}-macos-universal"
zip_path="$output_directory/$archive_base.zip"
dmg_path="$output_directory/$archive_base.dmg"

[[ -d "$app_path" ]] || {
  echo "macOS app bundle not found: $app_path" >&2
  exit 1
}
[[ -f "$app_path/Contents/Info.plist" ]] || {
  echo "App bundle Info.plist not found: $app_path/Contents/Info.plist" >&2
  exit 1
}

bundle_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_path/Contents/Info.plist")"
executable_path="$app_path/Contents/MacOS/$bundle_executable"
[[ -x "$executable_path" ]] || {
  echo "Bundle executable is missing or not executable: $executable_path" >&2
  exit 1
}

validated_binary_count=0
while IFS= read -r -d '' binary; do
  if binary_architectures="$(lipo -archs "$binary" 2>/dev/null)"; then
    for architecture in arm64 x86_64; do
      [[ " $binary_architectures " == *" $architecture "* ]] || {
        echo "Mach-O binary is not universal: $binary (architectures: $binary_architectures)" >&2
        exit 1
      }
    done
    echo "Validated universal Mach-O binary: ${binary#"$app_path"/} ($binary_architectures)"
    ((validated_binary_count += 1))
  fi
done < <(find "$app_path/Contents" -type f -print0)
((validated_binary_count > 0)) || {
  echo "No Mach-O binaries were found in the app bundle." >&2
  exit 1
}

# Use ad-hoc signing so packaging never depends on a Developer ID identity.
codesign --force --deep --sign - --timestamp=none --preserve-metadata=entitlements,requirements,flags "$app_path"
codesign --verify --deep --strict "$app_path"

mkdir -p "$output_directory"
rm -f "$zip_path" "$dmg_path"

workspace="$(mktemp -d "${TMPDIR:-/tmp}/dcomic-macos-package.XXXXXX")"
dmg_mount="$workspace/mount"
dmg_mounted=false
cleanup() {
  if [[ "$dmg_mounted" == true ]]; then
    hdiutil detach "$dmg_mount" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$workspace"
}
trap cleanup EXIT

zip_stage="$workspace/zip"
dmg_stage="$workspace/dmg"
zip_extract="$workspace/zip-extract"
mkdir -p "$zip_stage" "$dmg_stage" "$zip_extract" "$dmg_mount"

# ditto retains executable modes, bundle symlinks, extended attributes, and resource forks.
ditto "$app_path" "$zip_stage/DComicReborn.app"
ditto -c -k --sequesterRsrc --keepParent "$zip_stage/DComicReborn.app" "$zip_path"

ditto -x -k "$zip_path" "$zip_extract"
extracted_app="$zip_extract/DComicReborn.app"
[[ -x "$extracted_app/Contents/MacOS/$bundle_executable" ]] || {
  echo "ZIP did not preserve the bundle executable permission." >&2
  exit 1
}
while IFS= read -r -d '' source_link; do
  relative_link="${source_link#"$app_path"/}"
  extracted_link="$extracted_app/$relative_link"
  [[ -L "$extracted_link" && "$(readlink "$extracted_link")" == "$(readlink "$source_link")" ]] || {
    echo "ZIP did not preserve bundle symlink: $relative_link" >&2
    exit 1
  }
done < <(find "$app_path" -type l -print0)

ditto "$app_path" "$dmg_stage/DComicReborn.app"
ln -s /Applications "$dmg_stage/Applications"
hdiutil create \
  -volname "DComicReborn $version" \
  -srcfolder "$dmg_stage" \
  -format UDZO \
  -ov \
  "$dmg_path" >/dev/null
hdiutil verify "$dmg_path" >/dev/null

hdiutil attach -nobrowse -readonly -mountpoint "$dmg_mount" "$dmg_path" >/dev/null
dmg_mounted=true
[[ -d "$dmg_mount/DComicReborn.app" ]] || {
  echo "DMG does not contain DComicReborn.app." >&2
  exit 1
}
[[ -x "$dmg_mount/DComicReborn.app/Contents/MacOS/$bundle_executable" ]] || {
  echo "DMG did not preserve the bundle executable permission." >&2
  exit 1
}
while IFS= read -r -d '' source_link; do
  relative_link="${source_link#"$app_path"/}"
  dmg_link="$dmg_mount/DComicReborn.app/$relative_link"
  [[ -L "$dmg_link" && "$(readlink "$dmg_link")" == "$(readlink "$source_link")" ]] || {
    echo "DMG did not preserve bundle symlink: $relative_link" >&2
    exit 1
  }
done < <(find "$app_path" -type l -print0)
[[ -L "$dmg_mount/Applications" && "$(readlink "$dmg_mount/Applications")" == "/Applications" ]] || {
  echo "DMG does not contain the expected Applications link." >&2
  exit 1
}
hdiutil detach "$dmg_mount" >/dev/null
dmg_mounted=false

for package in "$zip_path" "$dmg_path"; do
  [[ -s "$package" ]] || {
    echo "Package was not created: $package" >&2
    exit 1
  }
done

printf 'Created packages:\n  %s\n  %s\n' "$zip_path" "$dmg_path"

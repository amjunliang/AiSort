#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/aisort-install.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
identity='Developer ID Application: READIT TECHNOLOGY PTE. LTD. (24WBZVJHMZ)'
destination=/Applications/MyApp/AiSort.app

xcodebuild -project "$root/AiSort.xcodeproj" -scheme AiSort -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$work_dir/build" \
    CODE_SIGNING_ALLOWED=NO build
app="$work_dir/build/Build/Products/Release/AiSort.app"
codesign --force --sign "$identity" --timestamp=none "$app"
codesign --verify --strict "$app"

mkdir -p /Applications/MyApp
pkill -f '^/Applications/MyApp/AiSort.app/Contents/MacOS/AiSort$' || true
rm -rf /Applications/MyApp/.AiSort-staged.app
ditto "$app" /Applications/MyApp/.AiSort-staged.app
rm -rf "$destination"
mv /Applications/MyApp/.AiSort-staged.app "$destination"
open -n "$destination"

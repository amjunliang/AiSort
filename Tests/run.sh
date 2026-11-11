#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/aisort-checks.XXXXXX")
output="$temp_dir/checks"
trap 'rm -rf "$temp_dir"' EXIT
xcrun swiftc -module-cache-path "$temp_dir/module-cache" "$root/AiSort/Models/AIModel.swift" "$root/AiSort/Models/ModelSort.swift" \
    "$root/AiSort/Services/Keychain.swift" "$root/AiSort/Services/ModelCacheStore.swift" \
    "$root/AiSort/Services/RateLimit.swift" "$root/AiSort/Services/ModelAPI.swift" "$root/AiSort/Controllers/ModelController.swift" \
    "$root/Tests/ArchitectureChecks.swift" -o "$output"
"$output"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAFE_SMOKE_DIR="/tmp/InnosDimmerSafeSmoke"

mkdir -p "$SAFE_SMOKE_DIR"
rm -f "$SAFE_SMOKE_DIR"/safe-app-window-*.png

xcodebuild \
  -project "$ROOT_DIR/InnosDimmer.xcodeproj" \
  -scheme InnosDimmer \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/InnosDimmerDerivedData-safe-smoke \
  test \
  -only-testing:InnosDimmerTests/MenuBarStateTests/testUnifiedAppWindowSafeVisualSmokeRendersNonblankPages

snapshot_count="$(find "$SAFE_SMOKE_DIR" -maxdepth 1 -type f -name 'safe-app-window-*.png' | wc -l | tr -d ' ')"
if [[ "$snapshot_count" != "6" ]]; then
  echo "Expected 6 safe app-window smoke snapshots, found $snapshot_count in $SAFE_SMOKE_DIR" >&2
  exit 1
fi

while IFS= read -r snapshot; do
  bytes="$(stat -f '%z' "$snapshot")"
  if [[ "$bytes" -le 0 ]]; then
    echo "Safe app-window smoke snapshot is empty: $snapshot" >&2
    exit 1
  fi
done < <(find "$SAFE_SMOKE_DIR" -maxdepth 1 -type f -name 'safe-app-window-*.png')

#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="GoalTracker"
BUNDLE_NAME="Goal Tracker"
BUNDLE_ID="local.goaltracker.app"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="1.0"
BUILD_VERSION="1"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -f "$APP_BINARY" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

BUILD_DIR="$ROOT_DIR/.build/debug"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
mkdir -p "$BUILD_DIR"
find "$ROOT_DIR/Sources/GoalTracker" -name '*.swift' -print0 | sort -z | xargs -0 swiftc -target arm64-apple-macosx14.0 -parse-as-library -o "$BUILD_BINARY"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

swift "$ROOT_DIR/script/generate_app_icon.swift" "$APP_RESOURCES"
iconutil -c icns "$APP_RESOURCES/GoalTracker.iconset" -o "$APP_RESOURCES/GoalTracker.icns"
rm -rf "$APP_RESOURCES/GoalTracker.iconset"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>GoalTracker</string>
  <key>CFBundleName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" --args "$@"
}

case "$MODE" in
  run)
    open_app
    ;;
  --preview-goals|preview-goals)
    open_app --preview-goals
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -f "$APP_BINARY" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|preview-goals|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

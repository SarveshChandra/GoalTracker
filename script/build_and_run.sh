#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/build_settings.sh"

DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"
BUILD_ROOT="$ROOT_DIR/.build"
STAGING_ROOT="${TMPDIR%/}/GoalTracker-build"
APP_BUNDLE="$STAGING_ROOT/$BUNDLE_NAME.app"
DIST_APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
DIST_APP_BINARY="$DIST_APP_BUNDLE/Contents/MacOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PACKAGE_STEM="${BUNDLE_NAME// /-}-${APP_VERSION}-${BUILD_VERSION}"
PACKAGE_PATH="$RELEASE_DIR/$PACKAGE_STEM.zip"
LEGACY_PACKAGE_PATH="$DIST_DIR/$PACKAGE_STEM.zip"
BUILT_BINARY=""

kill_running_app() {
  pkill -f "$APP_BINARY" >/dev/null 2>&1 || true
  pkill -f "$DIST_APP_BINARY" >/dev/null 2>&1 || true
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app_binary() {
  local configuration="$1"
  local build_dir="$BUILD_ROOT/$configuration"
  local -a swift_flags
  local -a app_sources

  mkdir -p "$build_dir"
  swift_flags=(-target "arm64-apple-macosx${MIN_SYSTEM_VERSION}" -parse-as-library)
  if [[ "$configuration" == "release" ]]; then
    swift_flags+=(-O -whole-module-optimization)
  else
    swift_flags+=(-Onone -g)
  fi

  app_sources=()
  while IFS= read -r -d '' file; do
    app_sources+=("$file")
  done < <(find "$ROOT_DIR/Sources/GoalTracker" -name '*.swift' -print0 | sort -z)

  swiftc "${swift_flags[@]}" -o "$build_dir/$APP_NAME" "${app_sources[@]}"
  BUILT_BINARY="$build_dir/$APP_NAME"
}

run_regression_checks() {
  local verify_dir="$BUILD_ROOT/verify"
  local verify_binary="$verify_dir/VerifyGoalTracker"
  local -a verify_sources

  mkdir -p "$verify_dir"
  verify_sources=("$ROOT_DIR/script/VerifyGoalTracker.swift")
  while IFS= read -r -d '' file; do
    verify_sources+=("$file")
  done < <(find "$ROOT_DIR/Sources/GoalTracker" -name '*.swift' ! -path '*/App/*' -print0 | sort -z)

  swiftc -target "arm64-apple-macosx${MIN_SYSTEM_VERSION}" -parse-as-library -o "$verify_binary" "${verify_sources[@]}"
  "$verify_binary"
}

write_info_plist() {
  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>GoalTracker</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>$APP_CATEGORY</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>$APP_COPYRIGHT</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

stage_bundle() {
  rm -rf "$APP_BUNDLE"
  rm -rf "$DIST_APP_BUNDLE"
  mkdir -p "$DIST_DIR" "$RELEASE_DIR" "$STAGING_ROOT"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$BUILT_BINARY" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  swift "$ROOT_DIR/script/generate_app_icon.swift" "$APP_RESOURCES"
  iconutil -c icns "$APP_RESOURCES/GoalTracker.iconset" -o "$APP_RESOURCES/GoalTracker.icns"
  rm -rf "$APP_RESOURCES/GoalTracker.iconset"

  write_info_plist
  xattr -cr "$APP_BUNDLE"
}

sign_bundle() {
  local signing_identity="${GOAL_TRACKER_SIGNING_IDENTITY:--}"
  local -a codesign_args

  xattr -cr "$APP_BUNDLE"
  codesign_args=(--force --sign "$signing_identity")
  if [[ "$signing_identity" != "-" ]]; then
    codesign_args+=(--options runtime --timestamp)
    if [[ -n "${GOAL_TRACKER_ENTITLEMENTS_PATH:-}" ]]; then
      codesign_args+=(--entitlements "$GOAL_TRACKER_ENTITLEMENTS_PATH")
    fi
  fi

  /usr/bin/codesign "${codesign_args[@]}" "$APP_BUNDLE"
}

validate_bundle() {
  /usr/bin/plutil -lint "$INFO_PLIST" >/dev/null
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

mirror_bundle_to_dist() {
  rm -rf "$DIST_APP_BUNDLE"
  /usr/bin/ditto "$APP_BUNDLE" "$DIST_APP_BUNDLE"
}

package_bundle() {
  rm -f "$PACKAGE_PATH"
  rm -f "$LEGACY_PACKAGE_PATH"
  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$PACKAGE_PATH"
  echo "Project app bundle: $DIST_APP_BUNDLE"
  echo "Packaged release artifact: $PACKAGE_PATH"
}

notarize_bundle() {
  local signing_identity="${GOAL_TRACKER_SIGNING_IDENTITY:--}"

  if [[ "$signing_identity" == "-" ]]; then
    echo "GOAL_TRACKER_SIGNING_IDENTITY must be set to a Developer ID identity before notarization." >&2
    exit 1
  fi

  if [[ -z "${GOAL_TRACKER_NOTARY_PROFILE:-}" ]]; then
    echo "GOAL_TRACKER_NOTARY_PROFILE must be set to a notarytool keychain profile before notarization." >&2
    exit 1
  fi

  xcrun notarytool submit "$PACKAGE_PATH" --keychain-profile "$GOAL_TRACKER_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  /usr/sbin/spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
  package_bundle
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" --args "$@"
}

case "$MODE" in
  run)
    kill_running_app
    build_app_binary debug
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    open_app
    ;;
  --preview-goals|preview-goals)
    kill_running_app
    build_app_binary debug
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    open_app --preview-goals
    ;;
  --debug|debug)
    kill_running_app
    build_app_binary debug
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    kill_running_app
    build_app_binary debug
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    kill_running_app
    build_app_binary debug
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    kill_running_app
    build_app_binary debug
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    open_app
    sleep 2
    pgrep -f "$APP_BINARY" >/dev/null
    ;;
  --check|check)
    run_regression_checks
    ;;
  --release|release)
    run_regression_checks
    build_app_binary release
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    echo "Built release app bundle: $DIST_APP_BUNDLE"
    ;;
  --package|package)
    run_regression_checks
    build_app_binary release
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    package_bundle
    ;;
  --notarize|notarize)
    run_regression_checks
    build_app_binary release
    stage_bundle
    sign_bundle
    validate_bundle
    mirror_bundle_to_dist
    package_bundle
    notarize_bundle
    ;;
  *)
    echo "usage: $0 [run|preview-goals|--debug|--logs|--telemetry|--verify|--check|--release|--package|--notarize]" >&2
    exit 2
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CueShot"
BUNDLE_ID="com.edgariraheta.CueShot"
MIN_SYSTEM_VERSION="14.0"
VERSION="${CUESHOT_VERSION:-0.1.6}"
BUILD_CONFIGURATION="${CUESHOT_BUILD_CONFIGURATION:-release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
LOG_FILE="$HOME/Library/Application Support/$APP_NAME/Logs/events.log"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"

resolve_sign_identity() {
  if [[ -n "${CUESHOT_SIGN_IDENTITY:-}" ]]; then
    echo "$CUESHOT_SIGN_IDENTITY"
    return
  fi

  local identity
  identity="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:.*\)".*/\1/p' | head -n 1)"
  if [[ -n "$identity" ]]; then
    echo "$identity"
  else
    echo "-"
  fi
}

sign_bundle() {
  local bundle="$1"
  local identity
  identity="$(resolve_sign_identity)"
  codesign --force --deep --sign "$identity" "$bundle" >/dev/null
}

build_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  swift build -c "$BUILD_CONFIGURATION"
  BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$BUILD_BINARY" "$APP_BINARY"
  chmod +x "$APP_BINARY"
  if [[ -f "$APP_ICON" ]]; then
    cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
  fi

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
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>CueShot needs Screen Recording to capture the UI element you clicked. Captures stay on this Mac.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>CueShot needs Automation to ask System Events to focus Codex and trigger Edit &gt; Paste after copying a screenshot.</string>
</dict>
</plist>
PLIST

  if command -v codesign >/dev/null 2>&1; then
    sign_bundle "$APP_BUNDLE"
  fi
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

open_privacy_settings() {
  local permission_app="$APP_BUNDLE"
  if [[ -d "$INSTALLED_APP" ]]; then
    permission_app="$INSTALLED_APP"
  fi
  /usr/bin/open -n "$permission_app"
  /usr/bin/open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" >/dev/null 2>&1 || true
  /usr/bin/open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" >/dev/null 2>&1 || true
  /usr/bin/open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" >/dev/null 2>&1 || true
  echo "Grant Accessibility, Screen Recording, and Automation/System Events to: $permission_app"
}

install_app() {
  build_app
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALLED_APP"
  ditto "$APP_BUNDLE" "$INSTALLED_APP"
  sign_bundle "$INSTALLED_APP"
  /usr/bin/open -n "$INSTALLED_APP"
  echo "$INSTALLED_APP"
}

build_dmg() {
  build_app
  rm -rf "$DMG_ROOT" "$DMG_PATH"
  mkdir -p "$DMG_ROOT"
  ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
  ln -s /Applications "$DMG_ROOT/Applications"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
  hdiutil verify "$DMG_PATH" >/dev/null
  echo "$DMG_PATH"
}

tcc_label() {
  case "$1" in
    2) echo "allowed" ;;
    0) echo "denied" ;;
    "") echo "missing" ;;
    *) echo "value=$1" ;;
  esac
}

tcc_value_for() {
  local db="$1"
  local service="$2"
  if [[ ! -r "$db" ]]; then
    return
  fi

  sqlite3 "$db" "select auth_value from access where service='$service' and client='$BUNDLE_ID' order by last_modified desc limit 1;" 2>/dev/null || true
}

print_tcc_status() {
  local user_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
  local system_db="/Library/Application Support/com.apple.TCC/TCC.db"
  local accessibility
  local screen
  local automation

  accessibility="$(tcc_value_for "$system_db" "kTCCServiceAccessibility")"
  [[ -n "$accessibility" ]] || accessibility="$(tcc_value_for "$user_db" "kTCCServiceAccessibility")"

  screen="$(tcc_value_for "$system_db" "kTCCServiceScreenCapture")"
  [[ -n "$screen" ]] || screen="$(tcc_value_for "$user_db" "kTCCServiceScreenCapture")"

  automation="$(tcc_value_for "$system_db" "kTCCServiceAppleEvents")"
  [[ -n "$automation" ]] || automation="$(tcc_value_for "$user_db" "kTCCServiceAppleEvents")"

  echo "TCC Accessibility: $(tcc_label "$accessibility")"
  echo "TCC Screen Recording: $(tcc_label "$screen")"
  echo "TCC Automation/System Events: $(tcc_label "$automation")"
}

case "$MODE" in
  run)
    build_app
    open_app
    ;;
  --debug|debug)
    BUILD_CONFIGURATION="debug"
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --permissions|permissions)
    open_privacy_settings
    ;;
  --install|install)
    install_app
    ;;
  --dmg|dmg)
    build_dmg
    ;;
  --diagnose|diagnose)
    diagnostic_app="$APP_BUNDLE"
    if [[ -d "$INSTALLED_APP" ]]; then
      diagnostic_app="$INSTALLED_APP"
    fi
    /usr/bin/open -n "$diagnostic_app"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    print_tcc_status
    if [[ -f "$LOG_FILE" ]]; then
      tail -n 80 "$LOG_FILE"
    else
      echo "No diagnostics log yet: $LOG_FILE"
    fi
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--permissions|--install|--dmg|--diagnose|--verify]" >&2
    exit 2
    ;;
esac

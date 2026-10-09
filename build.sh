#!/bin/bash
# Сборка AutoShoter.app из SwiftPM-пакета.
#   ./build.sh            — собрать в build/AutoShoter.app
#   ./build.sh install    — собрать и положить в ~/Applications
#   ./build.sh run        — собрать и запустить
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="AutoShoter"
BUNDLE_ID="me.garik.autoshoter"
VERSION="1.0"
MODE="${1:-build}"

echo "→ Компилирую…"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP="build/${APP_NAME}.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>ru</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Постоянный локальный сертификат: с ним разрешение на запись экрана переживает пересборку.
# Если его нет — ad-hoc, и macOS будет считать каждую сборку новым приложением.
SIGN_ID="$(security find-identity -p codesigning 2>/dev/null | awk '/AutoShoter Local Signing/ {print $2; exit}')"
if [ -n "$SIGN_ID" ]; then
    codesign --force --sign "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP" >/dev/null
    echo "→ Подписано сертификатом AutoShoter Local Signing"
else
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" >/dev/null
    echo "→ Подписано ad-hoc (запустите ./setup-signing.sh, чтобы разрешение не слетало)"
fi

echo "→ Готово: $APP"

if [ "$MODE" = "install" ]; then
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/${APP_NAME}.app"
    cp -R "$APP" "$HOME/Applications/"
    echo "→ Установлено: ~/Applications/${APP_NAME}.app"
fi

if [ "$MODE" = "run" ]; then
    open "$APP"
fi

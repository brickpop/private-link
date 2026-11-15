#!/bin/bash
# Assemble PrivateLink.app around the SwiftPM binary and ad-hoc sign it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=PrivateLink.app
BIN=PrivateLink
mkdir -p "$APP/Contents/MacOS"

cp .build/release/$BIN "$APP/Contents/MacOS/$BIN"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>PrivateLink</string>
    <key>CFBundleDisplayName</key>       <string>PrivateLink</string>
    <key>CFBundleIdentifier</key>        <string>org.private.link</string>
    <key>CFBundleExecutable</key>        <string>PrivateLink</string>
    <key>CFBundleVersion</key>           <string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>LSMinimumSystemVersion</key>    <string>12.0</string>
    <key>NSHighResolutionCapable</key>   <true/>
    <key>LSUIElement</key>               <true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.utilities</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>    <string>HTTP/HTTPS links</string>
            <key>CFBundleURLSchemes</key> <array><string>http</string><string>https</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: enough for a local, self-built app
codesign --force --sign - "$APP"

echo "built $APP"

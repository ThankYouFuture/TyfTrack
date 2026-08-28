#!/bin/zsh
# Build TyfTrack.app with the command-line-tools Swift toolchain (no Xcode needed).
set -e
cd "$(dirname "$0")/.."

APP=build/TyfTrack.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos14.0 \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/TyfTrack" \
  -framework AppKit \
  -framework SwiftUI \
  -framework Combine \
  -framework Security \
  -framework ServiceManagement \
  -framework CoreGraphics

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/logo-tyf.png "$APP/Contents/Resources/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --sign - "$APP"
echo "✅ Build OK → $APP"

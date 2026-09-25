#!/bin/sh
# Wraps the SwiftPM binary in a .app so notifications work. Output: build/Pomodoro.app
set -e
swift build -c release
APP=build/Pomodoro.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pomodoro "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>net.bhatti.pomodoro</string>
  <key>CFBundleName</key><string>Pomodoro</string>
  <key>CFBundleExecutable</key><string>Pomodoro</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
</dict></plist>
PLIST
codesign -s - --force "$APP"
echo "Built $APP"

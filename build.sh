#!/bin/bash

set -e

echo "🔨 Compilando Free Clamshell Mode app..."

BUILD_DIR="build"
APP_NAME="free-clamshell-mode"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile Swift
swiftc -parse-as-library -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" free-clamshell-mode.swift

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>free-clamshell-mode</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.free-clamshell-mode</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Free Clamshell Mode</string>
    <key>CFBundleDisplayName</key>
    <string>Free Clamshell Mode</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
EOF

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "✅ App compilada: $APP_BUNDLE"
echo "🚀 Para ejecutar: open $APP_BUNDLE"

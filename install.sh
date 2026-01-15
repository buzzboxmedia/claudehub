#!/bin/bash
# ClaudeHub Install Script
# Builds and installs ClaudeHub as a proper macOS app

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeHub"
APP_PATH="$HOME/Applications/$APP_NAME.app"

echo "Building $APP_NAME..."
cd "$SCRIPT_DIR"
swift build

echo "Creating app bundle..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy executable
cp ".build/debug/$APP_NAME" "$APP_PATH/Contents/MacOS/"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeHub</string>
    <key>CFBundleIdentifier</key>
    <string>com.buzzbox.claudehub</string>
    <key>CFBundleName</key>
    <string>ClaudeHub</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH"

# Add to Dock (remove old entries, add correct path)
python3 << PYTHON
import subprocess
import plistlib

APP_PATH = "$APP_PATH"

# Get current dock apps
result = subprocess.run(['defaults', 'export', 'com.apple.dock', '-'], capture_output=True)
dock = plistlib.loads(result.stdout)

# Remove any existing ClaudeHub entries
filtered = [
    app for app in dock.get('persistent-apps', [])
    if 'ClaudeHub' not in app.get('tile-data', {}).get('file-data', {}).get('_CFURLString', '')
]

# Add ClaudeHub with correct path
filtered.append({
    'tile-data': {
        'file-data': {
            '_CFURLString': f'file://{APP_PATH}/',
            '_CFURLStringType': 15
        }
    }
})

dock['persistent-apps'] = filtered

# Write back
plist_data = plistlib.dumps(dock)
subprocess.run(['defaults', 'import', 'com.apple.dock', '-'], input=plist_data)
print("✓ Added to Dock")
PYTHON

killall Dock 2>/dev/null || true

echo "✓ Installed to $APP_PATH"
echo ""
echo "Launch from Dock or Spotlight: ⌘+Space → ClaudeHub"

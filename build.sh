#!/bin/bash

# Configuration
APP_NAME="AwakeDisplay"
APP_BUNDLE="${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
PLIST_PATH="${APP_BUNDLE}/Contents/Info.plist"

echo "Building ${APP_NAME}..."

# 1. Create the App bundle structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 1.1 Generate App Icon (.icns) if source icon exists
if [ -f "icons/app-icon.png" ]; then
    echo "Generating .icns file..."
    ICONSET_DIR="AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # Generate different sizes for the iconset (forcing format to png)
    sips -s format png -z 16 16     icons/app-icon.png --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
    sips -s format png -z 32 32     icons/app-icon.png --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
    sips -s format png -z 32 32     icons/app-icon.png --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
    sips -s format png -z 64 64     icons/app-icon.png --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
    sips -s format png -z 128 128   icons/app-icon.png --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
    sips -s format png -z 256 256   icons/app-icon.png --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
    sips -s format png -z 256 256   icons/app-icon.png --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
    sips -s format png -z 512 512   icons/app-icon.png --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
    sips -s format png -z 512 512   icons/app-icon.png --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
    sips -s format png -z 1024 1024 icons/app-icon.png --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null
    
    # Convert iconset to icns
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
    
    # Clean up the temporary iconset folder
    rm -rf "${ICONSET_DIR}"
fi

# 1.2 Copy status bar icons
cp icons/bar-icon-line.svg "${RESOURCES_DIR}/bar-icon-line.svg"
cp icons/bar-icon-fill.svg "${RESOURCES_DIR}/bar-icon-fill.svg"

# 2. Create Info.plist
cat > "${PLIST_PATH}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.litiantao.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>需要屏幕录制权限以显示画中画功能中的虚拟外接显示器内容。</string>
</dict>
</plist>
EOF

# 3. Compile the Swift code
swiftc -import-objc-header Bridging-Header.h \
       main.swift \
       AppDelegate.swift \
       AwakeDisplayManager.swift \
       PiPWindowController.swift \
       -framework Cocoa \
       -framework CoreGraphics \
       -framework AVFoundation \
       -o "${MACOS_DIR}/${APP_NAME}"

# 4. Check for success
if [ $? -eq 0 ]; then
    echo "Build successful! Created ${APP_BUNDLE}."
    echo "Run 'open ${APP_BUNDLE}' to start the app."
else
    echo "Build failed."
    exit 1
fi

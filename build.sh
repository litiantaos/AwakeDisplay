#!/bin/bash
set -e # 任何命令失败则立即退出脚本

# 配置项
APP_NAME="AwakeDisplay"
APP_BUNDLE="${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
PLIST_PATH="${APP_BUNDLE}/Contents/Info.plist"

# 获取版本号，如果没有则默认为 1.1.1
APP_VERSION=${APP_VERSION:-"1.1.1"}
BUILD_NUMBER=${BUILD_NUMBER:-"1"}

echo "正在构建 ${APP_NAME} (版本: ${APP_VERSION}, 构建号: ${BUILD_NUMBER})..."

# 1. 创建 App bundle 结构
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 1.1 生成 App 图标 (.icns) (如果源图标存在)
if [ -f "icons/app-icon.png" ]; then
    echo "正在生成 .icns 文件..."
    ICONSET_DIR="AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # 生成不同尺寸的图标 (强制格式为 png)
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
    
    # 将 iconset 转换为 icns
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
    
    # 清理临时的 iconset 文件夹
    rm -rf "${ICONSET_DIR}"
fi

# 1.2 复制状态栏图标
if [ -f "icons/bar-icon-line.svg" ] && [ -f "icons/bar-icon-fill.svg" ]; then
    cp icons/bar-icon-line.svg "${RESOURCES_DIR}/bar-icon-line.svg"
    cp icons/bar-icon-fill.svg "${RESOURCES_DIR}/bar-icon-fill.svg"
else
    echo "警告：未找到状态栏图标资源"
fi

# 2. 创建 Info.plist
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
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
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

# 3. 编译 Swift 代码
echo "正在编译 Swift 代码..."
swiftc -import-objc-header Sources/Core/Bridging-Header.h \
       Sources/App/main.swift \
       Sources/App/AppDelegate.swift \
       Sources/Core/AwakeDisplayManager.swift \
       Sources/Core/UpdateCoordinator.swift \
       Sources/UI/PiPWindowController.swift \
       Sources/UI/AboutWindowController.swift \
       -framework Cocoa \
       -framework CoreGraphics \
       -framework AVFoundation \
       -o "${MACOS_DIR}/${APP_NAME}"

# 4. 对应用进行 Ad-Hoc 签名
echo "正在进行 Ad-Hoc 签名..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "构建成功！已生成 ${APP_BUNDLE}。"
echo "运行 'open ${APP_BUNDLE}' 以启动应用。"

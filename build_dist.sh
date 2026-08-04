#!/bin/bash
set -e
cd /Users/zhengtiansheng/WeChatProjects/applet/passtool

# ============ 0. 定位新版 Swift 工具链 ============
# 优先使用从 swift.org 下载并解压的工具链
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-}"
if [ -z "$TOOLCHAIN_DIR" ]; then
  # 查找已安装的工具链
  for tc in /Library/Developer/Toolchains/Swift*.xctoolchain ~/Library/Developer/Toolchains/Swift*.xctoolchain /tmp/SwiftToolchain.xctoolchain; do
    if [ -d "$tc/usr/bin/swiftc" ] || [ -x "$tc/usr/bin/swiftc" ]; then
      TOOLCHAIN_DIR="$tc"
      break
    fi
  done
fi

if [ -n "$TOOLCHAIN_DIR" ] && [ -x "$TOOLCHAIN_DIR/usr/bin/swiftc" ]; then
  SWIFTC="$TOOLCHAIN_DIR/usr/bin/swiftc"
  SDK="$TOOLCHAIN_DIR/usr/$(uname -m)-apple-darwin/SDKs/MacOSX.sdk"
  [ -d "$SDK" ] || SDK=$(xcrun --show-sdk-path --sdk macosx)
  echo "使用工具链: $TOOLCHAIN_DIR"
  echo "Swift 版本: $($SWIFTC --version 2>&1 | head -1)"
else
  SWIFTC="xcrun swiftc"
  SDK=$(xcrun --show-sdk-path --sdk macosx)
  echo "使用系统默认 swiftc: $(swiftc --version 2>&1 | head -1)"
fi
echo "SDK: $SDK"

# ============ 1. 构建 icns ============
ICONSET="/tmp/Passtool.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
SRC="Artwork/appicon_source.jpg"

sizes=(
  "icon_16x16.png 16"
  "icon_16x16@2x.png 32"
  "icon_32x32.png 32"
  "icon_32x32@2x.png 64"
  "icon_128x128.png 128"
  "icon_128x128@2x.png 256"
  "icon_256x256.png 256"
  "icon_256x256@2x.png 512"
  "icon_512x512.png 512"
  "icon_512x512@2x.png 1024"
)
for pair in "${sizes[@]}"; do
  set -- $pair
  name="$1"; sz="$2"
  sips -z "$sz" "$sz" "$SRC" --out "$ICONSET/$name" >/dev/null 2>&1
  sips -s format png "$ICONSET/$name" --out "$ICONSET/$name.tmp" >/dev/null 2>&1 && mv "$ICONSET/$name.tmp" "$ICONSET/$name"
done

ICNS_PATH="Shared/Assets/AppIcon.icns"
rm -f "$ICNS_PATH"
iconutil -c icns "$ICONSET" -o "$ICNS_PATH"
echo "icns: $ICNS_PATH $(stat -f%z "$ICNS_PATH") bytes"

# ============ 2. 编译双架构二进制 ============
APP="dist/Passtool.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

SWIFT_FILES=()
while IFS= read -r -d '' f; do
  SWIFT_FILES+=("$f")
done < <(find Shared macOS -name '*.swift' -type f -print0)
echo "源文件数: ${#SWIFT_FILES[@]}"

# x86_64 (Intel)
echo ">>> 编译 x86_64 (Intel)..."
$SWIFTC -target x86_64-apple-macosx10.15 -O -sdk "$SDK" -I "." \
  -o /tmp/Passtool_x86 "${SWIFT_FILES[@]}" 2>&1 | tail -15
if [ ! -f /tmp/Passtool_x86 ]; then
  echo "❌ x86_64 编译失败"
  exit 1
fi
echo "✅ x86_64 编译成功"

# arm64 (Apple Silicon)
echo ">>> 编译 arm64 (Apple Silicon)..."
$SWIFTC -target arm64-apple-macosx11.0 -O -sdk "$SDK" -I "." \
  -o /tmp/Passtool_arm "${SWIFT_FILES[@]}" 2>&1 | tail -15
if [ ! -f /tmp/Passtool_arm ]; then
  echo "❌ arm64 编译失败"
  exit 1
fi
echo "✅ arm64 编译成功"

# 合并为通用二进制
echo ">>> 合并通用二进制..."
lipo -create -output "$APP/Contents/MacOS/Passtool" /tmp/Passtool_x86 /tmp/Passtool_arm
echo "通用二进制:"
lipo -info "$APP/Contents/MacOS/Passtool"

# ============ 3. 资源 + plist ============
cp "$ICNS_PATH" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>CFBundleExecutable</key><string>Passtool</string>
  <key>CFBundleIdentifier</key><string>com.passtool.mac</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Passtool</string>
  <key>CFBundleDisplayName</key><string>Passtool</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon.icns</string>
  <key>LSMinimumSystemVersion</key><string>10.15</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Passtool</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticTermination</key><true/>
  <key>NSSupportsSuddenTermination</key><false/>
  <key>LSSupportsOpeningDocumentsInPlace</key><true/>
  <key>NSDocumentsFolderUsageDescription</key><string>访问文稿文件夹以保存密码库</string>
  <key>NSDesktopFolderUsageDescription</key><string>访问桌面以保存密码库</string>
  <key>NSDownloadsFolderUsageDescription</key><string>访问下载文件夹以保存密码库</string>
  <key>NSRemovableVolumesUsageDescription</key><string>访问可移动磁盘以保存密码库</string>
</dict>
</plist>
PLIST

echo -n "APPL????" > "$APP/Contents/PkgInfo"

codesign --force --deep --sign "-" --entitlements "macOS/Passtool.entitlements" --options runtime "$APP" 2>&1 | tail -3
echo "签名:"
codesign -dv "$APP" 2>&1 | head -5
echo "资源:"
ls -la "$APP/Contents/Resources/"
echo "✅ 构建完成（x86_64 + arm64 通用二进制）"

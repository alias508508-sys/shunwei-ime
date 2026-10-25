#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=0.2.0-dev
stage="macos/build/dmg-stage"
installer="$stage/安装顺位输入法.app"
if [ ! -d macos/build/Shunwrite.app ]; then bash scripts/build-mac.sh; fi
mkdir -p "$installer/Contents/MacOS" "$installer/Contents/Resources" releases
cat > "$installer/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.shunwei.installer</string><key>CFBundleName</key><string>安装顺位输入法</string>
<key>CFBundleDisplayName</key><string>安装顺位输入法</string><key>CFBundleExecutable</key><string>Installer</string>
<key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string><key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
ditto macos/build/Shunwrite.app "$installer/Contents/Resources/Shunwrite.app"
xcrun swiftc -O -target arm64-apple-macos14.0 -framework AppKit macos/Installer/main.swift -o "$installer/Contents/MacOS/Installer"
codesign --force --sign - "$installer"
codesign --verify --deep --strict "$installer"
"$installer/Contents/MacOS/Installer" --check-payload
cp scripts/uninstall-mac.sh "$stage/卸载顺位输入法.command"
chmod +x "$stage/卸载顺位输入法.command"
cat > "$stage/先读我.txt" <<'TXT'
顺位输入法 0.2.0 开发版 / Apple Silicon / macOS14及以上编译目标

1. 双击“安装顺位输入法.app”，安装到当前用户。
2. 到系统设置 → 键盘 → 文本输入，添加“顺位输入法”。未出现时退出登录后重新登录。
3. 默认拼音（中文优先），空格选词、Return提交原文、Esc取消组合。
4. 这是本机ad-hoc签名的开发构建，未经Apple Developer ID签名和公证。系统可能阻止首次运行；不要关闭系统整体安全保护。面向公众发布前需由开发者签名并公证。
5. 编译和协议测试通过不代表已完成TextEdit、浏览器、办公软件的真实宿主验收。
6. 卸载前切换其他输入法并在系统设置中移除顺位，再运行“卸载顺位输入法.command”。用户词条与旧版备份保留。

第三方词典来源和许可位于安装器内输入法应用的Resources/ThirdParty。
TXT
hdiutil create -volname '顺位输入法开发版' -srcfolder "$stage" -format UDZO -ov "releases/Shunwei-$version-macOS-arm64.dmg"
hdiutil verify "releases/Shunwei-$version-macOS-arm64.dmg"

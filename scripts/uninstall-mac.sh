#!/bin/bash
set -euo pipefail
app="$HOME/Library/Input Methods/Shunwrite.app"
printf '%s\n' '请先切换到其他输入法，并在系统设置中移除“顺位”。'
if [ -d "$app" ]; then
  bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
  if [ "$bundle_id" != 'org.shunwrite.inputmethod.Shunwrite' ]; then printf '%s\n' '标识不匹配，停止卸载。'; exit 1; fi
  destination="$HOME/.Trash/Shunwrite-$(date +%Y%m%d-%H%M%S).app"
  mkdir -p "$HOME/.Trash"
  mv "$app" "$destination"
  printf '应用已移至废纸篓：%s\n' "$destination"
fi
printf '%s\n' '用户词条保留于 ~/Library/Application Support/Shunwrite/entries.json，可自行删除。'

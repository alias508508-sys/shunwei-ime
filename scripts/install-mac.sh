#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app="macos/build/Shunwrite.app"
target_dir="$HOME/Library/Input Methods"
target_app="$target_dir/Shunwrite.app"
if [ ! -d "$source_app" ]; then printf '%s\n' '请先运行 npm run build:mac。'; exit 1; fi
codesign --verify --deep --strict "$source_app"
mkdir -p "$target_dir"
if [ -e "$target_app" ]; then
  backup_path="$target_app.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$target_app" "$backup_path"
  printf '已备份旧版：%s\n' "$backup_path"
fi
ditto "$source_app" "$target_app"
printf '已安装到：%s\n' "$target_app"
printf '%s\n' '请在系统设置 → 键盘 → 文本输入 → 编辑中添加“顺位”。列表未出现时退出登录后重新登录。安装脚本没有启用或切换系统输入源。'

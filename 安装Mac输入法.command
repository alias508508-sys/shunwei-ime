#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash scripts/install-mac.sh
read -r -p '按 Return 关闭窗口。' answer

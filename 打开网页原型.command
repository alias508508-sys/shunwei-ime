#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
existing_page=$(curl -fsS --max-time 2 'http://127.0.0.1:4173/' 2>/dev/null || true)
case "$existing_page" in *'顺位'*) open 'http://127.0.0.1:4173'; exit 0;; esac
if ! command -v npm >/dev/null 2>&1; then printf '%s\n' '未找到 npm，请先安装 Node.js。'; exit 1; fi
if [ ! -d node_modules ]; then npm ci; fi
npm run dev -- --port 4173 --strictPort &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
for attempt in {1..40}; do
  if curl -fsS --max-time 1 'http://127.0.0.1:4173/' >/dev/null 2>&1; then open 'http://127.0.0.1:4173'; break; fi
  sleep 0.15
done
wait "$server_pid"

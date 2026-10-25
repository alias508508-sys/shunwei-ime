#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mingw_root="${SHUNWEI_MINGW_ROOT:-$PWD/.tools/llvm-mingw-20261006-ucrt-macos-universal}"
if [ ! -x "$mingw_root/bin/x86_64-w64-mingw32-clang++" ]; then printf '%s\n' '缺少LLVM-MinGW，请设置SHUNWEI_MINGW_ROOT。'; exit 1; fi
python3 scripts/export-windows-data.py
for arch in x64 x86; do
  triplet=x86_64-w64-mingw32
  if [ "$arch" = x86 ]; then triplet=i686-w64-mingw32; fi
  mkdir -p "windows/build/$arch"
  "$mingw_root/bin/$triplet-clang++" -std=c++17 -O2 -DNOMINMAX -Wno-deprecated-declarations -shared -static windows/src/tsf.cpp -lole32 -loleaut32 -luuid -ladvapi32 -luser32 -lgdi32 -Wl,--kill-at -o "windows/build/$arch/Shunwei.dll"
  "$mingw_root/bin/$triplet-clang++" -std=c++17 -O2 -Wno-deprecated-declarations -static windows/src/engine-check.cpp -o "windows/build/$arch/engine-check.exe"
  "$mingw_root/bin/llvm-readobj" --file-headers --coff-exports "windows/build/$arch/Shunwei.dll" > "windows/build/$arch/pe-inspection.txt"
done

#!/usr/bin/env bash
set -euo pipefail
native_root="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$native_root/bin"
"${CC:-cc}" -std=c11 -O3 -Wall -Wextra -fPIC -shared \
  -o "$native_root/bin/libdot_wars_native.linux.x86_64.so" \
  "$native_root/dot_wars_native.c"

#!/usr/bin/env bash
# Build and exercise the vendor helpers with all test data in this workspace.
set -euo pipefail
umask 077
task_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$task_root"
mkdir -p artifacts/smoke-codex artifacts/cache
export CODEX_HOME="$task_root/artifacts/smoke-codex"
export XDG_CACHE_HOME="$task_root/artifacts/cache"

nix build ./nix --out-link artifacts/result
nix build ./nix#native-shell --out-link artifacts/native-shell

artifacts/native-shell/bin/chatgpt-native-shell -c '
  set -e
  "$CHATGPT_RESOURCES/cua_node/bin/node" --version
  "$CHATGPT_RESOURCES/rg" --version
  "$CHATGPT_RESOURCES/codex" --version
  "$CHATGPT_RESOURCES/cua_node/bin/node" "$1"
  "$CHATGPT_RESOURCES/codex" sandbox -- /bin/sh -c '\''
    printf "Codex sandbox command passed\n"
    awk "/^NoNewPrivs:|^Seccomp:/" /proc/self/status
  '\''
' -- "$task_root/scripts/smoke-node.cjs"

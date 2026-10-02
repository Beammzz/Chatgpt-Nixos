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
nix build ./nix#fhs-shell --out-link artifacts/fhs-shell

artifacts/fhs-shell/bin/chatgpt-fhs-shell -c '
  set -e
  /usr/lib/chatgpt/resources/cua_node/bin/node --version
  /usr/lib/chatgpt/resources/rg --version
  /usr/lib/chatgpt/resources/codex --version
  /usr/lib/chatgpt/resources/cua_node/bin/node "$1"
  /usr/lib/chatgpt/resources/codex sandbox -- /bin/sh -c '\''
    printf "Codex sandbox command passed\n"
    awk "/^NoNewPrivs:|^Seccomp:/" /proc/self/status
  '\''
' -- "$task_root/scripts/smoke-node.cjs"

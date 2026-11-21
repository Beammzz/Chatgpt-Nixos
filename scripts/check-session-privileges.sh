#!/usr/bin/env bash
# Run from a local Full access agent command after fully restarting ChatGPT.
set -euo pipefail
task_pid=$$
while [[ "$task_pid" -gt 1 ]]; do
  printf '\nPID %s, executable %s\n' "$task_pid" "$(readlink "/proc/$task_pid/exe" || true)"
  awk '/^Name:|^PPid:|^Uid:|^NoNewPrivs:|^Seccomp:/' "/proc/$task_pid/status"
  task_pid=$(awk '/^PPid:/ { print $2 }' "/proc/$task_pid/status")
done
printf '\nsudo path: %s\n' "$(command -v sudo)"
sudo -n id

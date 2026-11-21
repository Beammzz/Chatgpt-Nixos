# Native launcher and passwordless sudo

Date: 2026-10-08 (Asia/Bangkok). **Verified:** ARM64 native build, isolated GUI,
bundled app-server command execution and Home Manager activation.
**Pending:** a full restart and local command check in the user's normal app session.

## Problem and evidence

The original `buildFHSEnv` launcher starts an outer bubblewrap environment.
Readback of `/proc/{2185,2196,2601}/status` showed `NoNewPrivs: 1` for bubblewrap,
ChatGPT's main process and its bundled Codex app-server respectively. Full access
inside the app cannot clear an inherited kernel `no_new_privs` flag.
The user reported that `sudo -n id` therefore failed in local agent commands.

**Verified:** the host command `/run/wrappers/bin/sudo -n id` returns
`uid=0(root) gid=0(root) groups=0(root)`. The saved unrestricted `NOPASSWD`
rule is present in `/home/harumi/.dotfiles/Nixos/configuration.nix`.
Its manual activation was user-reported; the successful host command independently
confirms that passwordless sudo is effective. No sudo policy change was needed.

The running daily system is ARM64 Linux `7.2.9`, system closure
`/nix/store/7766yhfknzscy4hvn2zwzxb4brgb4f5n-nixos-system-Harumi-Nixos-26.11.20261006.151fa4e`.
This differs from the older ext4 installation recorded in the ProArt project guide.
No kernel build, NixOS rebuild, reboot or input update was performed.

## Sources and implementation

The vendor version remains **26.928.31416**, Debian architecture **arm64**:

```text
https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_26.928.31416_arm64.deb
SHA-256 b3c3f37dedfc57db72e810a1dc5be7b22586f0b99b7d4875868b06bdd855ba86
```

`nix/native.nix` uses `autoPatchelfHook` explicitly on files selected by
`nix/select-native-elf.py`. The selector checks ELF machine IDs and excludes
Android and musl prebuilds. Missing dependencies remain fatal; no ignore list is
used. `$ORIGIN` library paths are preserved, including Sharp's bundled libvips.
Runtime-loaded GUI, graphics, audio, credential, USB, TPM and Qt libraries are
included in RUNPATH. `/run/opengl-driver/lib` supplies the host graphics drivers.
No global `LD_LIBRARY_PATH` is exported into commands.

The launcher directly execs the patched bundled Owl binary as the normal user.
It creates no outer bubblewrap namespace and adds no sandbox-disabling flags.
Bubblewrap remains on PATH for Codex's own sandbox. Caller PATH entries retain
precedence, including NixOS's `/run/wrappers/bin/sudo` and configured local tools.
The bundled helpers and resources stay adjacent to the app; Node, ripgrep,
native modules and plugin helpers receive the required ELF adaptation.

Static inspection of the shipped ASAR found the supported environment override
`CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH`. The launcher supplies a resource
root containing `plugins/openai-bundled`, copied into a private, locked and
atomically initialized user cache. Its cache key includes the patched payload's
store identity, avoiding stale helper copies after package/library changes.
Cached bytes match the patched package; writable permission metadata allows the
app's manifest-copy/rewrite workflow. The cache is user-writable and has no
read-only mount; the store source stays immutable. ASAR bytes are unchanged.

ARM64's default package is native. The old diagnostic `fhs-shell` and existing
unvalidated x86-64 app definition remain available. New native-shell exports and
runtime development are limited to ARM64.

The Home Manager wrapper still selects explicit Wayland/X11, forwards profile
and URI arguments, uses existing profiles by default, and registers `codex:`.
The standalone package retains vendor assets and document handlers while
omitting broad HTTP/HTTPS registrations. The Home Manager menu item still uses
its absolute icon path and the same launcher for normal launches and callbacks.

## Completed checks

Evidence is under ignored `artifacts/native-launcher/`. Full runtime logs may
contain session/account data and are not committed.

| Check | Verified result / evidence |
| --- | --- |
| Standalone ARM64 build | `nix build ./nix`; `build.log`, `final-build.log` |
| ELF selection | 45 ELF files: 33 selected; 12 foreign prebuilds unchanged; four static helpers unchanged; 29 dynamic files adapted; `native-elf-report.json` |
| ASAR preservation | SHA-256 remains `2a1776f201b4b71f50fadb7edf97c6bb8d049a9f7be5a2da98599e07996f3277`; `native-static-summary.json` |
| Dependency resolution | Both tested package sets report zero unresolved auto-patchelf dependencies |
| Bundled helpers | Node `v24.21.0`, ripgrep `15.2.0`, Codex `0.159.2`; `smoke.log` |
| Native libraries | Sharp/libvips `8.18.6` PNG encode/decode; Classic Level write/read; `smoke.log`, `daily-smoke.log` |
| Native child | Bundled Node spawns shell with `NoNewPrivs: 0`, `Seccomp: 0`; `sudo -n id` returns root |
| Bundled app-server command | `command/exec` with Full access: PID 10615, parent 10573, `NoNewPrivs: 0`, `Seccomp: 0`, sudo returns root; `agent-check.log` |
| Codex workspace sandbox | App-server `command/exec` retains `NoNewPrivs: 1`, `Seccomp: 2`; `agent-check.log`; CLI sandbox also passes |
| Isolated final GUI | Main PID 10654 and Codex child 11066: `NoNewPrivs: 0`, `Seccomp: 0`, UID 1000; `daily-gui-status.json` |
| Chromium renderers | Final GUI renderers: `NoNewPrivs: 1`, `Seccomp: 2`; no disabling flag introduced |
| Desktop window | Hyprland: mapped, visible, class `chatgpt`, native Wayland (`xwayland: false`) |
| Graphics | GPU process loads host Mesa EGL/libgallium and selects `/dev/dri/renderD128`; no EGL initialization failures in final log; performance not measured |
| Plugins / local server | Seven-plugin marketplace written; reconciliation completed; local app-server connected and SQLite initialized; `daily-gui.log` |
| Plugin cache copies | All 808 regular files match the native package bytes and have user-write permission; `plugin-cache-check.txt` |
| Module checks | Desktop-file validation, URI/profile forwarding, platform selection and disabled/handler modes pass; `module-check.log` |
| Home Manager | Daily activation package builds and switch succeeds; `home-build.log`, `home-switch.log` |
| Installed handlers | `codex:` -> `chatgpt.desktop`; HTTP/HTTPS remain `zen-beta.desktop` |

The app-server check uses the shipped protocol's standalone `command/exec`
method. It makes no model request, starts no thread and requires no login.
It proves local command execution through the bundled agent server, rather than
only a host shell's sudo behavior. It does not prove a new authenticated GUI
conversation, which still needs the user's normal app restart.

The first native GUI build used this project's older locked nixpkgs (`7a0f122`),
with glibc `2.42`. It mapped but failed to load the current host Mesa driver,
which needs `GLIBC_2.43`, and fell back to software graphics. That package still
passes helper/sudo checks, but graphics compatibility is limited on this host.
The applied package instead uses the **existing** daily dotfiles nixpkgs pin
`151fa4e8ddfdd8dd25d945ad94ed54a13de9f6e4`, providing glibc `2.44`, with host Mesa
`26.2.4`. The final bounded GUI test used that exact Home Manager launcher.
No lock update was used to resolve the mismatch. Consumers should build with a
package set compatible with their host graphics drivers.

`ELECTRON_RUN_AS_NODE` is not a usable native-module test mode for this Owl
distribution: the attempted probe reported opening an existing browser session.
It establishes no SQLite/PTY loading result. SQLite initialization was observed
in the isolated GUI; PTY operations, hardware USB/TPM operations, fresh OAuth,
credential persistence, authenticated GUI work and overlays remain unverified
with the native package. Earlier FHS results remain historical evidence.

## Dotfiles and activation

`/home/harumi/.dotfiles/Home/home.nix` now overrides `programs.chatgpt.package`
with a self-contained copy under `Home/chatgpt-native/`, using Home Manager's
existing `pkgs`. The four copied source files are `package.nix`, `native.nix`,
`select-native-elf.py` and `sources.json`; its README explains maintenance.
This does not depend on this project's checkout at evaluation or runtime.
The GitHub flake input and imported upstream Home Manager module remain in use.

`flake.nix` and `flake.lock` are byte-identical to their backups. The upstream
ChatGPT input remains pinned at `cdeea8e0b9319091c39d54344bcd4e9c1370399d`, hash
`sha256-tcHxANOrLOMV0cSuZc7QU04n2+DjYyAqUWSuq7ZChdI=`. All other input pins,
including kernel-related inputs, remain unchanged. Only `bin/chatgpt` and
`share/applications/chatgpt.desktop` differ in bytes between the old/new
home-path trees. MIME cache symlinks were regenerated with identical content.

Applied with:

```sh
home-manager switch --flake path:/home/harumi/.dotfiles#harumi --no-write-lock-file
```

Active generation:
`/nix/store/92brn5bswib2pgyyl0qn4rvlfkykf92n-home-manager-generation`.
Installed native app:
`/nix/store/r59g8mw9r4qj2lf5xpg9m78c9q5amn80-chatgpt-26.928.31416`.
Patched payload:
`/nix/store/mx1x4x23i62l99z60brax3qd00nn7jph-chatgpt-payload-26.928.31416`.
Previous generation:
`/nix/store/jdzhmk3ik14r592sqsqgly7yz9wdnpmq-home-manager-generation`.
Backups are under `artifacts/native-launcher/dotfiles-backup/`.

## Quit, relaunch and settle the normal-session check

1. Finish current tasks and use ChatGPT's **Quit** command. Closing a window
   can leave its main process alive. From a normal desktop terminal, check
   `pgrep -a -x ChatGPT`. If app processes remain, use
   `pkill -TERM -x ChatGPT`, then confirm `pgrep -a -x ChatGPT` has no output.
2. From that desktop terminal, run `~/.nix-profile/bin/chatgpt`, or use the
   updated desktop menu entry. Do not launch from an old sandboxed agent shell.
   Do not use the standalone older-package-set `nix run ./nix` for this host.
3. In the new app session, select **local** execution and **Full access**, then
   have its agent execute:

   ```sh
   bash /home/harumi/Projects/Chatgpt-Nixos/scripts/check-session-privileges.sh
   ```

The script prints command ancestry and each process's UID, `NoNewPrivs` and
seccomp status, identifies the sudo path, and runs `sudo -n id`. Expect zero
`NoNewPrivs` in the app main process, Codex app-server and command shell, and
`uid=0(root)` from sudo. Sandboxed Chromium renderers are expected to retain
`NoNewPrivs: 1`; they do not run the Full access agent commands.
The old app session was left running for the user to quit; its flag cannot be
cleared by Home Manager activation. **The normal-session result remains pending.**

To reproduce the no-login app-server check, use `scripts/check-native-agent.py`
with `--shell` pointing at a native diagnostic shell, `--workspace` under
`artifacts/`, and optional `--sudo`. Set `CODEX_HOME` and `XDG_CACHE_HOME` to
artifact paths. `CHATGPT_TEST_SUDO=1 bash scripts/smoke-prototype.sh` runs the
standalone helper check with the benign sudo test enabled.

Rollback: restore `Home/home.nix` from the recorded backup and switch Home
Manager again; the native directory becomes unused. The previous generation's
`activate` script is an immediate user-level rollback option. Neither rollback
requires a system rebuild; these rollback procedures were not exercised.

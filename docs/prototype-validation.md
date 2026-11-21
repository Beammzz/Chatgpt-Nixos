# Prototype validation

This page records the earlier **FHS** prototype. The ARM64 default launcher was
replaced on 2026-10-08; see [native launcher validation](native-launcher.md) for
current build, userspace sudo, graphics and Home Manager results. Earlier GUI
feature/login results below have not all been repeated with the native package.

Tested 2026-10-02 (Asia/Bangkok) on ARM64 NixOS 26.11 with Nix 2.34.8.

## Pins and build

- App version: `26.928.31416`.
- Sources and SHA-256 values: `nix/sources.json`, with versioned official URLs.
- Nixpkgs: `7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f`, locked in `nix/flake.lock`.
- ARM64 main package, payload, and diagnostic FHS shell built successfully.
- Both architecture outputs evaluated. No x86-64 build or runtime test was done.
- Nix build sandboxing remained enabled. No NixOS system configuration was edited.

The existing verified ARM64 download was added to the Nix store under the
versioned fetcher's filename to avoid a duplicate download. This is a build-cache
optimization; the derivation still declares the official versioned URL and hash.

## Runtime results

| Check | Result |
| --- | --- |
| Bundled Node | `v24.21.0` |
| Bundled ripgrep | `15.2.0`; PCRE2 and NEON available |
| Bundled Codex CLI | `0.159.2` |
| Sharp/libvips | Native library loads; image encode/decode passes, libvips `8.18.6` |
| Classic Level | Native database open/write/read/close passes |
| Codex sandbox | Local `/bin/sh` command executes in nested sandbox; `NoNewPrivs: 1`, `Seccomp: 2` |
| GUI | Runs for bounded smoke-test periods and maps a desktop window |
| Compositor | Hyprland reports class `Chatgpt`, title `ChatGPT`, mapped, visible, `xwayland: true` |
| Chromium renderer sandbox | Two ChatGPT renderer processes observed with `NoNewPrivs: 1`, `Seccomp: 2` |
| Bundled plugin setup | Marketplace files installed and reconciliation completed after cache fix |
| Existing ChatGPT credentials | Bundled CLI reports logged in; authenticated model requests succeed |
| Authenticated Codex model session | Small project fixed and verified using `workspace-write` sandbox mode |
| CLI conversation persistence | Fresh process resumes the saved conversation and recalls exact changes |
| GUI authenticated coding | User reports fixture task completed; observed diff fixes only greeting.cjs |
| GUI conversation persistence | User reports conversation remains after quitting and reopening |
| XWayland interaction | User reports rendering works, but looks pixelated and feels laggy |
| Desktop integration | Home Manager evaluation/build and activation pass; installed desktop entry, icon, and `codex:` association verified |
| Native Wayland | Explicit Wayland launch and wrapper-selected Wayland map with `xwayland: false` |
| Native Wayland interaction | User reports sharper rendering and better responsiveness than XWayland |
| Pets / Mini on native Wayland | User reports oversized floating windows and drag animation without window movement; compositor confirms a `1128 × 1770` native floating window on a `1440 × 900` logical desktop |
| Fresh browser login/callback, audio, notifications, USB/TPM hardware operations | Not tested |

The GUI used `--ozone-platform=x11` without disabling any sandbox. A timeout ended
each smoke launch deliberately; exit status `124` denotes that timeout and is not
an application crash. Generated profiles and full logs are under `artifacts/`.
Runtime logs may contain account/session data; they are not committed.

The first launch used a separate Chromium profile but retained the default Codex
home. Subsequent tests explicitly set both `CODEX_HOME` and `--user-data-dir` to
workspace paths, plus `XDG_CACHE_HOME` for the plugin cache. Login was not inferred
from any credentials found during the first launch. The subsequent authenticated
CLI test below separately verifies that the cached login works.

## Authenticated task and persistence

The bundled Codex CLI ran against a disposable Git project under
`artifacts/auth-workflow/project`. A failing Node assertion required changing
`return \`hello ${name}\`;` to `return \`Hello, ${name}!\`;`. The session made that
one-line change, reran the check successfully, and wrote the requested
`arm64-nixos-ok` marker. A separate bundled Node invocation confirmed the result;
the test file and an outside sentinel stayed unchanged.

The experiment used a separate `CODEX_HOME` and mounted the existing cached
authentication file read-only over an empty placeholder. Credentials were not
copied into the test profile or printed. Runtime directories were mounted
read-only; only the fixture project and disposable Codex home were writable,
along with ephemeral runtime files. Model commands additionally used Codex's
`workspace-write` sandbox. This scoped test harness is stricter than the ordinary
desktop FHS wrapper and does not establish desktop-wide filesystem isolation.

Automatic approval review rejected an earlier proposed harness exposing the
host root as writable. That task was not executed; the narrow mounts above
resolved the rejection without disabling sandboxing.

A new process resumed the saved thread and correctly recalled the original and
corrected return statements and verification marker. It made no tool calls
during that recall. This verifies CLI state persistence, rather than GUI project
or conversation restoration. Generated task events, profiles, and fixture files
remain under ignored `artifacts/`.

The user subsequently tested the installed GUI against the disposable project
at `artifacts/gui-validation`, reporting that the work completed and the
conversation survived a full app restart. The observed Git diff changes only
the greeting return statement to the expected value, with the check unchanged.
These GUI results are user-reported; project restoration was not separately
reported. Rendering worked, but the user reported pixelation and lag with the
forced XWayland launcher.

## Native Wayland

A workspace-isolated launch with `--ozone-platform=wayland` mapped successfully;
Hyprland reported class `chatgpt`, `mapped: true`, and `xwayland: false`.
The tested Home Manager wrapper likewise selected Wayland from the current
session and mapped a native window. Profiles and cache were under `artifacts/`;
no existing account was signed out and no sandbox-disabling flags were added.
Bounded launches ended deliberately via timeout.

Two native Wayland renderer processes had `NoNewPrivs: 1`, `Seccomp: 2`.
The sampled GPU process had `NoNewPrivs: 1`, `Seccomp: 0`; that snapshot does
not establish GPU seccomp filtering. It loaded Mesa EGL/libgallium libraries,
which alone does not establish hardware acceleration or performance.
Evidence is under `artifacts/wayland-wrapper/`.

The bundled Owl runtime rejects `--ozone-platform=auto` with
`Invalid ozone platform: auto` (exit 133), despite
[upstream Electron documentation](https://www.electronjs.org/blog/electron-38-0)
describing automatic platform selection. Therefore the wrapper chooses an
explicit Wayland or X11 argument from `XDG_SESSION_TYPE`, with `WAYLAND_DISPLAY`
as a fallback when the session type is unspecified. Explicit configured or
command-line platform arguments take precedence. Launcher checks cover these
branches and profile/URI argument forwarding. The user subsequently reported
that native Wayland is sharper and more responsive than XWayland. This is a
user comparison, not a measured performance benchmark.

The user also reported that Pets and Mini render but have oversized floating
windows. Dragging the pet plays its animation without moving the window;
Hyprland modifier-drag moves the window without the app's drag animation.
A read-only compositor query confirmed an oversized native floating window.
Static inspection found a large drawing canvas and use of `setContentBounds`
for movement, an API documented as unsupported on Wayland. See
[overlay diagnosis](wayland-overlays.md) for the evidence and remaining limits. The
[official Linux guide](https://learn.chatgpt.com/docs/linux/linux-app#wayland-support)
describes native Wayland as experimental and lists floating windows, positioning,
focus, and keyboard shortcuts as areas that may not fully work. The report is
consistent with that documented limitation, but the cause remains a hypothesis.
The user reports successful Pets/Mini on Ubuntu GNOME with a normal launch;
that app's Wayland/XWayland backend and version are unknown. No overlay fix has
been tested. The launcher
continues to select Wayland; explicit `--ozone-platform=x11` remains available
after fully quitting the app.

The corrected launcher was built into the user's Home Manager configuration
and switched successfully. Only the local `chatgpt-nixos` input pin changed;
all other inputs, profile settings, and browser defaults remained the same.
The installed launcher matches the tested wrapper byte-for-byte. Desktop
launches now select native Wayland in this user's session; a full app quit and
relaunch is needed to change an already-running instance's platform.

## Home Manager module

The exported `homeManagerModules.default` targets ARM64 and provides configurable
Codex/Chromium profile paths, launcher arguments, and a `codex:` handler. The
desktop icon uses an absolute store path. The module is opt-in and was
subsequently activated with explicit user authorization.

Tests used Home Manager revision `c8ecc29e5175452bee4a2aa1ba2383856d795338`,
source hash `sha256-rvubAPbh3QCliic3sAK+CXTrPCGgJstY52OTs/5H1J4=`:

```sh
nix build --impure --expr 'import ./scripts/check-home-manager.nix {
  flake = builtins.getFlake (toString ./nix);
  homeManager = (builtins.fetchTree {
    type = "github";
    owner = "nix-community";
    repo = "home-manager";
    rev = "c8ecc29e5175452bee4a2aa1ba2383856d795338";
    narHash = "sha256-rvubAPbh3QCliic3sAK+CXTrPCGgJstY52OTs/5H1J4=";
  }).outPath;
}' --out-link artifacts/home-manager-check
```

Actual Home Manager module evaluation, desktop-file validation, and the generated
MIME configuration passed. A substitute executable confirmed forwarding of URI
arguments and profile paths containing spaces and apostrophes. Disabled mode
preserved the baseline package list; disabling handler registration omitted the
MIME settings. An `xdg-mime query default x-scheme-handler/codex` lookup using only
the generated workspace configuration returned `chatgpt.desktop`. No HTTP/HTTPS
defaults were added. This does not prove receipt of a real OAuth callback.

A staged copy of the actual `/home/harumi/.dotfiles` Home Manager configuration
also built successfully with ChatGPT enabled. Comparison with the active
generation showed only a new `chatgpt` executable, desktop application files,
and managed MIME configuration in the relevant home paths. Existing locked
dependency pins and Chrome MIME defaults were retained. The unmanaged host MIME
file required a backup before activation. Host source and MIME files remained
unchanged during preparation; activation was subsequently authorized and
completed as recorded in `docs/desktop-activation.md`.

## Issues resolved

### Missing nested-sandbox executable

The FHS wrapper used bubblewrap by absolute Nix store path, but the app's Codex
helper also needs `bwrap` on its own PATH. Without it, invoking Codex's sandbox
panicked. Adding `bubblewrap` to `targetPkgs` fixed that dependency.

This bundled CLI uses `codex sandbox -- COMMAND`; it does not have a `linux`
subcommand. The smoke script follows the shipped CLI's actual help text.

### Read-only bundled plugin copies

Nix store normalization makes files `0444` and directories `0555`. The app copies
bundled plugins while retaining those permissions, then rewrites manifests.
That produced `EACCES` even with a writable Codex home.

The wrapper now stages identical plugin content with `u+w` permission metadata
under a cache key containing version, architecture, and source hash prefix. A
lock serializes initialization and an atomic rename publishes the completed
cache. Bubblewrap mounts this directory read-only over the canonical bundled
plugin resource path. The app's copies are writable; its source mount remains
read-only. Vendor runtime binaries and ASAR are unchanged.

### Agent execution sandbox versus desktop execution

The first GUI test inside the agent execution sandbox exited with status `133`
and a Crashpad `setsockopt: Operation not permitted` error. A launch outside that
execution sandbox successfully mapped the window with Chromium sandboxing still
enabled. This distinction matters when reproducing tests from an agent: test
normal desktop access without adding `--no-sandbox`.

## Remaining limits

Fresh browser login needs the `codex:` desktop handler connected to the intended
profile. The module is now installed in the host's user desktop session, and the
`codex:` handler is registered while Chrome remains the HTTP/HTTPS default. The
cached login succeeded in CLI tests, and the user reports successful GUI coding
and conversation persistence. Fresh OAuth login, GUI project restoration, and
end-to-end browser callbacks remain unverified.

The isolated profile reported that sign-in is required for durable threads and
remote control. Some backend routes also returned 404 responses or Cloudflare
challenge pages. Those observations were not bypassed and do not establish a
Nix-specific failure. Native module loading, a rendered window, and one local
sandbox command do not establish complete app feature compatibility.

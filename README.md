# ChatGPT desktop on NixOS

A prototype of the official ChatGPT Linux desktop app, version **26.928.31416**,
using the bundled Electron/Owl runtime in `buildFHSEnv`.

The ARM64 package builds and maps ChatGPT windows on XWayland and native Wayland. Bundled
helpers, native Node libraries, plugin setup, and local sandbox commands pass
smoke checks. An authenticated bundled Codex session fixed a small project and
resumed successfully in a fresh process using existing login credentials.
The user also confirmed GUI coding and conversation persistence after restart.
Native Wayland launches successfully; the user reports sharper rendering and
better responsiveness than XWayland, but Pets and Mini break on native Wayland.
The floating-window failure remains under investigation.
Fresh browser login remains untested.
Development targets ARM64; existing x86-64 definitions have no runtime validation.

## Build and launch

From this directory:

```sh
nix build ./nix --out-link artifacts/result
./artifacts/result/bin/chatgpt --ozone-platform=wayland
```

Or use `nix run ./nix -- --ozone-platform=wayland` in a Wayland session, or
`--ozone-platform=x11` in an X11 session. A normal launch uses the app's
usual user profile, Codex home, desktop services, and a plugin cache under
`$XDG_CACHE_HOME/chatgpt-nixos` (default `~/.cache/chatgpt-nixos`).
This can reuse your existing Codex login, including `~/.codex/auth.json`.

For an experiment with separate workspace profiles:

```sh
mkdir -p artifacts/manual-codex artifacts/cache
CODEX_HOME="$PWD/artifacts/manual-codex" \
XDG_CACHE_HOME="$PWD/artifacts/cache" \
nix run ./nix -- \
  --user-data-dir="$PWD/artifacts/manual-browser" \
  --ozone-platform=wayland
```

`--user-data-dir` isolates Chromium's profile; `CODEX_HOME` separately isolates
Codex state. These settings do not isolate desktop services such as the system
keyring. A `codex:` login callback needs a desktop handler installed for the
intended profile; the commands above do not register one.

The flake lives in `nix/` so local package downloads and extracted artifacts are
not copied into the flake's source. Nixpkgs and both vendor downloads are pinned
by revision/version and hash. The flake permits these specific unfree app
packages; it does not change system-wide Nix configuration.

## Home Manager desktop integration

Add the GitHub input to your existing flake:

```nix
inputs.chatgpt-nixos.url = "github:Beammzz/Chatgpt-Nixos?dir=nix";
```

The `dir=nix` parameter selects the repository's flake directory. Your
`flake.lock` pins the GitHub revision. Update only this input when needed:

```sh
nix flake update chatgpt-nixos
```

Add these modules to your Home Manager configuration:

```nix
modules = [
  inputs.chatgpt-nixos.homeManagerModules.default
  { programs.chatgpt.enable = true; }
];
```

The module installs a launcher, menu entry, icon, and default `codex:` URI handler.
Menu launches and login callbacks use the same wrapper. It selects native
Wayland in a Wayland session and X11 otherwise, while using your usual profiles,
so it can reuse your existing account. The bundled runtime rejects the
`--ozone-platform=auto` flag; the wrapper selects an explicit value itself.
Do not separately add the raw ChatGPT package to `home.packages` alongside this
module, because both provide the same launcher and desktop filename.

Optional settings within `programs.chatgpt`:

```nix
codexHome = "/home/harumi/.local/share/chatgpt-codex";
userDataDir = "/home/harumi/.local/share/chatgpt-browser";
extraArgs = [ "--ozone-platform=x11" ]; # Optional XWayland fallback.
registerLoginHandler = true;
```

Both profile settings default to `null`, retaining app defaults and inherited
environment settings. Specifying empty profile directories starts separate
profiles; it does not copy credentials. Desktop keyring services remain shared.
The module does not register HTTP/HTTPS handlers or run Debian maintainer scripts.
Files were built and checked in an isolated test. On 2026-10-02, the user
explicitly authorized activation in their existing Home Manager configuration;
the desktop integration is now installed on this host.

The actual user's Home Manager configuration builds and has been switched. See
[desktop activation](docs/desktop-activation.md) for the applied changes, backups,
and remaining login checks. Future switches use:

```sh
home-manager switch --flake /home/harumi/.dotfiles#harumi
```

This user-level switch does not require `sudo` or a full flake update.

## Runtime checks

Run the helper/native-library/sandbox checks:

```sh
bash scripts/smoke-prototype.sh
```

This builds the package and diagnostic shell, then tests the bundled Node,
ripgrep, Codex CLI, Sharp image operations, Classic Level database operations,
and a local command inside Codex's own sandbox. Test data goes under `artifacts/`.
No model request or account login is involved.

`scripts/check-home-manager.nix` evaluates the module with an explicit Home
Manager source and builds its desktop/MIME files. It also checks disabled mode
and argument forwarding with a harmless substitute executable. See the
[validation record](docs/prototype-validation.md) for the tested revision.

For a diagnostic shell with the same runtime libraries and mounts:

```sh
XDG_CACHE_HOME="$PWD/artifacts/cache" nix run ./nix#fhs-shell
```

## Packaging choices

- Preserve vendor binaries, ASAR, native modules, and relative resource paths.
  Do not replace the Electron runtime or run Debian maintainer scripts.
- Supply GUI, graphics, audio, credential, USB, TPM, and Qt libraries. Make
  bubblewrap available for Codex's nested Linux sandbox.
- Preserve sandboxing. No `--no-sandbox` or approval-bypass flag is added.
- Stage unchanged bundled plugin files with writable permission metadata in a
  version/hash-specific user cache. Mount that source read-only inside the app's
  FHS environment so plugin copies can be updated in the user's Codex home.
- Provide the desktop entry, icon, and AppStream assets. Retain `codex:` and
  document handlers; omit the vendor's broad HTTP/HTTPS handler registration.

FHS packaging supplies a compatibility filesystem; it is not a security boundary
for the whole app. Normal desktop access and the vendor's own sandbox still
apply. Removing the versioned cache directory is safe when the app is closed;
it will be recreated on the next launch.

See [package inspection](docs/ubuntu-package-inspection.md) for the binary
inventory and [prototype validation](docs/prototype-validation.md) for exact
results and limitations.

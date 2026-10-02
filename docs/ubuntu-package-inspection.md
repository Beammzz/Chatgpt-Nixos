# Official Ubuntu package inspection

Inspected on 2026-10-02 (Asia/Bangkok). Both official packages were downloaded,
extracted, and inspected statically. No vendor code or maintainer script was run.
The host is `aarch64-linux`, NixOS 26.11, with Nix 2.34.8.

## Downloads and reproducibility

The [official Linux installation guide](https://learn.chatgpt.com/docs/linux/linux-app)
links to these mutable URLs:

- `https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_arm64.deb`
- `https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb`

Both contain package `chatgpt`, version **26.928.31416**. The official APT indexes
publish versioned paths, sizes, and SHA-256 values matching the downloaded bytes:

| Debian architecture | Nix system | Download size (bytes) | Installed-Size (KiB) |
| --- | --- | ---: | ---: |
| arm64 | aarch64-linux | 453121290 | 1526812 |
| amd64 | x86_64-linux | 474894546 | 1579189 |

Versioned download URLs for a future fixed-output derivation:

```text
https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_26.928.31416_arm64.deb
https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_26.928.31416_amd64.deb
```

SHA-256 (hex):

```text
arm64 b3c3f37dedfc57db72e810a1dc5be7b22586f0b99b7d4875868b06bdd855ba86
amd64 c463727f1ed5dced78338c8e2a65d889bd153276ff373fd77698ccb9af32d181
```

Indexes are stored in `artifacts/ubuntu/{arm64,amd64}/Packages`. They were fetched
from `deb/dists/stable/main/binary-{arm64,amd64}/Packages` under the same base URL.
The published checksums were compared; repository/package signatures were not
independently verified. Versioned artifact URLs were discovered in the indexes;
the package downloads themselves used the guide's `latest` URLs.

## Package structure

The Debian archives contain `debian-binary`, `control.tar.xz`, `data.tar.xz`, and
`_gpgorigin`. Installed content is primarily under `/usr/lib/chatgpt`.

| Component | Observed content | NixOS implication |
| --- | --- | --- |
| Main runtime | `ChatGPT`, Chromium resources, runtime version `42.3.0` | Preserve vendor runtime initially |
| Runtime metadata | `owl-electron-app.json` identifies runtime `owl` | A stock Electron substitution needs further investigation |
| JS application | `resources/app.asar`, about 535 MB on ARM64 | Keep adjacent to runtime and unpacked native modules |
| App metadata | ASAR root package `openai-codex-electron`; Electron dependency `42.3.0` | Confirms Electron app structure |
| Codex helpers | `resources/codex`, `codex-code-mode-host` | No ELF interpreter or `DT_NEEDED` entries observed |
| Node runtime | `resources/cua_node/bin/node`, version manifest `24.21.0-cua.1` | Dynamic loader and C++ runtime need resolution |
| Other helpers | `rg`, `node_repl`, `tectonic`, Sky executables, browser `extension-host` | Inspect all helper paths, not just the GUI |
| Native modules | SQLite, PTY, filesystem watcher, HID/serial, Sharp/libvips, Classic Level, TPM key module | Preserve ABI and resolve native dependencies |

The Codex helpers, `node_repl`, and Tectonic appear statically linked based on
their ELF headers/dynamic sections. That does not establish whether they load
additional libraries or invoke external tools at runtime.

Both extracted trees contain **45 ELF files**, including platform variants and
duplicate helper copies. ARM64 and AMD64 control metadata have the same library
families; differences are architecture, installed size, and the minimum libgcc
version. Desktop entries are identical.

## Launcher and desktop integration

`/usr/bin/chatgpt` is a symlink to `../lib/chatgpt/codex-launcher`. The launcher is:

```sh
#!/bin/sh
exec "$(dirname "$(readlink -f "$0")")/ChatGPT" "$@"
```

A Nix package must fix the shebang or supply its own wrapper, preserve runtime
resource locations, and provide `dirname`/`readlink` if retaining this script.

The desktop entry uses `Exec=chatgpt %U`, icon `chatgpt`, and registers `codex:`,
HTTP/HTTPS, and document MIME handlers. Install desktop assets under `$out/share`
and verify the `codex:` login callback. Review the broad HTTP/HTTPS registration
before using it in a desktop session. Other assets include AppStream metadata,
a pixmap, documentation, and a software-catalog XML file.

## Dynamic dependencies

The GUI requests `/lib/ld-linux-aarch64.so.1` on ARM64 and
`/lib64/ld-linux-x86-64.so.2` on AMD64. These conventional loader paths explain why
an extracted Ubuntu executable generally needs adaptation for NixOS.

The GUI's linked libraries cover GTK 3, GLib/GIO, accessibility, NSS/NSPR, D-Bus,
CUPS, Expat, ALSA, GBM, X11/XCB, Cairo/Pango, udev, and the compiler/libc runtime.
The package additionally declares notification, desktop utility, graphics driver,
OpenSSL, USB, TPM, and archive-tool dependencies. Declared dependencies and
`DT_NEEDED` entries are not a complete inventory of runtime-loaded libraries.

Notable details for packaging:

- `resources/native/remote-control-device-key.node` directly needs
  `libtss2-esys.so.0`, `libtss2-mu.so.0`, `libtss2-tcti-device.so.0`, and
  `libcrypto.so.3`, in addition to standard runtime libraries.
- `libqt5_shim.so` and `libqt6_shim.so` link to their respective Qt
  Core/Gui/Widgets libraries. These are absent from Debian's declared dependency
  list. Determine whether each is optional before deciding how to package it.
- Sharp's native module carries relative `$ORIGIN` RPATHs to bundled libvips.
  Preserve that directory layout when adding Nix library paths.
- The main GUI's highest observed GLIBC symbol version is `GLIBC_2.25`; the
  bundled Node binary needs `GLIBC_2.28`. The overall ARM64 ELF inventory includes
  references up to `GLIBC_2.30`. These are symbol observations, not a complete
  compatibility guarantee; Debian declares `libc6 >= 2.30`.
- HID and serial modules include Linux ARM, ARM64, x64, x64 musl, and Android
  variants in the same tree. An unfiltered library scan therefore reports
  irrelevant Android/musl dependencies such as `liblog.so` and
  `libc.musl-x86_64.so.1`. Filter by platform, architecture, and libc before
  patching; do not treat every entry in the library union as a host dependency.

## Maintainer scripts and sandboxing

`postinst` configures a signing key, APT repository, and repository opt-in files
under `/etc` and `/var/lib/chatgpt`; it also refreshes desktop metadata. `postrm`
removes those repository files on purge. These scripts should not be run by the
Nix derivation: source updates belong in the Nix package definition.

The supplied AppArmor profile targets `/usr/lib/chatgpt/ChatGPT`, sets
`flags=(unconfined)`, and permits `userns`. Maintainer scripts load or disable it
depending on host AppArmor ABI/support. A Nix store path will differ, so inspect
the actual target system's namespace and AppArmor behavior when testing. No
`chrome-sandbox` file or extracted setuid/setgid file was found in either package.
Do not assume this proves the app's sandbox behavior or disable sandboxing to
make a launch succeed.

## Reproduce the inspection

Run from the workspace with Bash, binutils (`ar`, `readelf`), GNU tar/coreutils,
xz, and Perl with `JSON::PP` and `File::Find` available:

```sh
bash scripts/inspect-ubuntu-package.sh artifacts/ubuntu/arm64/chatgpt_arm64.deb artifacts/ubuntu/arm64
bash scripts/inspect-ubuntu-package.sh artifacts/ubuntu/amd64/chatgpt_amd64.deb artifacts/ubuntu/amd64
```

Use a fresh output directory for a new package version. The script does not
download files, install packages, invoke maintainer scripts, use `ldd`, or run
executables from the extracted app. ASAR inspection reads its JSON header and
root `package.json` directly using Perl.

Each output directory contains `control/`, `root/`, and `reports/`. Reports
include checksums, a file inventory, symlinks, ELF headers/dynamic dependencies,
an ELF summary TSV, a union of library names, and ASAR metadata. The library union
includes foreign-platform prebuilds; use the ELF summary to interpret it.
Downloads and extracted trees currently occupy about **3.9 GiB** in total and
are excluded by `.gitignore`.

## Next implementation step

Build an ARM64 prototype preserving the vendor runtime and resource tree, using
`buildFHSEnv` or a derivation with selected `autoPatchelfHook` processing. The
[NixOS binary packaging guide](https://wiki.nixos.org/wiki/Packaging/Binaries)
documents these methods. Verify a normal sandboxed GUI launch, then login,
credential persistence, local Codex commands, browser integration, and graphics.

No Nix derivation, build, GUI launch, login, or sandbox test was completed during
this inspection. The sandbox denied access to the host Nix daemon during a
read-only environment check; that is an inspection-environment restriction,
not evidence that the app cannot run on NixOS.

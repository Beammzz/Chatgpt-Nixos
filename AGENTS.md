# ChatGPT desktop on NixOS

## Purpose

Inspect the official ChatGPT Linux distribution and develop reproducible NixOS
packaging. This workspace contains packaging work, not the desktop app's source.

## Working conventions

- Use `AGENTS.md` as the canonical agent instruction file.
- Read `docs/ubuntu-package-inspection.md` before changing the packaging approach.
- Prefer official OpenAI downloads and primary NixOS/Nixpkgs documentation.
- Focus development and runtime validation on `aarch64-linux`, as requested.
  Existing `x86_64-linux` definitions are unvalidated; do not expand that work.
- Record the actual package version, download URL, architecture, and SHA-256.
  A URL containing `latest` is mutable and must not be the only version pin.
- Keep downloaded packages, extracted files, and generated reports under
  `artifacts/`; do not commit those files.
- Inspect packages statically first. Do not run package maintainer scripts or
  use `ldd` on vendor executables. Use `ar`, `tar`, and `readelf` instead.
- Do not change host configuration, install the vendor APT repository, or weaken
  sandboxing as a shortcut. Keep experiments within the workspace.
- Preserve the bundled app runtime initially; check native modules and helper
  binaries before considering a different Electron runtime.
- Native-module directories include foreign architectures, Android, and musl
  prebuilds. Select the intended Linux/glibc files before patching; do not hide
  missing libraries with a blanket `autoPatchelfIgnoreMissingDeps = [ "*" ]`.
- Distinguish a package that builds, a GUI that launches, successful login, and
  functioning local Codex commands. Report only what was actually verified.
- Run checks appropriate to the change; static inspection does not establish
  runtime compatibility.

## Initial approach

Evaluate `buildFHSEnv` for a first runnable prototype, then assess whether
`autoPatchelfHook` and launcher wrappers can provide a conventional Nix package.
Check graphics, credentials, login URI handling, bundled helpers, local tools,
and sandbox behavior before declaring the port functional.

## Prototype layout and checks

- The flake is under `nix/`; use `nix build ./nix` and `nix run ./nix`.
  Keep artifacts outside that directory to avoid copying downloads into flake sources.
- Read `docs/prototype-validation.md` for current runtime results and limits.
- Read `docs/native-launcher.md` for the ARM64 native launcher, sudo/graphics
  validation, applied dotfiles override and pending normal-session restart check.
- Run `bash scripts/smoke-prototype.sh` for build, helper, native-library, and
  nested-sandbox checks. GUI tests additionally need normal desktop access.
- Set `CODEX_HOME`, `XDG_CACHE_HOME`, and `--user-data-dir` to workspace artifact
  paths during runtime experiments. Chromium's profile flag alone does not
  isolate Codex state or desktop keyring services.
- Keep the bundled plugin cache workaround unless copy/rewrite behavior has
  been verified against Nix store file permissions. Source bytes stay unchanged.

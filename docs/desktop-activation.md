# User desktop activation

The latest daily-system activation is the
[2026-10-08 native launcher change](native-launcher.md#dotfiles-and-activation).
It retains the GitHub input and login module, with a self-contained native
package override in the dotfiles. The records below describe earlier activations.

The existing Home Manager source is `/home/harumi/.dotfiles`, with configuration
`homeConfigurations.harumi`. A staged copy was built on 2026-10-02 under
`artifacts/desktop-activation/staged-dotfiles`. The user explicitly authorized
the host change with “okay do a switch now”; activation completed on 2026-10-02.

The applied change:

- Adds a local `chatgpt-nixos` input pointing to this workspace's `nix/` flake.
- Imports the Home Manager module and enables `programs.chatgpt`.
- Preserves the existing Chrome defaults for HTML, HTTP, HTTPS, about, and unknown
  schemes when bringing `mimeapps.list` under Home Manager management.
- Uses normal app profiles and therefore can reuse the existing Codex login.

All existing locked input pins were retained; Nix renamed some lock node keys
when inserting the new input. The actual user's staged activation package built
successfully. The generated MIME configuration preserves the previous defaults.
Host source and MIME file checksums remained unchanged during preparation.

The prepared generation is linked at `artifacts/desktop-activation/generation`.
The previous active generation path is recorded in
`artifacts/desktop-activation/previous-generation.txt`. Source checksums are in
`artifacts/desktop-activation/host-source-before.sha256`.

The existing `~/.config/mimeapps.list` is an unmanaged regular file. Activation
must back it up before letting Home Manager create its managed symlink. Do not
use a broad overwrite option to resolve that collision. Preserve the three
original dotfiles files (`flake.nix`, `flake.lock`, `Home/home.nix`) in the same
backup directory before applying the staged files.

The user authorized an exception to the workspace instruction, “Do not change
host configuration,” for this switch. The three staged dotfiles files were
applied and the unmanaged `~/.config/mimeapps.list` backed up. The first switch
stopped on an additional empty unmanaged compatibility file,
`~/.local/share/applications/mimeapps.list`. That file was also backed up, and
the retry completed successfully without forced overwrites.

Backups are under `artifacts/desktop-activation/backups/`, including the original
three dotfiles files, `mimeapps.list`, and `local-applications-mimeapps.list`.
Switch logs are `switch.log` and `switch-retry.log` in the same artifact root.
The first successful activation generation was
`/nix/store/2xqqjdg1d12zfl4sicv0sirpw2iapc6b-home-manager-generation`.

The actual command was:

```sh
home-manager switch --flake path:/home/harumi/.dotfiles#harumi --no-write-lock-file
```

No `sudo`, full `nix flake update`, NixOS rebuild, or vendor APT setup was used.
The launcher is available through `~/.nix-profile/bin/chatgpt`; the desktop entry
is through `~/.nix-profile/share/applications/chatgpt.desktop`. MIME files are now
Home Manager symlinks. Installed-handler queries return `chatgpt.desktop` for
`codex:` and `google-chrome.desktop` for HTTP and HTTPS. The icon is readable at
its absolute store path.

After the user reported pixelation and lag on XWayland, the Home Manager wrapper
was changed to choose explicit native Wayland in a Wayland session, with X11
fallback elsewhere and support for explicit user overrides. Native launches
mapped successfully with `xwayland: false`; the module's platform and argument
checks passed. The user's updated generation was built in the workspace and
switched successfully without changing existing dependency pins. The new active
generation is `/nix/store/8b49wx1cjxbqgspwzlbyk9i83228vibz-home-manager-generation`.
The previous lock file and generation path are recorded under
`artifacts/wayland-activation/`, along with the staged configuration and switch
log. The only host source change for this update was the local ChatGPT input's
lock entry. Existing app instances need a full quit and relaunch to use Wayland.

For an explicit XWayland fallback, quit the app and launch:

```sh
chatgpt --ozone-platform=x11
```

A fresh browser sign-in still needs to be exercised separately; desktop
registration alone does not establish OAuth success. Restoring the former setup
would require reverting the three dotfiles files from the backups, activating
the previous generation recorded above, and restoring both unmanaged MIME files.

For a separate login experiment, use workspace paths for `CODEX_HOME`,
`XDG_CACHE_HOME`, and `--user-data-dir`. Route callbacks to that same profile;
do not sign out the existing user profile to create a fresh-login test.

## GitHub input migration

On 2026-10-02, after publishing `Beammzz/Chatgpt-Nixos`, the user requested
replacing the local ChatGPT flake input with the GitHub repository. The dotfiles
input is now:

```nix
chatgpt-nixos.url = "github:Beammzz/Chatgpt-Nixos?dir=nix";
```

The `nix/` flake remains in its existing repository subdirectory. The consumer's
lock file pins commit `f8e29092a01e21e756244c762742650335f1ebdf` with source hash
`sha256-Jpu35WffvvLBo2O4b/ehnWPQoBzKO1lS9Muprj5L3MM=`. Updating only
`chatgpt-nixos` preserved every other lock node exactly.

A workspace-staged copy of the actual dotfiles configuration built the ARM64
`homeConfigurations.harumi.activationPackage` successfully. The tested
`flake.nix` and `flake.lock` were then applied to `/home/harumi/.dotfiles`, after
checking that the originals had not changed during preparation. Backups,
staged files, and the built generation link are under `artifacts/github-input/`.
The resulting generation is
`/nix/store/alzjbdsikmdk9kqxd4vr1lcz0c5sikax-home-manager-generation`.
No Home Manager activation was performed for this input-only migration.

Future ChatGPT source updates can use `nix flake update chatgpt-nixos` from the
dotfiles directory, followed by the usual Home Manager build/switch workflow.

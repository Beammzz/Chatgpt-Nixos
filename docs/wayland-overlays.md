# Pets and Mini on native Wayland

Investigated 2026-10-02 (Asia/Bangkok), official ARM64 app `26.928.31416`,
bundled Owl/Electron `42.3.0`, Hyprland `0.56.2`.

## User report and observed geometry

The user reports that native Wayland is sharper and more responsive than
XWayland. Pets and Mini render, but their floating windows are much larger than
the visible controls. Dragging the pet plays its walking animation while the
window stays in place. Hyprland modifier-drag moves the window but does not
produce the app's normal animated movement.

The user reports that Pets/Mini previously worked on Ubuntu GNOME with a normal
app launch. The app backend and version in that comparison are unknown. A
Wayland desktop session does not establish that the app used native Wayland.
OpenAI's Linux guide says the app uses XWayland when available in a Wayland
session. XWayland is therefore a plausible explanation for the successful
Ubuntu result, not a verified fact about that run. If the same app version also
works under explicitly selected native Wayland on GNOME, compositor behavior
and runtime protocol support need investigation before attributing this solely
to a general Wayland API limitation.

Read-only `hyprctl -j clients` and `hyprctl -j monitors` queries observed:

| Surface | Size | Position | State |
| --- | --- | --- | --- |
| Main ChatGPT window | `1396 × 822` | `22, 56` | Tiled, native Wayland |
| ChatGPT floating window | `1128 × 1770` | `82, -463` | Floating, native Wayland |
| Internal monitor | Physical `2880 × 1800`, scale `2` | `0, 0` | Logical desktop `1440 × 900` |

Both windows expose class `chatgpt` and title `ChatGPT`, including their initial
class and title. The floating surface is consistent with the reported overlay;
its role was not independently confirmed by toggling Pets/Mini. The inspected
Hyprland configuration contains no ChatGPT-specific size rule. The compositor
reported no configuration errors. Full snapshots are under ignored
`artifacts/wayland-overlays/`.

## Static application evidence

Inspection read the packed JavaScript from the existing ARM64 ASAR into
`artifacts/wayland-overlays/`; vendor files were not modified or executed.

The shared avatar-overlay manager creates a window with appearance
`avatarOverlay`, disables tiling support, and requests floating always-on-top
behavior. Its internal layout mode named `native` describes the pet drawing
layout, not the Wayland/X11 backend.

In that layout, `Dse` calculates a large drawing canvas with substantial margins
for motion. Its height can approach twice the display height. The Linux call
site does not enable `constrainNativeDrawWindowToDisplay`. Thus the large
surface is consistent with the application's own layout calculation; it is
not sufficient evidence of a Hyprland rule forcing a large size.

The renderer drag path updates the pet anchor, calls `applyLayout`, and passes
the resulting window rectangle to `setWindowBounds`. That method invokes
`BrowserWindow.setContentBounds`. The app's separate native window-drag handoff
is gated to macOS (`ad` and `od` return false on Linux).

[Electron's BrowserWindow documentation](https://www.electronjs.org/docs/latest/api/browser-window#winsetcontentboundsbounds-animate)
marks `setContentBounds` and `setPosition` unsupported on Wayland, and documents
that global window coordinates cannot be read using the usual bounds APIs.
This is a plausible explanation for animation updating while the surface does
not move, and for compositor-driven movement not keeping the app's internal
anchor in sync. It does not establish the behavior of the vendor's Owl runtime
on every compositor. This is a static hypothesis, not a trace of Owl's native
methods or a controlled comparison with GNOME.

The [official OpenAI Linux guide](https://learn.chatgpt.com/docs/linux/linux-app#wayland-support)
also lists floating windows, positioning, focus, and keyboard shortcuts among
the limitations of experimental native Wayland support.

## Workaround limits

Hyprland rules can change floating-window appearance or initial geometry, but
a fixed size cannot replace the app's movement API or synchronize its anchor.
Shrinking this drawing canvas may clip the pet or its controls. Matching only
the app class/title would also match the main window. No size rule has been
applied or validated as an overlay fix.

The existing `chatgpt --ozone-platform=x11` override is a compatibility fallback
after a full quit. Native Wayland can remain selected for the main app while
Pets/Mini are hidden. If the movement API limitation is the cause, a complete
native Wayland overlay fix may require changes to overlay behavior in the
app/runtime or a compositor integration. Such changes are not yet established
as necessary; a launcher flag alone has not been shown to solve it either.
No per-window mixture of Wayland and X11 has been established for the bundled
runtime. Sharpness, performance, and overlay behavior under a revised XWayland
scaling configuration remain separate, untested experiments.

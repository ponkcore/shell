# Known Issues

Fork-local bugs that are open and unassigned. Upstream is not affected by
these unless noted; do not file them on `caelestia-dots/shell` without
confirming they reproduce on stock upstream first.

## Dropdown menus unclickable / misbehaving in the utilities drawer

**Status:** open, regressed by design (revert `0e1ce334`, 2026-08-22).

### Symptoms

1. `Menu.qml` popups are not clickable outside their panel; in some positions
   they receive no input at all.
2. In the utilities drawer's record card (`modules/utilities/cards/Record.qml`,
   SplitButton with a mode dropdown), the menu list vanishes after the open
   animation completes.
3. Clicking a dropdown item starts recording immediately instead of selecting
   the mode; the main button should start recording, the menu should only
   select the mode.

### Files involved

- `components/controls/Menu.qml` — popup layer, input mask region
- `modules/drawers/Regions.qml` — menuRegion write/ownership
- `modules/drawers/ContentWindow.qml` — popup hosting
- `modules/utilities/cards/Record.qml` — SplitButton semantics

### History

A fix chain was attempted across `53a3b7a0..1bca7e22` (popup layer keep-alive,
input-mask region plumbing, region ownership guards, diagnostics dump,
recorder button semantics). None of the input attempts landed — the popup
stayed unclickable — and one revision (`1bca7e22`) crashed the shell on a QML
parse error. All four files were rolled back byte-identical to `b34bf280` in
`0e1ce334`; the original symptoms are accepted for now.

### Constraints for the next attempt

- The chain is preserved in git history: read `git log b34bf280..1bca7e22` and
  the diffs before retrying; the failure modes are documented in the commit
  messages.
- Any fix must keep `qml-lint-conventions.py` and `qmllint` clean (CI gates).
- The shell runs on Hyprland via layer-shell; popup input goes through the
  compositor, so "clickable outside panel" interacts with `Regions.qml` input
  region accounting — that coupling is where the previous attempts broke.

### Collateral loss: the recorder button semantics fix

`0e1ce334` reverted the whole chain, including `42bb3ea0`
("recorder menu selects the mode, main button starts recording") — which was
**not** part of the broken menu plumbing. It only changed `Record.qml`:
the four `MenuItem`s each had their own `onClicked: Recorder.start([...])`, so
picking a mode started a recording immediately. That fix moved the start to the
`SplitButton`'s `stateLayer.onClicked` with args derived from the active item,
matching how every other `SplitButton` in the tree behaves.

So symptom 3 above is a separate, already-solved bug that got rolled back as
collateral, not another facet of the input problem.

It re-applies cleanly: `git cherry-pick 42bb3ea0` onto current `main` applies
without conflict and leaves `qmlformat` and `qml-lint-conventions.py` passing.
It was deliberately **not** re-landed here because it is a behaviour change and
needs a decision on its own — but it is independent of the menu fix and can be
cherry-picked without waiting for that.

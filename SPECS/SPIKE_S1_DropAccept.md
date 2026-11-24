# SPIKE S1 — magic drop-accept of a Blizzard-refused item

Goal: prove that a roaming, non-secure frame can intercept a bag-item drop onto a Blizzard action
button when the client itself would refuse the item. Throwaway-quality code; the catcher is drawn
**opaque red** so we can see where it is. No rendering of the item, no saved vars.

## What the spike does

1. `CURSOR_CHANGED` -> `GetCursorInfo()`. If `"item"` and NOT droppable natively
   (`C_Item.GetItemSpell(id) == nil and not C_Item.IsEquippableItem(id)`), arm the catcher; otherwise disarm.
2. Armed: `OnUpdate` walks `ActionButton1..12`, `MultiBar*Button1..12`, finds the one with `IsMouseOver()`,
   `SetAllPoints` the catcher onto it and shows it. None hovered -> hide.
3. Catcher `OnReceiveDrag` and `OnClick` both log `slot=<button.action> item=<link>` plus which handler
   fired, then:
   - if `HasAction(slot)`: call `PickupAction(slot)` then `ClearCursor()` and log whether the slot emptied
     (`HasAction(slot)` after), and whether an `ADDON_ACTION_BLOCKED` / Lua error appeared;
   - else `ClearCursor()`.
4. `/aba` prints armed state and the last drop.

## Questions answered by running it

| # | Question | How to see it | Result |
|---|---|---|---|
| Q1 | `CURSOR_CHANGED` fires when picking up a trade good; `GetCursorInfo` returns itemID | chat log on pickup | **YES** (Era 2026-11-24): `item 6889 [Small Egg]` |
| Q2 | `GetItemSpell` is nil for Heavy Leather / Small Egg; non-nil for a potion | log line `eligible=` | **YES** for Small Egg: `spell=nil equippable=false -> eligible=true`. Potion not yet checked. |
| Q3 | The red catcher follows the cursor over bar buttons, one frame lag at most | eyeball | **YES** — moved MultiBarLeft6 -> MultiBarRight6 -> MultiBarLeft6 cleanly |
| Q4 | Releasing the mouse over the catcher delivers `OnReceiveDrag`, `OnClick`, or both | log | **`OnReceiveDrag` only** (no OnClick logged) |
| Q5 | `PickupAction(slot)` from the drop handler empties an occupied slot (out of combat) | log + bar | OPEN — both drops hit an empty slot; drop onto an occupied one next |
| Q6 | Drop over the catcher does NOT also reach Blizzard (no red "can't do that" error) | eyeball | **YES** (no error reported) |

Note: `CURSOR_CHANGED` (disarm) fires *inside* `ClearCursor()` i.e. before `HandleDrop` returns — fine, `hoveredButton` is captured first.
Tested on Classic Era (`ActionBarAnything_Vanilla.toc`, 11509); Forever still to run.

## Exit

All six answered -> delete nothing yet; M1 replaces `Spike_S1.lua` with `Catcher.lua` / `Overlay.lua`.
Record results in the table above and in the SPEC open questions.
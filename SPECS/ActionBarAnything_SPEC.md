# ActionBarAnything — spec (concise)

Put ANY bag item on a Blizzard action bar slot — including trade goods (Heavy Leather, Small Egg) that
`PlaceAction` refuses because they have no on-use spell — and draw it there with a live total count.

Target: WoW Forever (16001). Era secondary. Slash: `/aba`.

## Problem

Dragging a non-usable item onto an action slot is rejected by the client. There is no API to make a real
action slot hold it. So we **fake the slot**: accept the drop ourselves and draw over the Blizzard button.

## Design

| Piece | Mechanism |
|---|---|
| Detect drag | `CURSOR_CHANGED` -> `GetCursorInfo()` = `"item", itemID, link`. Qualifies for us when Blizzard would refuse it: `C_Item.GetItemSpell(itemID) == nil` AND `not C_Item.IsEquippableItem(itemID)`. |
| Accept drop | ONE roaming `Button` (`ABA_DropCatcher`). While an eligible item is on the cursor, an `OnUpdate` tests every Blizzard action button with `IsMouseOver()`; the catcher is `SetAllPoints` onto the hovered one and shown; hidden otherwise. `OnReceiveDrag`/`OnClick` -> record `{ [actionSlot] = itemID }`, `ClearCursor()`. |
| Occupied slot | If `HasAction(slot)`: try `PickupAction(slot)` + `ClearCursor()` from the drop handler (hardware event). If that is blocked, refuse the drop with `UIErrorsFrame`. Decided by spike S1. |
| Render | One display overlay per claimed slot anchored to the button: icon (`C_Item.GetItemIconByID`), count (`C_Item.GetItemCount(itemID, includeBank)`), tooltip `GameTooltip:SetItemByID`. Refresh on `BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED`. |
| Paging | Data keyed on **action slot number**. On `ACTIONBAR_PAGE_CHANGED`, `UPDATE_BONUS_ACTIONBAR`, `UPDATE_SHAPESHIFT_FORM`, `ACTIONBAR_SLOT_CHANGED`: overlay shown on a button only when `button.action == slot`. |
| Drag out | Overlay `OnDragStart` -> `PickupItem(itemID)`, forget the slot, hide. Right-click also clears. |
| Persist | SavedVariables `ActionBarAnythingDB.chars[UnitGUID("player")].slots[slot] = itemID`. GUID keys only (workspace directive). |

Not secure frames anywhere: nothing is cast, so Show/Hide/anchor work in combat.

## Files

```
ActionBarAnything.toc
Core.lua        addon table, saved vars, slash, events
Catcher.lua     eligibility test, roaming drop catcher
Overlay.lua     per-slot display overlays, paging sync, drag-out
```

## Phases

- [x] **S1 spike** (2026-11-24, Era OK) — roaming catcher accepts a trade-good drop on a Blizzard button; drop arrives as `OnReceiveDrag` only. See `SPIKE_S1_DropAccept.md`. `Spike_S1.lua` kept for reference, not loaded.
- [x] **M1** (2026-11-24, Era OK) — `Core.lua`/`Catcher.lua`/`Overlay.lua`: overlay with icon + bag count (top-left), tooltip, drag out (`PickupItem`), right-click clear, paging sync, GUID-keyed saved vars.
      **Native drag rule**: while something Blizzard accepts is on the cursor (`DRAG_BEGIN "native"`), overlays go mouse-off, alpha 0.4, strata BACKGROUND so the drop reaches the real button; on `DRAG_END` / `ACTIONBAR_SLOT_CHANGED` any claimed slot with `HasAction(slot)` loses its claim.
      **Move**: overlay `OnDragStart` sets `ABA.dragSourceSlot`; catcher drop on another slot moves the claim, same slot is a no-op, a drop anywhere else (`EndDrag`) clears the source.
      Open from S1: `PickupAction(slot)` on an occupied slot from our drop handler — untested.
- [x] **M1b** (2026-11-24) — `Options.lua`: GotJunk-style settings page (title, General: Enable checkbox, How-it-works prose). Account-wide `ActionBarAnythingDB.settings.enabled`; `/aba` opens it, `/aba list|clear|debug`. Disabled = stock drag behaviour, overlays hidden, claims kept.
- [ ] **M1c** (2026-11-24, awaiting in-game OK) — bar-lock: overlay drag-out honours `lockActionBars` + `IsModifiedClick("PICKUPACTION")` (`ABA.ActionBarDragAllowed`); drops are NOT gated (matches Blizzard). Border: a copy of the button's NormalTexture (atlas or file) drawn in OVERLAY above our icon. Options text reworded to "What it does". README.md.
- [x] **Fix: stale drag state** (2026-11-24) — `BeginDrag` dedupe guard assumed an empty-cursor `CURSOR_CHANGED` always closes a drag; it doesn't (drop back into same bag slot, /reload holding an item). Symptom looked like "bottom bars don't accept drops". Guard removed; `OnClick`/`OnMouseUp` on the catcher were tried, never fired, removed — the release is `OnReceiveDrag` on every bar.
- [x] **Fix: click-to-place** (2026-11-24) — ROOT CAUSE of every "intermittent / first drag / main bar" report. The engine delivers drag-and-release as `OnReceiveDrag` but click-pickup → click-place as `OnClick`; the catcher only had the former. Both now call `HandleDrop`. The earlier removal of `OnClick` was based on a drag-only test. "Main bar doesn't work" is withdrawn.
- [x] **Grid during drag** (2026-11-24, needs in-game OK incl. Forever Edit Mode per-bar setting) — Blizzard never fires `ACTIONBAR_SHOWGRID` for a non-placeable item, so with Always Show Action Bars off the empty slots stay hidden. `ABA.ForceGridShown`: SavedVariables marker `settings.gridForcedFrom` written BEFORE `SetCVar("alwaysShowActionBars","1")`, restored on `DRAG_END`; `RepairGridAfterCrash` at login. Hard client crash = marker lost (accepted).
- [ ] **OPEN: overlay on a hidden empty button** — with Always Show off a claimed slot's Blizzard button is hidden, and `SyncAll` gates on `button:IsVisible()`. Expect the overlay to vanish; fix = gate on the bar's visibility (`button:GetParent():IsVisible()`). Confirm in game first.
- [ ] **Failure visibility** — a drag that ends while the catcher was shown but no drop arrived should print one hint line; today it is silent (see analysis 2026-11-24: TOOLTIP-strata collisions with other addons, bar addons replacing Blizzard bars).
- [ ] **M2** — options: count includes bank; click action on a fake slot (nothing / open bags). Untested: options page text heights.
- [ ] **M3** — Era TOC + verification.

## Open questions

- Does the drop onto the catcher arrive as `OnReceiveDrag`, `OnClick`, or both? (S1)
- Is `PickupAction(slot)` allowed from our drop handler out of combat? (S1)
- Is `GetItemSpell` nil for trade goods on Forever (not secret)? (S1)
- Keybind press on a faked slot still fires the (empty) real slot — acceptable; nothing to do.
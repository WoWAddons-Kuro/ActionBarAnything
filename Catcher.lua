-- ActionBarAnything: cursor watching + the single roaming drop catcher.
-- Fires ABA messages:
--   DRAG_BEGIN(mode)   mode = "claimable" (item Blizzard refuses -> we catch it)
--                      or   "native"    (anything Blizzard accepts -> overlays stand aside)
--   DRAG_END()
local ADDON, ABA = ...

-- Eligibility -------------------------------------------------------------------------------------
local function ItemSpellID(itemID)
	if C_Item and C_Item.GetItemSpell then return select(2, C_Item.GetItemSpell(itemID)) end
	return select(2, GetItemSpell(itemID))
end

local function IsEquippable(itemID)
	if C_Item and C_Item.IsEquippableItem then return C_Item.IsEquippableItem(itemID) end
	return IsEquippableItem(itemID)
end

-- An item Blizzard's PlaceAction refuses: no on-use spell and not equippable.
function ABA.IsClaimableItem(itemID)
	return ItemSpellID(itemID) == nil and not IsEquippable(itemID)
end

-- Catcher frame -----------------------------------------------------------------------------------
local catcher = CreateFrame("Button", "ABA_DropCatcher", UIParent)
catcher:SetFrameStrata("TOOLTIP")
catcher:EnableMouse(true)
catcher:RegisterForDrag("LeftButton")
catcher:Hide()

local hilite = catcher:CreateTexture(nil, "OVERLAY")
hilite:SetAllPoints()
hilite:SetColorTexture(0.2, 0.8, 1, 0.35)   -- translucent drop-target highlight

local dragMode          -- nil | "claimable" | "native"
local dragItemID
local hoveredButton

local tracker = CreateFrame("Frame")

-- Rect test instead of IsMouseOver(): a hidden frame keeps its rect but IsMouseOver() is false for
-- it, and an empty button may be hidden (Always Show off, Dominos per-bar empty-buttons off). The
-- catcher is shown over the rect, so the drop itself does not need the button to be visible.
local function RectContainsCursor(frame)
	local l, b, w, h = frame:GetRect()
	if not l or w == 0 then return false end
	local scale = frame:GetEffectiveScale()
	local x, y = GetCursorPosition()
	x, y = x / scale, y / scale
	return x >= l and x <= l + w and y >= b and y <= b + h
end

local function TrackCursor()
	local over
	local buttons = ABA.actionButtons
	for i = 1, #buttons do
		local b = buttons[i]
		if ABA.ButtonBarIsVisible(b) and RectContainsCursor(b) then over = b break end
	end
	if over ~= hoveredButton then
		hoveredButton = over
		if over then
			catcher:ClearAllPoints()
			catcher:SetAllPoints(over)
			catcher:Show()
		else
			catcher:Hide()
		end
	end
end

local function EndDrag()
	if not dragMode then return end
	dragMode, dragItemID, hoveredButton = nil, nil, nil
	catcher:Hide()
	tracker:SetScript("OnUpdate", nil)
	ABA.Bars.ShowEmptySlots(false)
	-- an overlay drag that did not land on another slot: the item went to a bag / the floor / was
	-- cancelled, so the source slot gives up its claim
	local src = ABA.dragSourceSlot
	ABA.dragSourceSlot = nil
	if src then
		ABA.Debug("drag from slot %d ended elsewhere; claim removed", src)
		ABA.ClearSlot(src)
	end
	ABA.Fire("DRAG_END")
end

local function BeginDrag(mode, itemID)
	-- No dedupe on cached state: a drag can end without CURSOR_CHANGED delivering an empty cursor
	-- (drop back into the same bag slot, loading screen, /reload with an item held), which left
	-- dragMode stale and silently ignored the next pickup of the same item. Re-arm every time.
	local isNew = (dragMode ~= mode or dragItemID ~= itemID)
	dragMode, dragItemID, hoveredButton = mode, itemID, nil
	if mode == "claimable" then
		catcher:Hide()
		-- Blizzard will not fire ACTIONBAR_SHOWGRID for this item, so empty slots stay hidden
		-- unless we show the grid ourselves (restored in EndDrag)
		ABA.Bars.ShowEmptySlots(true)
		tracker:SetScript("OnUpdate", TrackCursor)
	else
		tracker:SetScript("OnUpdate", nil)
		catcher:Hide()
		ABA.Bars.ShowEmptySlots(false)
	end
	if isNew then
		ABA.Debug("drag begin: %s item=%s", mode, tostring(itemID))
		ABA.Fire("DRAG_BEGIN", mode)
	end
end

local function HandleDrop(via)
	local button = hoveredButton
	local slot = button and ABA.ActionSlotOf(button)
	local kind, itemID, itemLink = GetCursorInfo()
	ABA.Debug("drop via %s on %s slot=%s cursor=%s %s", via, button and button:GetName() or "nil", tostring(slot), tostring(kind), tostring(itemID))
	if not slot or kind ~= "item" or not itemID then return end

	if HasAction(slot) then
		-- empty the real slot first (hardware-event context; out of combat only)
		if InCombatLockdown() then
			UIErrorsFrame:AddMessage("ActionBarAnything: cannot replace an action in combat", 1, 0.2, 0.2)
			return
		end
		PickupAction(slot)
		ClearCursor()
		if HasAction(slot) then
			UIErrorsFrame:AddMessage("ActionBarAnything: slot is occupied", 1, 0.2, 0.2)
			return
		end
		-- NB: the old action is gone; the dragged item is no longer on the cursor either
	else
		ClearCursor()
	end

	local src = ABA.dragSourceSlot
	ABA.dragSourceSlot = nil          -- consumed: EndDrag (fired by ClearCursor above) must not clear it
	if src and src ~= slot then
		ABA.ClearSlot(src)            -- move: old slot empties
		ABA.Debug("moved claim slot %d -> %d", src, slot)
	end
	ABA.SetSlotItem(slot, itemID)
	ABA.Debug("claimed slot %d <- %s", slot, tostring(itemLink))
end

-- Two ways an item leaves the cursor onto a frame, and the engine delivers them differently:
--   drag-and-release   (mouse held from the bag to the bar)  -> OnReceiveDrag
--   click-to-pick-up, move, click-to-place                    -> OnClick (no drag is in progress)
-- Both must land in HandleDrop. Verified Era 2026-11-24 after a false start: the click path was
-- removed once because a drag-only test never fired it. The catcher only exists while a claimable
-- item is on the cursor, so a left-click on it is always intent to drop.
catcher:SetScript("OnReceiveDrag", function() HandleDrop("OnReceiveDrag") end)
catcher:RegisterForClicks("LeftButtonUp")
catcher:SetScript("OnClick", function(_, mouseButton)
	if mouseButton == "LeftButton" then HandleDrop("OnClick") end
end)

-- Cursor events -----------------------------------------------------------------------------------
tracker:RegisterEvent("CURSOR_CHANGED")
tracker:SetScript("OnEvent", function()
	local kind, id = GetCursorInfo()
	if not kind or not ABA.IsEnabled() then EndDrag() return end
	if kind == "item" and id and ABA.IsClaimableItem(id) then
		BeginDrag("claimable", id)
	else
		-- spells, macros, items with a use, equipment, pet abilities...: Blizzard accepts these
		BeginDrag("native", id)
	end
end)
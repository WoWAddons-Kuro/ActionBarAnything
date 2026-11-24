-- ActionBarAnything: per-slot display overlays drawn over the Blizzard button that currently shows
-- a claimed action slot. Icon, total bag count (top-left), tooltip, drag-out, right-click clear.
-- During a NATIVE drag (something Blizzard accepts) overlays go dim + mouse-off + low strata so the
-- drop reaches the real button; if the real slot then gains an action, our claim is dropped.
local ADDON, ABA = ...

local overlays = {}        -- [blizzardButton] = overlay frame (one per Blizzard button, created lazily)
local nativeDragActive = false

local function ItemCount(itemID)
	if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID, false) end
	return GetItemCount(itemID, false)
end

local function ItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID) end
	return GetItemIcon(itemID)
end

-- Overlay frame -----------------------------------------------------------------------------------
local function SetInteractive(ov, interactive)
	ov:EnableMouse(interactive)
	ov:SetFrameStrata(interactive and "MEDIUM" or "BACKGROUND")
	ov:SetAlpha(interactive and 1 or 0.4)
end

local function CreateOverlay(button)
	local ov = CreateFrame("Button", nil, UIParent)
	ov:SetAllPoints(button)
	ov:SetFrameLevel(button:GetFrameLevel() + 5)
	ov:RegisterForClicks("RightButtonUp")
	ov:RegisterForDrag("LeftButton")

	ov.icon = ov:CreateTexture(nil, "ARTWORK")
	ov.icon:SetAllPoints()
	ov.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- same crop as Blizzard action icons

	ov.count = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	ov.count:SetPoint("TOPLEFT", 2, -2)
	ov.count:SetJustifyH("LEFT")

	ov:SetScript("OnEnter", function(self)
		if not self.itemID then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.itemID)
		GameTooltip:Show()
	end)
	ov:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- drag the item back out: it becomes a real bag item on the cursor. The source slot is NOT
	-- cleared yet - Catcher does that when the item lands on another slot (move), or we do it on
	-- DRAG_END if the cursor was dropped anywhere else. Dropping back on the same slot = no-op.
	ov:SetScript("OnDragStart", function(self)
		if not self.itemID or not self.slot then return end
		if ItemCount(self.itemID) <= 0 then ABA.ClearSlot(self.slot) return end
		ABA.dragSourceSlot = self.slot
		PickupItem(self.itemID)
		-- hide ourselves so the catcher (and a drop on this very slot) is not blocked by our frame
		SetInteractive(self, false)
	end)
	ov:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" and self.slot then ABA.ClearSlot(self.slot) end
	end)

	SetInteractive(ov, true)
	ov:Hide()
	return ov
end

local function RefreshOverlay(ov)
	local itemID = ov.itemID
	if not itemID then return end
	ov.icon:SetTexture(ItemIcon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
	local n = ItemCount(itemID)
	ov.count:SetText(n > 0 and tostring(n) or "0")
	ov.count:SetTextColor(n > 0 and 1 or 0.6, n > 0 and 1 or 0.6, n > 0 and 1 or 0.6)
	ov.icon:SetDesaturated(n == 0)
end

-- Which overlays should be visible right now: for every Blizzard button, the slot it currently
-- displays (button.action, which follows paging/stances) is either claimed or not.
local function SyncAll()
	local enabled = ABA.IsEnabled()
	for i = 1, #ABA.actionButtons do
		local button = ABA.actionButtons[i]
		local slot = button.action
		local itemID = enabled and ABA.GetSlotItem(slot) or nil
		local ov = overlays[button]
		if itemID then
			if not ov then
				ov = CreateOverlay(button)
				overlays[button] = ov
			end
			ov.slot, ov.itemID = slot, itemID
			RefreshOverlay(ov)
			SetInteractive(ov, not nativeDragActive)
			if button:IsVisible() then ov:Show() else ov:Hide() end
		elseif ov then
			ov.slot, ov.itemID = nil, nil
			ov:Hide()
		end
	end
end

local function RefreshCounts()
	for _, ov in pairs(overlays) do
		if ov:IsShown() then RefreshOverlay(ov) end
	end
end

-- A real action landed on a claimed slot (user dropped a spell/usable item there): drop our claim.
local function CheckClaimedSlotsForRealActions()
	local toClear
	ABA.ForEachClaimedSlot(function(slot)
		if HasAction(slot) then
			toClear = toClear or {}
			toClear[#toClear + 1] = slot
		end
	end)
	if toClear then
		for _, slot in ipairs(toClear) do
			ABA.Debug("slot %d got a real action; claim removed", slot)
			ABA.ClearSlot(slot)
		end
	end
end

-- Wiring ------------------------------------------------------------------------------------------
ABA.On("SLOTS_CHANGED", SyncAll)
ABA.On("ENABLED_CHANGED", SyncAll)
ABA.On("DRAG_BEGIN", function(mode)
	nativeDragActive = (mode == "native")
	SyncAll()
end)
ABA.On("DRAG_END", function()
	nativeDragActive = false
	CheckClaimedSlotsForRealActions()
	SyncAll()
end)

local frame = CreateFrame("Frame")
ABA.On("LOGIN", function()
	frame:RegisterEvent("BAG_UPDATE_DELAYED")
	frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	CheckClaimedSlotsForRealActions()
	SyncAll()
end)
frame:SetScript("OnEvent", function(_, event)
	if event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then
		RefreshCounts()
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		CheckClaimedSlotsForRealActions()
		SyncAll()
	else
		-- paging / stance / zoning: button.action may now point at different slots
		C_Timer.After(0, SyncAll)
	end
end)
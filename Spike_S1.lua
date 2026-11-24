-- ActionBarAnything SPIKE S1: can a roaming non-secure frame accept a bag-item drop onto a Blizzard
-- action button when the client itself would refuse the item (trade goods etc.)?
-- Throwaway. Catcher is OPAQUE RED on purpose. See SPECS/SPIKE_S1_DropAccept.md for the questions.
local ADDON, ABA = ...

local function Log(fmt, ...)
	print("|cff33ccffABA|r " .. string.format(fmt, ...))
end

-- Blizzard action button globals we watch (same walk as VelocitySelfBuffHighlights/Bars.lua).
local BAR_PREFIXES = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
	"MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local actionButtons = {}   -- array of existing button frames, built at PLAYER_LOGIN

local function CollectActionButtons()
	wipe(actionButtons)
	for _, prefix in ipairs(BAR_PREFIXES) do
		for i = 1, 12 do
			local b = _G[prefix .. i]
			if b then actionButtons[#actionButtons + 1] = b end
		end
	end
	Log("watching %d action buttons", #actionButtons)
end

-- Eligibility: Blizzard refuses the drop when the item has no on-use spell and is not equippable.
local function GetItemSpellID(itemID)
	if C_Item and C_Item.GetItemSpell then
		local _, spellID = C_Item.GetItemSpell(itemID)
		return spellID
	end
	local _, spellID = GetItemSpell(itemID)
	return spellID
end

local function IsEquippable(itemID)
	if C_Item and C_Item.IsEquippableItem then return C_Item.IsEquippableItem(itemID) end
	return IsEquippableItem(itemID)
end

local function CursorItemBlizzardRefuses()
	local kind, itemID, itemLink = GetCursorInfo()
	if kind ~= "item" or not itemID then return nil end
	local spellID = GetItemSpellID(itemID)
	local equippable = IsEquippable(itemID)
	local eligible = (spellID == nil) and not equippable
	Log("cursor item %s id=%d spell=%s equippable=%s -> eligible=%s",
		tostring(itemLink), itemID, tostring(spellID), tostring(equippable), tostring(eligible))
	if eligible then return itemID, itemLink end
	return nil
end

-- The single roaming catcher ---------------------------------------------------------------------
local catcher = CreateFrame("Button", "ABA_DropCatcher", UIParent)
catcher:SetFrameStrata("TOOLTIP")   -- above everything so the drop lands on us, not the real button
catcher:EnableMouse(true)
catcher:RegisterForClicks("AnyUp", "AnyDown")
catcher:RegisterForDrag("LeftButton")
catcher:Hide()

local bg = catcher:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(1, 0, 0, 1)   -- OPAQUE RED: spike debugging
local label = catcher:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("CENTER")
label:SetText("DROP")

local armedItemID, armedItemLink   -- what is on the cursor while armed
local hoveredButton                -- Blizzard button the catcher currently covers
ABA.lastDrop = nil

local function HandleDrop(handlerName)
	local button = hoveredButton
	if not button then Log("%s fired with no hovered button", handlerName) return end
	local slot = button.action
	local kind, itemID, itemLink = GetCursorInfo()
	Log("%s: button=%s slot=%s cursor=%s %s %s", handlerName, button:GetName(), tostring(slot),
		tostring(kind), tostring(itemID), tostring(itemLink))
	if kind ~= "item" then return end

	-- Q5: can we empty an occupied real slot from here?
	if slot and HasAction(slot) then
		local before = HasAction(slot)
		local ok, err = pcall(PickupAction, slot)
		Log("PickupAction(%d): pcall ok=%s err=%s  (InCombatLockdown=%s)", slot, tostring(ok), tostring(err), tostring(InCombatLockdown()))
		-- cursor now holds the old action (if it worked); drop it on the floor
		ClearCursor()
		Log("slot %d HasAction before=%s after=%s", slot, tostring(before), tostring(HasAction(slot)))
	else
		ClearCursor()
	end

	ABA.lastDrop = { slot = slot, itemID = itemID, itemLink = itemLink, handler = handlerName, button = button:GetName() }
	Log("ACCEPTED: slot %s <- %s (via %s)", tostring(slot), tostring(itemLink), handlerName)
end

catcher:SetScript("OnReceiveDrag", function() HandleDrop("OnReceiveDrag") end)
catcher:SetScript("OnClick", function(_, mouseButton, down) HandleDrop("OnClick(" .. tostring(mouseButton) .. (down and ",down)" or ",up)")) end)
catcher:SetScript("OnDragStart", function() Log("OnDragStart on catcher (unexpected)") end)

-- Arming / tracking -------------------------------------------------------------------------------
local tracker = CreateFrame("Frame")

local function Disarm(reason)
	if armedItemID then Log("disarmed (%s)", reason) end
	armedItemID, armedItemLink, hoveredButton = nil, nil, nil
	catcher:Hide()
	tracker:SetScript("OnUpdate", nil)
end

local function TrackCursor()
	local over
	for i = 1, #actionButtons do
		local b = actionButtons[i]
		if b:IsVisible() and b:IsMouseOver() then over = b break end
	end
	if over ~= hoveredButton then
		hoveredButton = over
		if over then
			catcher:ClearAllPoints()
			catcher:SetAllPoints(over)
			catcher:Show()
			Log("catcher -> %s (slot %s)", over:GetName(), tostring(over.action))
		else
			catcher:Hide()
		end
	end
end

local function Arm(itemID, itemLink)
	armedItemID, armedItemLink = itemID, itemLink
	hoveredButton = nil
	tracker:SetScript("OnUpdate", TrackCursor)
	Log("armed for %s", tostring(itemLink))
end

tracker:RegisterEvent("PLAYER_LOGIN")
tracker:RegisterEvent("CURSOR_CHANGED")
tracker:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		CollectActionButtons()
		Log("spike S1 loaded. Drag a trade good (Heavy Leather, Small Egg) over an action button. /aba for state.")
	elseif event == "CURSOR_CHANGED" then
		local itemID, itemLink = CursorItemBlizzardRefuses()
		if itemID then
			if itemID ~= armedItemID then Arm(itemID, itemLink) end
		else
			Disarm("cursor changed")
		end
	end
end)

SLASH_ACTIONBARANYTHING1 = "/aba"
SlashCmdList.ACTIONBARANYTHING = function()
	Log("armed=%s hovered=%s buttons=%d", tostring(armedItemLink), hoveredButton and hoveredButton:GetName() or "nil", #actionButtons)
	local d = ABA.lastDrop
	if d then
		Log("last drop: slot %s <- %s on %s via %s", tostring(d.slot), tostring(d.itemLink), d.button, d.handler)
	else
		Log("no drop yet")
	end
end
-- ActionBarAnything: addon table, saved variables, action-button walk, event bus, slash.
local ADDON, ABA = ...
_G.ActionBarAnything = ABA

ABA.debug = false

function ABA.Log(fmt, ...)
	print("|cff33ccffABA|r " .. string.format(fmt, ...))
end

function ABA.Debug(fmt, ...)
	if ABA.debug then ABA.Log(fmt, ...) end
end

-- Saved variables ------------------------------------------------------------------------------
-- ActionBarAnythingDB.settings.<key>                               account-wide options
-- ActionBarAnythingDB.chars[<player GUID>].slots[<action slot number>] = itemID
local SETTING_DEFAULTS = { enabled = true }

local function Settings()
	ActionBarAnythingDB = ActionBarAnythingDB or { chars = {} }
	ActionBarAnythingDB.settings = ActionBarAnythingDB.settings or {}
	return ActionBarAnythingDB.settings
end

function ABA.GetSetting(key)
	local v = Settings()[key]
	if v == nil then v = SETTING_DEFAULTS[key] end
	return v
end
function ABA.SetSetting(key, value) Settings()[key] = value end
function ABA.IsEnabled() return ABA.GetSetting("enabled") and true or false end

local function CharDB()
	ActionBarAnythingDB = ActionBarAnythingDB or { chars = {} }
	ActionBarAnythingDB.chars = ActionBarAnythingDB.chars or {}
	local key = UnitGUID("player")
	local c = ActionBarAnythingDB.chars[key]
	if not c then
		c = { slots = {} }
		ActionBarAnythingDB.chars[key] = c
	end
	c.slots = c.slots or {}
	return c
end

function ABA.GetSlotItem(slot)
	return slot and CharDB().slots[slot] or nil
end

function ABA.SetSlotItem(slot, itemID)
	CharDB().slots[slot] = itemID
	ABA.Fire("SLOTS_CHANGED", slot)
end

function ABA.ClearSlot(slot)
	if CharDB().slots[slot] then
		CharDB().slots[slot] = nil
		ABA.Fire("SLOTS_CHANGED", slot)
	end
end

function ABA.ForEachClaimedSlot(fn)
	for slot, itemID in pairs(CharDB().slots) do fn(slot, itemID) end
end

-- Blizzard action buttons ----------------------------------------------------------------------
local BAR_PREFIXES = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
	"MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
ABA.actionButtons = {}   -- array of existing Blizzard action button frames (built at PLAYER_LOGIN)

local function CollectActionButtons()
	wipe(ABA.actionButtons)
	for _, prefix in ipairs(BAR_PREFIXES) do
		for i = 1, 12 do
			local b = _G[prefix .. i]
			if b then ABA.actionButtons[#ABA.actionButtons + 1] = b end
		end
	end
end

-- Internal message bus (modules subscribe; keeps Catcher/Overlay decoupled) -----------------------
local listeners = {}

-- Empty-slot grid ---------------------------------------------------------------------------------
-- With "Always Show Action Bars" off, Blizzard hides empty buttons and only shows them on
-- ACTIONBAR_SHOWGRID, which the engine fires for placeable things only - never for a trade good.
-- So during a claimable drag we flip the CVar ourselves (Blizzard reacts to its own CVAR_UPDATE,
-- no taint) and put it back when the drag ends. The user's value is written to SavedVariables
-- BEFORE the flip so a /reload or disconnect mid-drag can be repaired at next login. (A hard
-- client crash loses unsaved SavedVariables; that case cannot be covered.)
local GRID_CVAR = "alwaysShowActionBars"

function ABA.ForceGridShown(on)
	local s = Settings()
	if on then
		if s.gridForcedFrom then return end                 -- already forced by us
		local cur = GetCVar(GRID_CVAR)
		if cur == "1" then return end                       -- user already shows the grid; nothing to do
		s.gridForcedFrom = cur or "0"
		SetCVar(GRID_CVAR, "1")
		ABA.Debug("grid forced on (was %s)", s.gridForcedFrom)
	elseif s.gridForcedFrom then
		SetCVar(GRID_CVAR, s.gridForcedFrom)
		ABA.Debug("grid restored to %s", s.gridForcedFrom)
		s.gridForcedFrom = nil
	end
end

local function RepairGridAfterCrash()
	local s = Settings()
	if s.gridForcedFrom then
		ABA.Log("restoring 'Always Show Action Bars' to %s (a previous session ended mid-drag)", s.gridForcedFrom)
		ABA.ForceGridShown(false)
	end
end

-- Blizzard's "Lock Action Bars" (Options > Action Bars; CVar lockActionBars) and its override
-- modifier ("Pick Up Action Key", IsModifiedClick("PICKUPACTION"), default Shift). The same rule
-- ActionBarActionButtonMixin applies to drag-start AND drop: when locked, both need the modifier.
function ABA.ActionBarDragAllowed()
	if GetCVar("lockActionBars") ~= "1" then return true end
	return IsModifiedClick("PICKUPACTION")
end

function ABA.On(message, fn)
	listeners[message] = listeners[message] or {}
	table.insert(listeners[message], fn)
end
function ABA.Fire(message, ...)
	local list = listeners[message]
	if not list then return end
	for _, fn in ipairs(list) do fn(...) end
end

-- Events -----------------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		CollectActionButtons()
		CharDB()
		RepairGridAfterCrash()
		ABA.Fire("LOGIN")
	end
end)

-- Slash ------------------------------------------------------------------------------------------
SLASH_ACTIONBARANYTHING1 = "/aba"
SlashCmdList.ACTIONBARANYTHING = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "debug" then
		ABA.debug = not ABA.debug
		ABA.Log("debug %s", ABA.debug and "on" or "off")
	elseif msg == "clear" then
		local c = CharDB()
		wipe(c.slots)
		ABA.Fire("SLOTS_CHANGED")
		ABA.Log("all slots cleared")
	elseif msg == "list" then
		local n = 0
		ABA.ForEachClaimedSlot(function(slot, itemID)
			n = n + 1
			local link = select(2, GetItemInfo(itemID))
			ABA.Log("  slot %d: %s (id %d)", slot, tostring(link), itemID)
		end)
		ABA.Log("%d claimed slot(s), %d action buttons, enabled=%s. /aba list | clear | debug", n, #ABA.actionButtons, tostring(ABA.IsEnabled()))
	else
		ABA.OpenOptions()
	end
end
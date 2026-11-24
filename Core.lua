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
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

-- Action buttons ---------------------------------------------------------------------------------
-- Which frames are action buttons, and how to show empty ones, is bar-provider knowledge
-- (Blizzard vs Dominos vs ...). It lives in Bars\Bars_*.lua behind ABA.Bars; Core only walks
-- the names the active providers hand back.
ABA.actionButtons = {}   -- array of existing action button frames (rebuilt at login and entering world)
local knownButtons = {}  -- [frame] = true, so a rescan never adds a frame twice

local function CollectActionButtons()
	local added = 0
	for _, name in ipairs(ABA.Bars.ButtonNames()) do
		local b = _G[name]
		if b and not knownButtons[b] and b.GetAttribute then
			knownButtons[b] = true
			ABA.actionButtons[#ABA.actionButtons + 1] = b
			added = added + 1
		end
	end
	if added > 0 then ABA.Debug("action buttons: +%d (total %d)", added, #ABA.actionButtons) end
	return added
end
ABA.CollectActionButtons = CollectActionButtons

-- The action slot a button currently shows. Blizzard keeps button.action in step with the
-- secure "action" attribute; bar addons (Dominos SetID(0)s reused Blizzard buttons to kill the
-- stock paging) only maintain the attribute, so the attribute is the authority.
function ABA.ActionSlotOf(button)
	local slot = button:GetAttribute("action")
	if type(slot) ~= "number" then slot = button.action end
	if type(slot) == "number" and slot > 0 then return slot end
	return nil
end

-- The frame whose visibility says whether a button is "on screen": its bar. A button itself may be
-- hidden just because its slot is empty (Always Show off / Dominos per-bar empty-buttons off).
function ABA.ButtonBarIsVisible(button)
	local bar = button:GetParent()
	return bar ~= nil and bar:IsVisible()
end

-- Internal message bus (modules subscribe; keeps Catcher/Overlay decoupled) -----------------------
local listeners = {}

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
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		CollectActionButtons()
		CharDB()
		ABA.Bars.RepairAfterCrash()
		ABA.Fire("LOGIN")
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- bar addons (Dominos bars 7-11) create their buttons after PLAYER_LOGIN
		if CollectActionButtons() > 0 then ABA.Fire("BUTTONS_CHANGED") end
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
		ABA.Log("%d claimed slot(s), %d action buttons (bars: %s), enabled=%s. /aba list | clear | debug", n, #ABA.actionButtons, ABA.Bars.ActiveNames(), tostring(ABA.IsEnabled()))
	else
		ABA.OpenOptions()
	end
end
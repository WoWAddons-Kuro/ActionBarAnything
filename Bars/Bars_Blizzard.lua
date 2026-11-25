-- ActionBarAnything bar provider: Blizzard's stock action bars (always present).
local ADDON, ABA = ...

local BLIZZARD_BUTTON_PREFIXES = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
	"MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

-- Empty-slot grid: with "Always Show Action Bars" off, Blizzard hides empty buttons and only
-- shows them on ACTIONBAR_SHOWGRID, which the engine fires for placeable things only - never for a
-- trade good. So during a claimable drag we flip the CVar (Blizzard reacts to its own CVAR_UPDATE,
-- no taint) and put it back when the drag ends. The user's value is written to SavedVariables
-- BEFORE the flip so a /reload or disconnect mid-drag is repaired at next login. (A hard client
-- crash loses unsaved SavedVariables; that case cannot be covered.)
local GRID_CVAR = "alwaysShowActionBars"
local GRID_MARKER = "gridForcedFrom"   -- ActionBarAnythingDB.settings key: user's value while we hold it

local Blizzard = {}

function Blizzard.IsPresent() return true end

function Blizzard.ButtonNames(into)
	for _, prefix in ipairs(BLIZZARD_BUTTON_PREFIXES) do
		for i = 1, 12 do into[#into + 1] = prefix .. i end
	end
end

function Blizzard.ShowEmptySlots(on)
	local forcedFrom = ABA.GetSetting(GRID_MARKER)
	if on then
		if forcedFrom then return end                        -- already forced by us
		local cur = GetCVar(GRID_CVAR)
		if cur == "1" then return end                        -- user already shows the grid; nothing to do
		ABA.SetSetting(GRID_MARKER, cur or "0")
		SetCVar(GRID_CVAR, "1")
		ABA.Debug("Blizzard grid forced on (was %s)", tostring(cur))
	elseif forcedFrom then
		SetCVar(GRID_CVAR, forcedFrom)
		ABA.SetSetting(GRID_MARKER, nil)
		ABA.Debug("Blizzard grid restored to %s", forcedFrom)
	end
end

function Blizzard.RepairAfterCrash()
	local forcedFrom = ABA.GetSetting(GRID_MARKER)
	if forcedFrom then
		ABA.Log("restoring 'Always Show Action Bars' to %s (a previous session ended mid-drag)", forcedFrom)
		Blizzard.ShowEmptySlots(false)
	end
end

ABA.BarProviders.Blizzard = Blizzard
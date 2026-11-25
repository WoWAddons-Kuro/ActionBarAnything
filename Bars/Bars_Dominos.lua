-- ActionBarAnything bar provider: Dominos (Tuller). Present when the Dominos addon is loaded.
--
-- Facts from Dominos\bars\actionBar\buttons.lua (read 2026-11-24, Era install):
--  * 14 bars x 12 = 168 action slots. Bars 3-6 and 12-14 REUSE Blizzard's MultiBar*Button%d /
--    MultiBar5-7Button%d frames by name (already covered by Bars_Blizzard). Bars 1 (unless
--    "use Blizzard keybind handlers"), 2 and 7-11 are DominosActionButton%d, %d = action slot
--    (1-24, 73-132). Bars 7-11 are created lazily -> Core rescans at PLAYER_ENTERING_WORLD.
--  * Reused Blizzard buttons are SetID(0) and re-parented; the slot is the secure "action"
--    attribute (ABA.ActionSlotOf already prefers that over button.action).
--  * Empty-button visibility is Dominos' own showgrid bitmask. Blizzard's reasons (1 = CVar
--    alwaysShowActionBars, 4) are FILTERED OUT, so the CVar flip in Bars_Blizzard does nothing for
--    Dominos buttons. The public API is Dominos:SetShowEmptyButtons(bool) /
--    Dominos:ShowingEmptyButtons() (Dominos.lua), profile-persisted, reason 32 on every button.
local ADDON, ABA = ...

local MARKER = "dominosEmptyButtonsForcedFrom"   -- settings key: user's value (false) while we hold it

local Dominos = {}

local function API()
	local D = _G.Dominos
	if D and D.SetShowEmptyButtons and D.ShowingEmptyButtons then return D end
	return nil
end

function Dominos.IsPresent()
	return API() ~= nil
end

function Dominos.ButtonNames(into)
	for i = 1, 132 do into[#into + 1] = "DominosActionButton" .. i end
end

function Dominos.ShowEmptySlots(on)
	local D = API()
	if not D then return end
	local forcedFrom = ABA.GetSetting(MARKER)
	if on then
		if forcedFrom ~= nil then return end                 -- already forced by us
		if D:ShowingEmptyButtons() then return end           -- user already shows them
		ABA.SetSetting(MARKER, false)                        -- remember: user had them off
		D:SetShowEmptyButtons(true)
		ABA.Debug("Dominos empty buttons forced on")
	elseif forcedFrom ~= nil then
		D:SetShowEmptyButtons(forcedFrom)
		ABA.SetSetting(MARKER, nil)
		ABA.Debug("Dominos empty buttons restored to %s", tostring(forcedFrom))
	end
end

function Dominos.RepairAfterCrash()
	if ABA.GetSetting(MARKER) ~= nil then
		ABA.Log("restoring Dominos 'Show Empty Buttons' (a previous session ended mid-drag)")
		Dominos.ShowEmptySlots(false)
	end
end

ABA.BarProviders.Dominos = Dominos
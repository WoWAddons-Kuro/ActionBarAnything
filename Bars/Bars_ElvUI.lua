-- ActionBarAnything bar provider: ElvUI (tukui.org). Present when ElvUI's ActionBars module is
-- enabled. ElvUI's bars are built on its own fork of LibActionButton-1.0 ("LibActionButton-1.0-ElvUI").
--
-- Facts from ElvUI\Game\Shared\Modules\ActionBars\ActionBars.lua and
-- ElvUI_Libraries\Game\Shared\LibActionButton-1.0\LibActionButton-1.0.lua (read 2026-11-24, Era install):
--  * Bars: AB:CreateBar(i) for i = 1..10 and 13..15. Frame 'ElvUI_Bar'..id, buttons
--    LAB:CreateButton(i, 'ElvUI_Bar<id>Button<i>', bar) for i = 1..12. Bars 11/12 do not exist.
--  * The slot is the secure "action" attribute (LAB: self:GetAttribute("action")); ABA.ActionSlotOf
--    already prefers that. LAB also mirrors it as button._state_action for insecure code.
--  * Empty-button visibility is LAB's alpha trick, not Hide(): UpdateGrid sets alpha 0 on a shown
--    button with no action unless button.config.showGrid, or the module-level gridCounter > 0.
--    gridCounter is bumped by ACTIONBAR_SHOWGRID/HIDEGRID, which the engine never fires for a
--    trade good - same problem as Blizzard. ShowGrid/HideGrid are file-locals, not exported.
--  * Public, persisted knob: E.db.actionbar['bar'..i].showGrid (per bar), applied by
--    AB:UpdateButtonSettings() -> UpdateConfig(config.showGrid) -> UpdateGrid. That is what the
--    user's ElvUI options "Show Empty Buttons" checkbox writes, so we flip exactly that.
--  * Because the frames are shown at alpha 0, IsVisible() is true and the rect is valid, so the
--    catcher's rect-based hover works even without ShowEmptySlots; the flip is purely so the user
--    can SEE where the empty slots are.
local ADDON, ABA = ...

local MARKER = "elvuiShowGridForcedBars"   -- settings key: array of bar keys we set showGrid=true on

local ELVUI_BAR_IDS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 }

local ElvUI = {}

-- Returns E (ElvUI engine), AB (ActionBars module) when ElvUI's action bars are active, else nil.
local function API()
	local ElvUIAddon = _G.ElvUI
	if type(ElvUIAddon) ~= "table" then return nil end
	local E = ElvUIAddon[1]
	if type(E) ~= "table" or not E.private or not E.private.actionbar or not E.private.actionbar.enable then return nil end
	if type(E.db) ~= "table" or type(E.db.actionbar) ~= "table" then return nil end
	local AB = E.GetModule and E:GetModule("ActionBars", true)
	if type(AB) ~= "table" or type(AB.UpdateButtonSettings) ~= "function" then return nil end
	return E, AB
end

function ElvUI.IsPresent()
	return API() ~= nil
end

function ElvUI.ButtonNames(into)
	for _, barID in ipairs(ELVUI_BAR_IDS) do
		for i = 1, 12 do into[#into + 1] = ("ElvUI_Bar%dButton%d"):format(barID, i) end
	end
end

function ElvUI.ShowEmptySlots(on)
	local E, AB = API()
	if not E then return end
	local forcedBars = ABA.GetSetting(MARKER)
	if on then
		if forcedBars then return end                        -- already forced by us
		forcedBars = {}
		for _, barID in ipairs(ELVUI_BAR_IDS) do
			local barKey = "bar" .. barID
			local barDB = E.db.actionbar[barKey]
			if barDB and barDB.enabled and not barDB.showGrid then
				barDB.showGrid = true
				forcedBars[#forcedBars + 1] = barKey
			end
		end
		if #forcedBars == 0 then return end                  -- user already shows every grid
		ABA.SetSetting(MARKER, forcedBars)                   -- persisted BEFORE the visual change
		AB:UpdateButtonSettings()
		ABA.Debug("ElvUI showGrid forced on for %d bar(s)", #forcedBars)
	elseif forcedBars then
		for _, barKey in ipairs(forcedBars) do
			local barDB = E.db.actionbar[barKey]
			if barDB then barDB.showGrid = false end
		end
		ABA.SetSetting(MARKER, nil)
		AB:UpdateButtonSettings()
		ABA.Debug("ElvUI showGrid restored on %d bar(s)", #forcedBars)
	end
end

function ElvUI.RepairAfterCrash()
	if ABA.GetSetting(MARKER) then
		ABA.Log("restoring ElvUI 'Show Empty Buttons' (a previous session ended mid-drag)")
		ElvUI.ShowEmptySlots(false)
	end
end

ABA.BarProviders.ElvUI = ElvUI
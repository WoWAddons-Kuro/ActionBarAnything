-- ActionBarAnything: bar-provider interface. WHICH frames are action buttons, and HOW empty ones
-- are made visible during a drag, differs between Blizzard's bars and bar addons (Dominos,
-- Bartender4...). Each provider lives in its own Bars_<Name>.lua and implements exactly the
-- methods below; Bars_Select.lua picks the active ones and binds the union onto ABA.Bars.
-- Core/Catcher/Overlay only ever call ABA.Bars - never a provider, never an addon-specific global.
local ADDON, ABA = ...

ABA.BarProviders = {}   -- [name] = provider table, filled by Bars_*.lua

-- Every provider implements all of these:
ABA.BARS_INTERFACE = {
	-- IsPresent() -> bool
	--   Does this provider apply right now? (Blizzard: always. Dominos: addon loaded.)
	"IsPresent",

	-- ButtonNames(into) -> appends global frame names (strings) to the array `into`
	--   Every frame name this provider may use for an action button. Missing globals are fine;
	--   Core skips them. Called at login and again at PLAYER_ENTERING_WORLD for lazy bars.
	"ButtonNames",

	-- ShowEmptySlots(on)
	--   Make empty action buttons visible (on=true) during a drag the engine will not announce
	--   with ACTIONBAR_SHOWGRID, and put them back (on=false). Must be idempotent and must
	--   remember what it changed so a later restore is exact. May be a no-op.
	"ShowEmptySlots",

	-- RepairAfterCrash()
	--   Called once at login. If a previous session ended with ShowEmptySlots(true) outstanding,
	--   undo it now (state must therefore be in SavedVariables).
	"RepairAfterCrash",
}
-- ActionBarAnything: picks the active bar providers and binds their union onto ABA.Bars.
-- Loaded after every Bars_*.lua. Unlike the Client pattern (exactly one flavour), several bar
-- providers can be active at once: Blizzard is always there, and a bar addon adds its own frames
-- on top (Dominos reuses some Blizzard buttons AND creates its own).
local ADDON, ABA = ...

local active = {}   -- array of provider tables that IsPresent()

-- Validate: every provider must implement exactly the interface - nothing missing, nothing extra.
for name, provider in pairs(ABA.BarProviders) do
	local declared = {}
	for _, method in ipairs(ABA.BARS_INTERFACE) do
		declared[method] = true
		if type(provider[method]) ~= "function" then
			ABA.Log("|cffff4040bar provider %s is missing %s()|r", name, method)
		end
	end
	for key, value in pairs(provider) do
		if type(value) == "function" and not declared[key] then
			ABA.Log("|cffff4040bar provider %s has %s() which is not in BARS_INTERFACE|r", name, key)
		end
	end
end

-- Presence is decided lazily (a bar addon may load after us); re-evaluated on every call.
local function Active()
	wipe(active)
	for name, provider in pairs(ABA.BarProviders) do
		if provider.IsPresent() then active[#active + 1] = provider end
	end
	return active
end

ABA.Bars = {
	-- array of every button frame name across active providers (duplicates harmless; Core dedupes frames)
	ButtonNames = function()
		local names = {}
		for _, p in ipairs(Active()) do p.ButtonNames(names) end
		return names
	end,
	ShowEmptySlots = function(on)
		for _, p in ipairs(Active()) do p.ShowEmptySlots(on) end
	end,
	RepairAfterCrash = function()
		for _, p in ipairs(Active()) do p.RepairAfterCrash() end
	end,
	-- for /aba list
	ActiveNames = function()
		local out = {}
		for name, p in pairs(ABA.BarProviders) do
			if p.IsPresent() then out[#out + 1] = name end
		end
		table.sort(out)
		return table.concat(out, ", ")
	end,
}
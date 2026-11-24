-- ActionBarAnything: settings page (Options > AddOns > ActionBarAnything). Style follows GotJunk.
local ADDON, ABA = ...

local optionsCategory, optionsFrame

local function CreateOptions()
	optionsFrame = CreateFrame("Frame", "ActionBarAnythingOptions")
	optionsFrame.name = "ActionBarAnything"

	local title = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16); title:SetText("ActionBarAnything")
	local sub = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); sub:SetWidth(560); sub:SetJustifyH("LEFT")
	sub:SetText("Put any bag item on an action bar slot - even trade goods and other items the game refuses, like Heavy Leather or a Small Egg - and see how many you carry right there on the bar.")

	local BOX_W, PAD = 580, 10
	local last, lastDy = sub, -14
	local function Place(w, dy, dx) w:SetPoint("TOPLEFT", last, "BOTTOMLEFT", dx or 0, dy or lastDy); last = w; lastDy = -6 end

	local function Check(parent, key, label, tip, onChange)
		local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
		cb.Text:SetText(label)
		cb.tooltipText = tip
		cb:SetScript("OnClick", function(self)
			ABA.SetSetting(key, self:GetChecked() and true or false)
			if onChange then onChange() end
		end)
		cb.Update = function(self) self:SetChecked(ABA.GetSetting(key) and true or false) end
		return cb
	end

	local function Section(header)
		local box = CreateFrame("Frame", nil, optionsFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetWidth(BOX_W)
		if box.SetBackdrop then
			box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
			box:SetBackdropColor(0, 0, 0, 0.25); box:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
		end
		local h = box:CreateFontString(nil, "ARTWORK", "GameFontNormal"); h:SetPoint("TOPLEFT", PAD, -PAD); h:SetText(header)
		box.inner_last, box.inner_h = h, PAD + 14
		function box:Add(w, height, dy, dx)
			dy = dy or -6
			w:SetPoint("TOPLEFT", self.inner_last, "BOTTOMLEFT", dx or 0, dy)
			self.inner_last, self.inner_h = w, self.inner_h - dy + height
			return w
		end
		function box:Finish() self:SetHeight(self.inner_h + PAD) end
		return box
	end

	local function Para(parent, text)
		local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		fs:SetWidth(BOX_W - 2 * PAD - 4); fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetSpacing(2)
		fs:SetText(text)
		return fs
	end

	local widgets = {}

	-- General ---------------------------------------------------------------------------------
	local gen = Section("General")
	local enable = gen:Add(Check(gen, "enabled", "Enable ActionBarAnything",
		"When off, items you have placed stay remembered but are not drawn, and dragging items onto the bars behaves exactly like the stock UI.",
		function() ABA.Fire("ENABLED_CHANGED") end), 26, -4, 0)
	widgets[#widgets + 1] = enable
	gen:Finish()
	Place(gen, -14)

	-- What it does ----------------------------------------------------------------------------
	local how = Section("What it does")
	local p1 = how:Add(Para(how,
		"Normally you can only put usable or equippable items on your action bars. With ActionBarAnything you can drag ANY item from your bags onto an empty action bar slot - leather, ore, cloth, eggs, quest drops - " ..
		"and the slot shows the item with a running count of how many you are carrying. Handy for keeping an eye on gathering mats, quest collectibles or vendor trash without opening your bags."), 56, -4, 2)
	local p2 = how:Add(Para(how,
		"|cffffd200Hover|r the slot for the item tooltip.  |cffffd200Drag|r it to another slot to move it, or to a bag to take it off the bar.  |cffffd200Right-click|r to clear the slot.  " ..
		"Your placements are saved per character and follow the slot when the bar pages or you change stance."), 44, -8, 2)
	local p3 = how:Add(Para(how,
		"These slots are for looking, not clicking: the keybind does nothing and the item cannot be used from the bar. Dropping a spell or usable item on one replaces it as normal."), 30, -8, 2)
	how:Finish()
	Place(how, -14)

	optionsFrame.Update = function() for _, w in ipairs(widgets) do w:Update() end end
	optionsFrame:SetScript("OnShow", optionsFrame.Update)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsFrame, "ActionBarAnything")
		Settings.RegisterAddOnCategory(optionsCategory)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(optionsFrame)
	end
end

function ABA.OpenOptions()
	if Settings and Settings.OpenToCategory and optionsCategory then
		Settings.OpenToCategory(optionsCategory:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory and optionsFrame then
		InterfaceOptionsFrame_OpenToCategory(optionsFrame)
		InterfaceOptionsFrame_OpenToCategory(optionsFrame)
	end
end

ABA.On("LOGIN", CreateOptions)
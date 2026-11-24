local _, DN = ...

local button

local function Place()
	local angle = math.rad(DeathNotebookDB.minimapAngle or 215)
	local r = Minimap:GetWidth() / 2 + 8
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local x, y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	DeathNotebookDB.minimapAngle = math.deg(math.atan2(y / scale - my, x / scale - mx)) % 360
	Place()
end

function DN.CreateMinimapButton()
	button = CreateFrame("Button", "DeathNotebookMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(24, 24)
	bg:SetPoint("CENTER")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\DeathNotebook\\Media\\Icon.tga")
	icon:SetSize(17, 17)
	icon:SetPoint("CENTER")
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(_, which)
		if which == "RightButton" then DeathNotebook_AddTarget() else DeathNotebook_Toggle() end
	end)
	button:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", FollowCursor)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Death Notebook")
		GameTooltip:AddLine(DN.L["Left-click: open the book"], 1, 1, 1)
		GameTooltip:AddLine(DN.L["Right-click: add target"], 1, 1, 1)
		GameTooltip:AddLine(DN.L["Drag: move this button"], 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Place()
end

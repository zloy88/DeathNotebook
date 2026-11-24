local _, DN = ...

local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local marks = {} -- nameplate frame -> our own overlay (Blizzard's frames stay untouched)

local function GetMark(plate)
	local m = marks[plate]
	if m then return m end
	m = CreateFrame("Frame", nil, plate)
	m:SetSize(30, 30)
	m:SetPoint("BOTTOM", plate, "TOP", 0, 2)
	m:EnableMouse(false)

	local glow = m:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture("Interface\\AddOns\\DeathNotebook\\Media\\Glow.tga")
	glow:SetPoint("CENTER")
	glow:SetSize(62, 62)
	glow:SetVertexColor(1, 0.08, 0.05)
	glow:SetBlendMode("ADD")

	local skull = m:CreateTexture(nil, "ARTWORK")
	skull:SetAllPoints()
	skull:SetTexture(SKULL)
	skull:SetVertexColor(1, 0.45, 0.4)

	m.kills = m:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
	m.kills:SetPoint("LEFT", m, "RIGHT", 1, 0)
	m.kills:SetTextColor(1, 0.25, 0.2)

	local anim = glow:CreateAnimationGroup()
	anim:SetLooping("BOUNCE")
	local a = anim:CreateAnimation("Alpha")
	a:SetFromAlpha(0.9)
	a:SetToAlpha(0.35)
	a:SetDuration(0.8)
	anim:Play()

	marks[plate] = m
	return m
end

local function Update(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate then return end
	local entry = DN.Option("plates") and DN.FindUnit(unit)
	if entry then
		local m = GetMark(plate)
		m.kills:SetText(entry.kills + entry.deaths > 0 and entry.kills .. ":" .. entry.deaths or "")
		m:Show()
	elseif marks[plate] then
		marks[plate]:Hide()
	end
end

-- Remember units ourselves rather than reading fields off nameplate frames.
local units = {}

function DN.VisibleUnits() return units end

function DN.RefreshNameplates()
	for unit in pairs(units) do Update(unit) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("UNIT_NAME_UPDATE")
f:RegisterEvent("UNIT_FACTION")
f:SetScript("OnEvent", function(_, event, unit)
	unit = DN.Readable(unit)
	if not unit then return end
	if event == "NAME_PLATE_UNIT_ADDED" then
		units[unit] = true
		Update(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		units[unit] = nil
		local plate = C_NamePlate.GetNamePlateForUnit(unit)
		if plate and marks[plate] then marks[plate]:Hide() end
	elseif unit and units[unit] then
		Update(unit)
	end
end)

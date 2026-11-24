local _, DN = ...
local L, Readable = DN.L, DN.Readable

-- Warning at the top of the screen, and the line in unit tooltips.
local SHOW_TIME = 5
local banner
local near = {}     -- entry -> true while the warning shows
local lastSeen = {} -- entry -> GetTime() of the last sighting
local shownUntil = 0

local function CreateBanner()
	banner = CreateFrame("Frame", "DeathNotebookAlert", UIParent)
	banner:Hide()
	banner:SetSize(420, 62)
	banner:SetPoint("TOP", 0, -150)
	banner:SetFrameStrata("HIGH")
	banner:EnableMouse(false)

	local bg = banner:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.06, 0.06, 0.07, 0.92)
	for _, side in ipairs({ "TOP", "BOTTOM" }) do
		local line = banner:CreateTexture(nil, "BORDER")
		line:SetColorTexture(0.7, 0.1, 0.09, 1)
		line:SetPoint(side .. "LEFT")
		line:SetPoint(side .. "RIGHT")
		line:SetHeight(2)
	end
	local icon = banner:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\DeathNotebook\\Media\\Icon.tga")
	icon:SetSize(48, 48)
	icon:SetPoint("LEFT", 10, 0)

	banner.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	banner.title:SetPoint("TOPLEFT", 68, -11)
	banner.title:SetTextColor(0.95, 0.25, 0.2)
	banner.detail = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	banner.detail:SetPoint("TOPLEFT", banner.title, "BOTTOMLEFT", 0, -5)
	banner.detail:SetWidth(335)
	banner.detail:SetJustifyH("LEFT")
	banner.detail:SetWordWrap(false)
end

local function Score(e)
	return L["You %d : %d them"]:format(e.kills, e.deaths)
end

function DN.ShowAlert(e, label)
	if not banner then CreateBanner() end
	local now = GetTime()
	if now >= shownUntil then wipe(near) end
	near[e] = true
	shownUntil = now + SHOW_TIME

	local count, names = 0, {}
	for entry in pairs(near) do
		count = count + 1
		names[count] = DN.FullName(entry)
	end
	if count > 1 then
		table.sort(names)
		banner.title:SetText(L["%d enemies from the book are near!"]:format(count))
		banner.detail:SetText(table.concat(names, ", "))
	else
		banner.title:SetText(L["%s is near!"]:format(label or DN.FullName(e)))
		banner.detail:SetText(Score(e) .. (e.note and e.note ~= "" and "  -  " .. e.note:gsub("\n", " ") or ""))
	end
	banner:Show()
	if DN.Option("sound") then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
	C_Timer.After(SHOW_TIME + 0.05, function()
		if GetTime() >= shownUntil then banner:Hide() end
	end)
end

-- A written player came into view. Warns only if they were out of sight for a while.
function DN.See(unit)
	if Readable(UnitIsUnit(unit, "player")) then return end
	local e = DN.FindUnit(unit)
	if not e then return end
	local now, before = GetTime(), lastSeen[e]
	lastSeen[e] = now
	if e.surname then DN.Describe(e, unit) end
	DN.Stamp(e)
	if before and now - before < DN.Option("cooldown") then return end

	local _, where = IsInInstance()
	where = Readable(where)
	if not DN.Option("alert") or where == "pvp" or where == "arena" then return end
	local name, surname = DN.UnitIdentity(unit)
	DN.ShowAlert(e, name and DN.FullName({ name = name, surname = surname }))
	if DN.RefreshBook then DN.RefreshBook() end
end

-- The plate went away: they were in view until now.
function DN.Lost(unit)
	local e = DN.FindUnit(unit)
	if e then lastSeen[e] = GetTime() end
end

local function OnTooltip(tooltip)
	if tooltip ~= GameTooltip or not DN.Option("tooltip") then return end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	unit = ok and Readable(unit) or nil
	local e = unit and DN.FindUnit(unit)
	if not e then return end
	tooltip:AddLine(L["In the book"] .. "  " .. Score(e), 0.95, 0.25, 0.2)
	if e.note and e.note ~= "" then tooltip:AddLine(e.note, 0.86, 0.83, 0.76, true) end
end

local f = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_LOGIN" }) do
	f:RegisterEvent(event)
end
f:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		DN.See("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		DN.See("mouseover")
	elseif event == "PLAYER_LOGIN" then
		if TooltipDataProcessor and Enum and Enum.TooltipDataType then
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltip)
		else
			GameTooltip:HookScript("OnTooltipSetUnit", OnTooltip)
		end
	else
		unit = Readable(unit)
		if not unit then return end
		if event == "NAME_PLATE_UNIT_ADDED" then DN.See(unit) else DN.Lost(unit) end
	end
end)

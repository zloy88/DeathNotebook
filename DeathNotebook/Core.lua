local _, DN = ...
local L = DN.L

BINDING_HEADER_DEATHNOTEBOOK = "Death Notebook"
BINDING_NAME_DEATHNOTEBOOK_TOGGLE = L["Open / close the book"]
BINDING_NAME_DEATHNOTEBOOK_ADDTARGET = L["Add target to the book"]
BINDING_NAME_DEATHNOTEBOOK_MUTE = L["Turn alerts on / off"]

local entries = {} -- saved array of { name, surname?, guid?, kills, deaths, added, ... }
local recent = {}  -- saved array of enemies who are not written down (yet)
local index = {}   -- lookup key -> entry

-- The client hands addons opaque "secret" values in some situations (instances,
-- battlegrounds). Comparing or indexing with one is an error, so drop them here.
local function Readable(v)
	if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
	return v
end
DN.Readable = Readable

-- strlower only handles ASCII; EU names need Latin-1 and Cyrillic as well.
local function Lower(s)
	s = s:lower()
	s = s:gsub("\195([\128-\158])", function(c)
		return c == "\151" and "\195\151" or "\195" .. string.char(c:byte() + 32)
	end)
	s = s:gsub("\208([\144-\175])", function(c)
		local b = c:byte()
		return b < 160 and "\208" .. string.char(b + 32) or "\209" .. string.char(b - 32)
	end)
	return (s:gsub("\208\129", "\209\145"))
end

-- Forever characters have a first name and a surname, unique per region.
-- UnitName returns them separately; chat and typed text may use a space or "-".
local function Split(name, surname)
	name = strtrim(name)
	local first, last = name:match("^([^%s%-]+)[%s%-]+(.+)$")
	if first then name, surname = first, last end
	surname = surname and strtrim(surname)
	return name, surname ~= "" and surname or nil
end

local function Key(name, surname)
	return Lower(name) .. (surname and " " .. Lower(surname) or "")
end

DN.Lower = Lower

function DN.FullName(e)
	return e.surname and (e.name .. " " .. e.surname) or e.name
end

local function Reindex()
	wipe(index)
	for _, e in ipairs(entries) do index[Key(e.name, e.surname)] = e end
end

local function Print(msg)
	print("|cffc8c2b4Death Notebook:|r " .. msg)
end
DN.Print = Print

function DN.Entries() return entries end
function DN.Recent() return recent end

local DEFAULTS = {
	alert = true, sound = true, cooldown = 60, plates = true, tooltip = true,
	enemiesOnly = true, recent = true, autoAdd = false, sort = "written",
}

function DN.Option(key)
	local o = DeathNotebookDB and DeathNotebookDB.options
	if o and o[key] ~= nil then return o[key] end
	return DEFAULTS[key]
end

function DN.SetOption(key, value)
	DeathNotebookDB.options[key] = value
	if DN.RefreshNameplates then DN.RefreshNameplates() end
	if DN.RefreshBook then DN.RefreshBook() end
end

-- Notes when and where something happened. Enemy positions can't be read, so it is our own.
function DN.Stamp(t)
	t.seen, t.zone = time(), Readable(GetRealZoneText())
	t.map, t.x, t.y = nil, nil, nil
	local map = Readable(C_Map.GetBestMapForUnit("player"))
	local pos = map and Readable(C_Map.GetPlayerMapPosition(map, "player"))
	if not pos then return end
	local x, y = pos:GetXY()
	x, y = Readable(x), Readable(y)
	if x and y and x > 0 then t.map, t.x, t.y = map, x, y end
end

-- An entry written without a surname matches everyone with that first name.
function DN.Find(name, surname)
	return index[Key(name, surname)] or index[Key(name)]
end

-- For typed text: a first name alone also finds an entry that has a surname.
local function FindTyped(name, surname)
	local found = DN.Find(name, surname)
	if found or surname then return found end
	for _, e in ipairs(entries) do
		if Lower(e.name) == Lower(name) then return e end
	end
end

local function Changed()
	Reindex()
	if DN.RefreshNameplates then DN.RefreshNameplates() end
	if DN.RefreshBook then DN.RefreshBook() end
end

local function Valid(s)
	return s ~= "" and not s:find("[%s%d%p]")
end

-- Someone from Recent is written down: take over what is known.
local function TakeRecent(e)
	for i, r in ipairs(recent) do
		if Key(r.name, r.surname) == Key(e.name, e.surname) then
			table.remove(recent, i)
			e.deaths = e.deaths + r.deaths
			e.guid = e.guid or r.guid
			for _, k in ipairs({ "class", "level", "guild", "seen", "zone", "map", "x", "y", "lastDeath" }) do
				e[k] = r[k]
			end
			return
		end
	end
end

local function Capital(s)
	return s:match("^%l") and s:sub(1, 1):upper() .. s:sub(2) or s
end

function DN.Add(name, surname, guid)
	name, surname = Split(name or "", surname)
	if not Valid(name) or (surname and not Valid(surname)) then
		return Print(L["That is not a valid player name."])
	end

	local found = FindTyped(name, surname)
	if found then
		if surname and not found.surname then -- now we know exactly who was meant
			found.surname, found.guid = Capital(surname), guid
			Changed()
		end
		Print(L["%s is already in the book."]:format(DN.FullName(found)))
		return found
	end

	local e = {
		name = Capital(name), surname = surname and Capital(surname),
		guid = guid, kills = 0, deaths = 0, added = time(),
	}
	entries[#entries + 1] = e
	TakeRecent(e)
	if DN.ShowEntry then DN.ShowEntry(e) end
	Changed()
	Print(L["%s has been written into the book."]:format(DN.FullName(e)))
	return e
end

function DN.Remove(entry)
	for i, e in ipairs(entries) do
		if e == entry then
			table.remove(entries, i)
			Changed()
			return Print(L["%s has been struck from the book."]:format(DN.FullName(e)))
		end
	end
end

function DN.RemoveRecent(r)
	for i, v in ipairs(recent) do
		if v == r then
			table.remove(recent, i)
			return Changed()
		end
	end
end

local function SafeGUID(unit)
	local ok, guid = pcall(UnitGUID, unit)
	return ok and Readable(guid) or nil
end

-- name, surname, guid of a player unit; nil if it isn't a player or can't be read
function DN.UnitIdentity(unit)
	if not Readable(UnitExists(unit)) or not Readable(UnitIsPlayer(unit)) then return end
	local name, surname = UnitName(unit)
	name, surname = Readable(name), Readable(surname)
	if not name or name == UNKNOWNOBJECT then return end
	name, surname = Split(name, surname)
	return name, surname, SafeGUID(unit)
end

-- By faction, so duels and enemies without a PvP flag are judged correctly.
function DN.IsEnemy(unit)
	local theirs, ours = Readable(UnitFactionGroup(unit)), Readable(UnitFactionGroup("player"))
	return theirs ~= nil and ours ~= nil and theirs ~= ours
end

-- Entry for a visible unit. Learns the GUID of fully named entries on the way.
function DN.FindUnit(unit)
	local name, surname, guid = DN.UnitIdentity(unit)
	if not name then return end
	if DN.Option("enemiesOnly") and not DN.IsEnemy(unit) then return end
	local e = DN.Find(name, surname)
	if e and e.surname and guid then e.guid = guid end
	return e
end

-- Class, level and guild of a visible unit.
function DN.Describe(t, unit)
	local _, class = UnitClass(unit)
	t.class = Readable(class) or t.class
	t.level = Readable(UnitLevel(unit)) or t.level
	local guild = GetGuildInfo(unit)
	t.guild = Readable(guild) or t.guild
end

function DN.AddUnit(unit)
	local name, surname, guid = DN.UnitIdentity(unit)
	if not name then return Print(L["Target a player first."]) end
	if Readable(UnitIsUnit(unit, "player")) then return Print(L["Things can't be that bad."]) end
	if DN.Option("enemiesOnly") and not DN.IsEnemy(unit) then
		return Print(L["Only enemy players belong in the book. You can change that in the settings."])
	end
	local e = DN.Add(name, surname, guid)
	if e then
		if e.surname then DN.Describe(e, unit) end
		DN.Stamp(e)
		DN.Lost(unit) -- in view already: no warning now
		Changed()
	end
end

function DeathNotebook_AddTarget() DN.AddUnit("target") end

-- name, surname, class, race of a player seen earlier
function DN.IdentityFromGUID(guid)
	local ok, name, surname = pcall(UnitNameFromGUID, guid)
	name, surname = ok and Readable(name) or nil, ok and Readable(surname) or nil
	local ok2, _, class, _, race, _, n, s = pcall(GetPlayerInfoByGUID, guid)
	if not ok2 then class, race, n, s = nil, nil, nil, nil end
	if not name or name == UNKNOWNOBJECT then name, surname = Readable(n), Readable(s) end
	if not name or name == "" then return end
	name, surname = Split(name, surname)
	return name, surname, Readable(class), Readable(race)
end

local function EntryForGUID(guid)
	for _, e in ipairs(entries) do
		if e.guid == guid then return e end
	end
	local name, surname = DN.IdentityFromGUID(guid)
	if name then return DN.Find(name, surname) end
end

local RECENT_MAX, FIGHT_GAP = 32, 300
local lastFight = {}

-- An enemy killed us (killed) or fought us. Written enemies get their score,
-- everyone else goes to Recent.
function DN.RecordEnemy(name, surname, guid, class, killed, unit)
	local e = DN.Find(name, surname)
	if e then
		if not killed then return end
		e.deaths, e.lastDeath = e.deaths + 1, time()
		DN.Stamp(e)
		Print(L["%s killed you. You %d : %d them"]:format(DN.FullName(e), e.kills, e.deaths))
		return Changed()
	end
	if not DN.Option("recent") and not (killed and DN.Option("autoAdd")) then return end

	local key = Key(name, surname)
	if not killed then
		if lastFight[key] and GetTime() - lastFight[key] < FIGHT_GAP then return end
		lastFight[key] = GetTime()
	end
	local r
	for _, v in ipairs(recent) do
		if Key(v.name, v.surname) == key then r = v end
	end
	if not r then
		r = { name = name, surname = surname, deaths = 0 }
		recent[#recent + 1] = r
	end
	r.guid, r.class = guid or r.guid, class or r.class
	if unit then DN.Describe(r, unit) end
	DN.Stamp(r)
	if killed then
		r.deaths, r.lastDeath = r.deaths + 1, time()
		if DN.Option("autoAdd") then
			DN.Add(name, surname, guid)
			return
		end
		Print(L["%s killed you. Open Recent to write the name down."]:format(DN.FullName(r)))
	end
	if #recent > RECENT_MAX then
		local oldest = 1
		for i, v in ipairs(recent) do
			if v.seen < recent[oldest].seen then oldest = i end
		end
		table.remove(recent, oldest)
	end
	if DN.RefreshBook then DN.RefreshBook() end
end

-- Killing blows by the player or their pet.
local function OnPartyKill(attacker, victim)
	attacker, victim = Readable(attacker), Readable(victim)
	if not attacker or not victim then return end
	if attacker ~= SafeGUID("player") and attacker ~= SafeGUID("pet") then return end
	if not victim:find("^Player%-") then return end

	local entry = EntryForGUID(victim)
	if not entry then return end

	entry.kills = entry.kills + 1
	entry.lastKill = time()
	Print(L["%s slain! You %d : %d them"]:format(DN.FullName(entry), entry.kills, entry.deaths))
	Changed()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PARTY_KILL")
f:SetScript("OnEvent", function(_, event, ...)
	if event == "PARTY_KILL" then return OnPartyKill(...) end

	-- This addon used to be called Death Wish: take over its book.
	if not DeathNotebookDB and DeathWishDB then
		DeathNotebookDB, DeathWishDB = DeathWishDB, nil
	end
	DeathNotebookDB = DeathNotebookDB or {}
	DeathNotebookDB.entries = DeathNotebookDB.entries or {}
	DeathNotebookDB.recent = DeathNotebookDB.recent or {}
	DeathNotebookDB.options = DeathNotebookDB.options or {}
	entries, recent = DeathNotebookDB.entries, DeathNotebookDB.recent
	for _, e in ipairs(entries) do e.kills, e.deaths = e.kills or 0, e.deaths or 0 end
	Changed()
	DN.CreateMinimapButton()
	DN.RegisterSlash()

	if Menu and Menu.ModifyMenu then
		Menu.ModifyMenu("MENU_UNIT_ENEMY_PLAYER", function(_, root, context)
			local unit = context and context.unit
			if not unit then return end
			local name, surname, guid = DN.UnitIdentity(unit)
			if not name then return end
			local entry = DN.Find(name, surname)
			root:CreateDivider()
			root:CreateTitle("Death Notebook")
			if entry then
				root:CreateButton(L["Strike from the book"], function() DN.Remove(entry) end)
			else
				-- name captured now: the unit may have changed by the time of the click
				root:CreateButton(L["Write into the book"], function() DN.Add(name, surname, guid) end)
			end
		end)
	end
end)

function DeathNotebook_ToggleAlerts()
	DN.SetOption("alert", not DN.Option("alert"))
	Print(DN.Option("alert") and L["Alerts are on."] or L["Alerts are off."])
end

function DN.Waypoint(e)
	if not e.map then return Print(L["No place is known for %s."]:format(DN.FullName(e))) end
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(e.map, e.x, e.y, { title = DN.FullName(e) })
	elseif C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(e.map) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(e.map, e.x, e.y))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
			C_SuperTrack.SetSuperTrackedUserWaypoint(true)
		end
	else
		return Print(L["A waypoint cannot be set on this map."])
	end
	Print(L["Waypoint set: %s"]:format(DN.FullName(e)))
end

local function Slash(msg)
	local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "" then
		DeathNotebook_Toggle()
	elseif cmd == "add" then
		if rest == "" then DeathNotebook_AddTarget() else DN.Add(rest) end
	elseif (cmd == "remove" or cmd == "way") and rest ~= "" then
		local entry = FindTyped(Split(rest))
		if not entry then
			Print(L["%s is not in the book."]:format(rest))
		elseif cmd == "way" then
			DN.Waypoint(entry)
		else
			DN.Remove(entry)
		end
	elseif cmd == "mute" then
		DeathNotebook_ToggleAlerts()
	else
		Print("/dnb - " .. L["open the book"])
		Print("/dnb add [name] - " .. L["add a name, or your target"])
		Print("/dnb remove <name> - " .. L["strike a name"])
		Print("/dnb way <name> - " .. L["set a waypoint to the last sighting"])
		Print("/dnb mute - " .. L["turn alerts on or off"])
	end
end

-- Done at login, when the other addons are loaded: /dn is only used if it is free.
function DN.RegisterSlash()
	local taken = false
	for k, v in pairs(_G) do
		if type(k) == "string" and k:find("^SLASH_") and Readable(v) == "/dn" then taken = true end
	end
	SLASH_DEATHNOTEBOOK1 = "/dnb"
	SLASH_DEATHNOTEBOOK2 = "/deathnotebook"
	if not taken then SLASH_DEATHNOTEBOOK3 = "/dn" end
	SlashCmdList.DEATHNOTEBOOK = Slash
end

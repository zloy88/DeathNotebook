local _, DW = ...

BINDING_HEADER_DEATHWISH = "Death Wish"
BINDING_NAME_DEATHWISH_TOGGLE = "Open / close the book"
BINDING_NAME_DEATHWISH_ADDTARGET = "Add target to the book"

local entries = {} -- saved array of { name, surname?, guid?, kills, lastKill?, added }
local index = {}   -- lookup key -> entry

-- The client hands addons opaque "secret" values in some situations (instances,
-- battlegrounds). Comparing or indexing with one is an error, so drop them here.
local function Readable(v)
	if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
	return v
end
DW.Readable = Readable

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

function DW.FullName(e)
	return e.surname and (e.name .. " " .. e.surname) or e.name
end

local function Reindex()
	wipe(index)
	for _, e in ipairs(entries) do index[Key(e.name, e.surname)] = e end
end

local function Print(msg)
	print("|cffb01818Death Wish:|r " .. msg)
end
DW.Print = Print

function DW.Entries() return entries end

-- An entry written without a surname matches everyone with that first name.
function DW.Find(name, surname)
	return index[Key(name, surname)] or index[Key(name)]
end

-- For typed text: a first name alone also finds an entry that has a surname.
local function FindTyped(name, surname)
	local found = DW.Find(name, surname)
	if found or surname then return found end
	for _, e in ipairs(entries) do
		if Lower(e.name) == Lower(name) then return e end
	end
end

local function Changed()
	Reindex()
	if DW.RefreshNameplates then DW.RefreshNameplates() end
	if DW.RefreshBook then DW.RefreshBook() end
end

local function Valid(s)
	return s ~= "" and not s:find("[%s%d%p]")
end

local function Capital(s)
	return s:match("^%l") and s:sub(1, 1):upper() .. s:sub(2) or s
end

function DW.Add(name, surname, guid)
	name, surname = Split(name or "", surname)
	if not Valid(name) or (surname and not Valid(surname)) then
		return Print("That is not a valid player name.")
	end

	local found = FindTyped(name, surname)
	if found then
		if surname and not found.surname then -- now we know exactly who was meant
			found.surname, found.guid = Capital(surname), guid
			Changed()
		end
		return Print(DW.FullName(found) .. " is already in the book.")
	end

	local e = {
		name = Capital(name), surname = surname and Capital(surname),
		guid = guid, kills = 0, added = time(),
	}
	entries[#entries + 1] = e
	if DW.ShowLastPage then DW.ShowLastPage() end
	Changed()
	Print(DW.FullName(e) .. " has been written into the book.")
end

function DW.Remove(entry)
	for i, e in ipairs(entries) do
		if e == entry then
			table.remove(entries, i)
			Changed()
			return Print(DW.FullName(e) .. " has been struck from the book.")
		end
	end
end

local function SafeGUID(unit)
	local ok, guid = pcall(UnitGUID, unit)
	return ok and Readable(guid) or nil
end

-- name, surname, guid of a player unit; nil if it isn't a player or can't be read
function DW.UnitIdentity(unit)
	if not Readable(UnitExists(unit)) or not Readable(UnitIsPlayer(unit)) then return end
	local name, surname = UnitName(unit)
	name, surname = Readable(name), Readable(surname)
	if not name or name == UNKNOWNOBJECT then return end
	name, surname = Split(name, surname)
	return name, surname, SafeGUID(unit)
end

-- Entry for a visible unit. Learns the GUID of fully named entries on the way.
function DW.FindUnit(unit)
	local name, surname, guid = DW.UnitIdentity(unit)
	if not name then return end
	local e = DW.Find(name, surname)
	if e and e.surname and guid then e.guid = guid end
	return e
end

function DW.AddUnit(unit)
	local name, surname, guid = DW.UnitIdentity(unit)
	if not name then return Print("Target a player first.") end
	if Readable(UnitIsUnit(unit, "player")) then return Print("Things can't be that bad.") end
	DW.Add(name, surname, guid)
end

function DeathWish_AddTarget() DW.AddUnit("target") end

local function EntryForGUID(guid)
	for _, e in ipairs(entries) do
		if e.guid == guid then return e end
	end
	local ok, name, surname = pcall(UnitNameFromGUID, guid)
	name, surname = ok and Readable(name) or nil, ok and Readable(surname) or nil
	if not name or name == UNKNOWNOBJECT then
		local _, _, _, _, _, n, s = GetPlayerInfoByGUID(guid)
		name, surname = Readable(n), Readable(s)
	end
	if not name or name == "" then return end
	return DW.Find(Split(name, surname))
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
	Print(("%s slain! Kills: |cffffd100%d|r"):format(DW.FullName(entry), entry.kills))
	Changed()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PARTY_KILL")
f:SetScript("OnEvent", function(_, event, ...)
	if event == "PARTY_KILL" then return OnPartyKill(...) end

	DeathWishDB = DeathWishDB or {}
	DeathWishDB.entries = DeathWishDB.entries or {}
	entries = DeathWishDB.entries
	Changed()
	DW.CreateMinimapButton()

	if Menu and Menu.ModifyMenu then
		Menu.ModifyMenu("MENU_UNIT_ENEMY_PLAYER", function(_, root, context)
			local unit = context and context.unit
			if not unit then return end
			local name, surname, guid = DW.UnitIdentity(unit)
			if not name then return end
			local entry = DW.Find(name, surname)
			root:CreateDivider()
			root:CreateTitle("Death Wish")
			if entry then
				root:CreateButton("Strike from the book", function() DW.Remove(entry) end)
			else
				-- name captured now: the unit may have changed by the time of the click
				root:CreateButton("Write into the book", function() DW.Add(name, surname, guid) end)
			end
		end)
	end
end)

SLASH_DEATHWISH1 = "/deathwish"
SLASH_DEATHWISH2 = "/dw"
SlashCmdList.DEATHWISH = function(msg)
	local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "" then
		DeathWish_Toggle()
	elseif cmd == "add" then
		if rest == "" then DeathWish_AddTarget() else DW.Add(rest) end
	elseif cmd == "remove" and rest ~= "" then
		local entry = FindTyped(Split(rest))
		if entry then DW.Remove(entry) else Print(rest .. " is not in the book.") end
	else
		Print("/dw - open the book")
		Print("/dw add [name] - add a name, or your target")
		Print("/dw remove <name>")
	end
end

local _, DN = ...
local Readable = DN.Readable

-- Who killed us, and who fought us. Addons can't read the combat log on Forever;
-- the game's death recap still lists who hit us last.
local ALLIANCE = { Human = true, Dwarf = true, NightElf = true, Gnome = true, Draenei = true, Worgen = true }
local HORDE = { Orc = true, Scourge = true, Tauren = true, Troll = true, BloodElf = true, Goblin = true }

local function SameFaction(race)
	local side = ALLIANCE[race] and "Alliance" or HORDE[race] and "Horde"
	return side ~= nil and side == Readable(UnitFactionGroup("player"))
end

local function InBattleground()
	local _, where = IsInInstance()
	where = Readable(where)
	return where == "pvp" or where == "arena"
end

local function Record(guid, killed)
	local name, surname, class, race = DN.IdentityFromGUID(guid)
	if not name then return end
	if DN.Option("enemiesOnly") and race and SameFaction(race) then return end
	DN.RecordEnemy(name, surname, guid, class, killed)
end

local lastRecap

-- true when a fresh recap was read
local function ReadRecap()
	local ok, has = pcall(C_DeathRecap.HasRecapEvents)
	if not ok or not Readable(has) then return false end
	local ok2, events = pcall(C_DeathRecap.GetRecapEvents)
	events = ok2 and Readable(events) or nil
	if type(events) ~= "table" or #events == 0 then return false end

	local last, stamp -- the killing blow; the recap normally lists it first
	local players, order = {}, {}
	for _, ev in ipairs(events) do
		local t = tonumber(Readable(ev.timestamp))
		if not last or (t and stamp and t > stamp) then last, stamp = ev, t end
		local guid = Readable(ev.sourceGUID)
		if type(guid) == "string" and guid:find("^Player%-") and not players[guid] then
			players[guid] = true
			order[#order + 1] = guid
		end
	end
	if stamp then -- an old recap, the new one is not there yet
		if stamp == lastRecap or (stamp > 1e9 and time() - stamp > 60) then return false end
		lastRecap = stamp
	end

	local killer = Readable(last.sourceGUID)
	if type(killer) ~= "string" then killer = nil end
	-- A pet's killing blow counts for its owner only if nobody else could be meant.
	if killer and killer:find("^Pet%-") then killer = #order == 1 and order[1] or nil end
	for _, guid in ipairs(order) do
		if guid ~= Readable(UnitGUID("player")) then Record(guid, guid == killer) end
	end
	return true
end

local function OnDeath()
	if not C_DeathRecap or InBattleground() then return end
	local tries = 0
	local function Try()
		tries = tries + 1
		if not ReadRecap() and tries < 5 then C_Timer.After(0.6, Try) end
	end
	C_Timer.After(0.3, Try)
end

-- We were hit: enemy players in combat who target us count as a fight. Only a suggestion
-- for Recent, it never changes the score.
local nextCheck = 0
local function CheckAttackers()
	local now = GetTime()
	if now < nextCheck or not DN.Option("recent") or InBattleground() then return end
	nextCheck = now + 1
	local function Check(unit)
		if not Readable(UnitExists(unit)) or not DN.IsEnemy(unit) then return end
		if not Readable(UnitAffectingCombat(unit)) or not Readable(UnitIsUnit(unit .. "target", "player")) then return end
		local name, surname, guid = DN.UnitIdentity(unit)
		if name then DN.RecordEnemy(name, surname, guid, nil, false, unit) end
	end
	Check("target")
	for unit in pairs(DN.VisibleUnits()) do Check(unit) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterUnitEvent("UNIT_COMBAT", "player")
f:SetScript("OnEvent", function(_, event, _, action)
	if event == "PLAYER_DEAD" then
		OnDeath()
	elseif Readable(action) == "WOUND" then
		CheckAttackers()
	end
end)

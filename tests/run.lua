-- lua5.1 tests/run.lua : loads the addon against a small fake WoW API
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local handlers, named, frames = {}, {}, {}
local methods = {}
local function obj()
	local o = { scripts = {}, shown = true }
	return setmetatable(o, { __index = function(_, k)
		if methods[k] then return methods[k] end
		if k:match("^%u") then return function() end end
	end })
end
function methods:SetScript(e, fn) self.scripts[e] = fn end
function methods:HookScript(e, fn) local old = self.scripts[e]; self.scripts[e] = function(...) if old then old(...) end fn(...) end end
function methods:RegisterEvent(e) handlers[e] = handlers[e] or {}; table.insert(handlers[e], self) end
function methods:CreateTexture() return obj() end
function methods:CreateFontString() return obj() end
function methods:CreateAnimationGroup() return obj() end
function methods:CreateAnimation() return obj() end
function methods:SetText(t) self.txt = tostring(t) end
function methods:GetText() return self.txt or "" end
function methods:GetStringWidth() return 10 end
function methods:IsMouseOver() return false end
function methods:SetShown(s) if s then self:Show() else self:Hide() end end
function methods:Show() if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
function methods:Hide() if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
function methods:IsShown() return self.shown end
function CreateFrame(_, name, parent) local o = obj(); o.parent = parent; table.insert(frames, o); if name then _G[name] = o end return o end
UIParent, GameTooltip, UISpecialFrames, SlashCmdList, SOUNDKIT = obj(), obj(), {}, {}, {}
PlaySound = function() end
tinsert, time, date, UNKNOWNOBJECT = table.insert, os.time, os.date, "Unknown"
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
issecretvalue = function(v) return v == SECRET end
GetRealmName = function() return "My Realm" end
GetNormalizedRealmName = function() return "MyRealm" end
local names = { ["Player-2-B"] = { "Bob", "Other" } }
UnitNameFromGUID = function(g) local i = names[g]; if i then return i[1], i[2] end end
local log = {}; print_ = print; print = function(s) log[#log + 1] = s end
local unitsT = { player = { "Me" }, target = { "Bob", "Smith" }, nameplate1 = { "Bob", "Smith" }, nameplate2 = { "Foe", "Where" }, nameplate3 = { SECRET, SECRET } }
UnitExists = function(u) return unitsT[u] ~= nil end
UnitIsPlayer = function(u) return true end
UnitName = function(u) return unitsT[u][1], unitsT[u][2] end
UnitIsUnit = function(a, b) return a == b end
UnitGUID = function(u) return ({ player = "Player-1-ME", pet = "Pet-1", target = "Player-1-B", nameplate1 = "Player-1-B" })[u] end
local infos = { ["Player-1-B"] = { "Bob", "SomeRealm" }, ["Player-2-B"] = { "Bob", "Other" }, ["Player-2-F"] = { "Foe", "ElseWhere" } }
GetPlayerInfoByGUID = function(g) local i = infos[g]; if i then return 1, 2, 3, 4, 5, i[1], i[2] end end
local plates = { nameplate1 = obj(), nameplate2 = obj(), nameplate3 = obj() }
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end }
local menuFn; Menu = { ModifyMenu = function(_, fn) menuFn = fn end }
local function fire(e, ...) for _, h in ipairs(handlers[e]) do h.scripts.OnEvent(h, e, ...) end end
local function markOf(u) for _, f in ipairs(frames) do if f.parent == plates[u] then return f.shown, f.kills.txt end end end
local n = 0
Minimap = obj(); Minimap.GetWidth = function() return 140 end; Minimap.GetCenter = function() return 100, 100 end
Minimap.GetEffectiveScale = function() return 2 end; GetCursorPosition = function() return 200, 300 end
local function eq(a, b, m) n = n + 1; if a ~= b then error((m or "") .. ": got " .. tostring(a) .. " want " .. tostring(b), 2) end end

local now, zone, friend, where = 1000, "Duskwood", {}, "none"
GetLocale = function() return "enUS" end
GetTime = function() return now end
GetRealZoneText = function() return zone end
IsInInstance = function() return where ~= "none", where end
UnitFactionGroup = function(u) return (u == "player" or friend[u]) and "Alliance" or "Horde" end
UnitClass = function() return "Rogue", "ROGUE" end
UnitLevel = function() return 30 end
GetGuildInfo = function() return "Bad Guild" end
local attacking = {}
UnitAffectingCombat = function(u) return attacking[u] end
local isUnit = UnitIsUnit
UnitIsUnit = function(a, b)
	local unit = a:match("^(.+)target$")
	if unit and b == "player" then return attacking[unit] or false end
	return isUnit(a, b)
end
RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 1, b = 0 } }
local canPin, pin = true, nil
C_Map = {
	GetBestMapForUnit = function() return 47 end,
	GetPlayerMapPosition = function() return { GetXY = function() return .25, .5 end } end,
	CanSetUserWaypointOnMap = function() return canPin end,
	SetUserWaypoint = function(p) pin = p end,
}
UiMapPoint = { CreateFromCoordinates = function(...) return { ... } end }
local timers = {}
C_Timer = { After = function(t, fn) table.insert(timers, fn) end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
local recap; C_DeathRecap = { HasRecapEvents = function() return recap ~= nil end, GetRecapEvents = function() return recap end }
local tooltipFn; Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipFn = fn end }
function methods:RegisterUnitEvent(e) self:RegisterEvent(e) end
function methods:HasFocus() return false end
local DN = {}
DeathWishDB = { entries = { { name = "Old", kills = 3, added = 1 } } }
for _, f in ipairs({ "Locale", "Core", "Nameplates", "Alert", "Deaths", "Book", "Minimap" }) do assert(loadfile("DeathNotebook/" .. f .. ".lua"))("DeathNotebook", DN) end
fire("PLAYER_LOGIN")
eq(DN.Entries()[1].name, "Old", "old book taken over"); eq(DeathWishDB, nil); DN.Remove(DN.Entries()[1])
local E = DN.Entries()
for i = 1, 3 do fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
eq(markOf("nameplate1"), nil, "unmarked")
DeathNotebook_AddTarget(); eq(#E, 1); eq(DN.FullName(E[1]), "Bob Smith"); eq(markOf("nameplate1"), true, "marked")
DN.Add("bob"); DN.Add("bob-smith"); DN.Add("Bob Smith"); eq(#E, 1, "dup")
DN.Add("foe"); eq(E[2].name, "Foe"); eq(markOf("nameplate2"), true, "cross-realm wildcard")
eq(markOf("nameplate3"), nil, "secret ignored")
for _, bad in ipairs({ "", "  ", "a b c", "x1" }) do DN.Add(bad) end; eq(#E, 2, "invalid")
fire("PARTY_KILL", "Player-1-ME", "Player-1-B"); eq(E[1].kills, 1)
fire("PARTY_KILL", "Pet-1", "Player-1-B"); eq(E[1].kills, 2, "pet")
fire("PARTY_KILL", "Player-9-X", "Player-1-B"); eq(E[1].kills, 2, "party member")
fire("PARTY_KILL", "Player-1-ME", "Player-2-B"); eq(E[1].kills, 2, "other Bob")
fire("PARTY_KILL", SECRET, SECRET); fire("PARTY_KILL", "Player-1-ME", "Creature-0-1")
fire("PARTY_KILL", "Player-1-ME", "Player-2-F"); eq(E[2].kills, 1)
eq(select(2, markOf("nameplate1")), "2:0", "plate score")
DN.Add("Élan"); DN.Add("élan"); DN.Add("Жук"); DN.Add("жук"); eq(#E, 4, "utf8 case")
DeathNotebook_Toggle(); eq(DeathNotebookBook.shown, true)
for i = 1, 30 do DN.Add("Enemy" .. string.char(96 + (i % 26) + 1) .. string.rep("q", i)) end
eq(#E, 34); eq(DeathNotebookBook.page.txt, "3 / 3", "jump to new page")
DeathNotebookBook.scripts.OnMouseWheel(DeathNotebookBook, 1); eq(DeathNotebookBook.page.txt, "2 / 3")
DeathNotebookBook.scripts.OnMouseWheel(DeathNotebookBook, 1)
local row; for _, f in ipairs(frames) do if f.entry == E[1] then row = f end end
row.remove.scripts.OnClick(); eq(#E, 34, "asks first"); row.remove.scripts.OnClick(); eq(#E, 33, "removed")
eq(markOf("nameplate1"), false, "unmarked after removal")
local label, click; local root = { CreateDivider = function() end, CreateTitle = function() end, CreateButton = function(_, l, c) label, click = l, c end }
menuFn(nil, root, { unit = "target" }); eq(label, "Write into the book"); click(); eq(#E, 34)
menuFn(nil, root, { unit = "target" }); eq(label, "Strike from the book"); click(); eq(#E, 33)
SlashCmdList.DEATHNOTEBOOK("add zed some"); eq(DN.FullName(E[34]), "Zed Some"); SlashCmdList.DEATHNOTEBOOK("remove zed"); eq(#E, 33)
fire("NAME_PLATE_UNIT_REMOVED", "nameplate2"); eq(markOf("nameplate2"), false)
DeathNotebook_Toggle(); DN.Entries()[1].check = true
eq(DeathNotebookDB.entries[1].check, true, "saved")
local b = DeathNotebookMinimapButton
b.scripts.OnDragStart(b); b.scripts.OnUpdate(b); b.scripts.OnDragStop(b)
eq(math.floor(DeathNotebookDB.minimapAngle + .5), 90, "dragged to top"); eq(b.scripts.OnUpdate, nil)
b.scripts.OnClick(b, "LeftButton"); eq(DeathNotebookBook.shown, true)
local before = #E; b.scripts.OnEnter(b); b.scripts.OnClick(b, "RightButton"); eq(#E, before + 1, "right-click adds target")

-- v1.2
local function alertText() return DeathNotebookAlert and DeathNotebookAlert.shown and DeathNotebookAlert.title.txt or nil end
local alerts, showAlert = 0, DN.ShowAlert
DN.ShowAlert = function(...) alerts = alerts + 1; return showAlert(...) end
DN.Remove(E[#E]); while #E > 0 do DN.Remove(E[1]) end; wipe(DN.Recent())
DN.Add("Bob", "Smith"); local bob = E[1]
now = 5000; fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(alerts, 1, "warns"); eq(alertText(), "Bob Smith is near!")
eq(bob.zone, "Duskwood"); eq(bob.map, 47); eq(bob.class, "ROGUE"); eq(bob.guild, "Bad Guild")
now = 5059; fire("PLAYER_TARGET_CHANGED"); eq(alerts, 1, "cooldown")
now = 5100; fire("NAME_PLATE_UNIT_REMOVED", "nameplate1"); now = 5150; fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(alerts, 1, "cooldown starts when out of sight")
now = 5300; fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); eq(alerts, 2, "warns again")
DN.Add("Foe", "Where"); now = 5302; fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
eq(alertText(), "2 enemies from the book are near!")
now = 5308; runTimers(); eq(alertText(), nil, "hides")
where = "pvp"; now = 6000; fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); eq(alerts, 3, "silent in battlegrounds"); where = "none"
DeathNotebook_ToggleAlerts(); now = 7000; fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); eq(alerts, 3, "muted"); DeathNotebook_ToggleAlerts()
fire("NAME_PLATE_UNIT_ADDED", "nameplate3"); fire("NAME_PLATE_UNIT_ADDED", SECRET); eq(alerts, 3, "secrets ignored")

friend.nameplate1 = true; DN.RefreshNameplates(); eq(markOf("nameplate1"), false, "friendly unmarked")
now = 8000; fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); eq(alerts, 3, "no warning for friends")
DN.SetOption("enemiesOnly", false); eq(markOf("nameplate1"), true, "option"); DN.SetOption("enemiesOnly", true); friend.nameplate1 = nil
friend.target = true; DN.Remove(bob); DeathNotebook_AddTarget(); eq(#E, 1, "friendly target refused"); friend.target = nil
DN.SetOption("plates", false); eq(markOf("nameplate2"), false); DN.SetOption("plates", true); eq(markOf("nameplate2"), true)

-- deaths
infos["Player-1-K"] = { "Kil", "Ler" }; infos["Player-1-H"] = { "Hel", "Per" }; infos["Player-1-A"] = { "Al", "Ly" }
local race = { ["Player-1-A"] = "Human" }
GetPlayerInfoByGUID = function(g) local i = infos[g]; if i then return "Rogue", "ROGUE", "x", race[g] or "Orc", 2, i[1], i[2] end end
local function die(...) recap = { ... }; fire("PLAYER_DEAD"); for _ = 1, 6 do runTimers() end end
local t0 = os.time()
die({ sourceGUID = "Player-1-K", timestamp = t0 }, { sourceGUID = "Player-1-H", timestamp = t0 - 1 }, { sourceGUID = "Player-1-A", timestamp = t0 - 2 }, { sourceGUID = SECRET })
local R = DN.Recent(); eq(#R, 2, "allies left out"); eq(R[1].deaths, 1, "killer"); eq(R[2].deaths, 0, "helper")
die({ sourceGUID = "Player-1-K", timestamp = t0 }); eq(R[1].deaths, 1, "stale recap")
die({ sourceGUID = "Player-1-K", timestamp = t0 - 500 }); eq(R[1].deaths, 1, "old recap")
die({ sourceGUID = "Creature-1", timestamp = t0 + 1 }, { sourceGUID = "Player-1-K", timestamp = t0 }); eq(R[1].deaths, 1, "creature's blow")
die({ sourceGUID = "Pet-1", timestamp = t0 + 2 }, { sourceGUID = "Player-1-K", timestamp = t0 }); eq(R[1].deaths, 2, "pet's blow")
die({ sourceGUID = SECRET, timestamp = SECRET }); eq(R[1].deaths, 2, "secret recap")
recap = nil; fire("PLAYER_DEAD"); for _ = 1, 9 do runTimers() end; eq(#timers, 0, "stops trying")
DN.Add("Kil Ler"); local k = DN.Find("Kil", "Ler"); eq(k.deaths, 2, "taken from Recent"); eq(#R, 1)
die({ sourceGUID = "Player-1-K", timestamp = t0 + 3 }); eq(k.deaths, 3, "written killer"); eq(#R, 1)
fire("PARTY_KILL", "Player-1-ME", "Player-1-K"); eq(k.kills, 1)
DN.SetOption("autoAdd", true); die({ sourceGUID = "Player-2-B", timestamp = t0 + 4 }); eq(DN.Find("Bob", "Other").deaths, 1, "auto"); DN.SetOption("autoAdd", false)

-- fights
now = 9000; attacking.nameplate1 = true; fire("UNIT_COMBAT", "player", "HEAL"); eq(#R, 1)
fire("UNIT_COMBAT", "player", "WOUND"); eq(#R, 2, "attacker"); eq(R[2].deaths, 0); eq(R[2].class, "ROGUE")
now = 9010; fire("UNIT_COMBAT", "player", "WOUND"); eq(#R, 2, "once")
now = 9020; attacking.nameplate1 = SECRET; fire("UNIT_COMBAT", "player", "WOUND"); eq(#R, 2); attacking = {}
for i = 1, 50 do DN.RecordEnemy("Rnd" .. string.rep("q", i), "Z", nil, nil, false) end; eq(#R, 32, "Recent is capped")

-- book
if not DeathNotebookBook.shown then DeathNotebook_Toggle() end
local function button(text) for i = #frames, 1, -1 do local f = frames[i]; if f.text and f.text.txt == text and f.shown then return f end end end
local function rowOf(e) for _, f in ipairs(frames) do if f.entry == e then return f end end end
button("Recent").scripts.OnClick(); eq(DeathNotebookBook.page.txt, "1 / 2")
local first = rowOf(R[1]) or rowOf(R[2]); local before2, count = #E, #R
first.add.scripts.OnClick(); eq(#E, before2 + 1, "write from Recent"); eq(#R, count - 1)
rowOf(R[1]).remove.scripts.OnClick(); eq(#R, count - 2, "dismiss")
button("Names").scripts.OnClick()
DeathNotebookBook.search:SetText("KIL"); DeathNotebookBook.search.scripts.OnTextChanged()
eq(rowOf(k) ~= nil, true); eq(rowOf(DN.Find("Bob", "Other")), nil, "search")
DeathNotebookBook.search:SetText(""); DeathNotebookBook.search.scripts.OnTextChanged()
DN.SetOption("sort", "deaths"); local top; for _, f in ipairs(frames) do if f.entry == k then top = f end end
eq(top.score.txt, "1 : 3")
for _, s in ipairs({ "written", "name", "kills", "deaths", "last seen", "written" }) do DN.SetOption("sort", s) end
rowOf(k).scripts.OnEnter(); rowOf(k).scripts.OnClick()
eq(DeathNotebookBook.detailName.txt, "Kil Ler")
DeathNotebookBook.note:SetText("ganks"); DeathNotebookBook.note.scripts.OnTextChanged(DeathNotebookBook.note, true); eq(k.note, "ganks")
button("Set waypoint").scripts.OnClick(); eq(pin[1], 47)
canPin, pin = false, nil; DN.Waypoint(k); eq(pin, nil); canPin = true
local strike = button("Strike out"); strike.scripts.OnClick(); eq(DN.Find("Kil", "Ler"), k, "asks"); strike.scripts.OnClick(); eq(DN.Find("Kil", "Ler"), nil)
eq(DeathNotebookBook.page.shown, true, "back to the list")
button("Settings").scripts.OnClick(); eq(DeathNotebookBook.page.shown, false)
button("[x]  Mark nameplates").scripts.OnClick(); eq(DN.Option("plates"), false)
button("Warn again after: 60 seconds").scripts.OnClick(); eq(DN.Option("cooldown"), 120)
button("Test the warning").scripts.OnClick()

-- tooltip
local lines = {}; GameTooltip.GetUnit = function() return "Foe", "nameplate2" end
GameTooltip.AddLine = function(_, s) lines[#lines + 1] = s end
tooltipFn(GameTooltip); eq(lines[1], "In the book  You 0 : 0 them")
GameTooltip.GetUnit = function() return SECRET, SECRET end; tooltipFn(GameTooltip); eq(#lines, 1)
for _, c in ipairs({ "help", "way foe", "way nobody", "mute", "mute" }) do SlashCmdList.DEATHNOTEBOOK(c) end
eq(SLASH_DEATHNOTEBOOK1, "/dnb"); eq(SLASH_DEATHNOTEBOOK3, "/dn")
SLASH_OTHER1, SLASH_DEATHNOTEBOOK3 = "/dn", nil; DN.RegisterSlash(); eq(SLASH_DEATHNOTEBOOK3, nil, "/dn left to others")

-- every German text fits its English one
GetLocale = function() return "deDE" end
local de = {}; assert(loadfile("DeathNotebook/Locale.lua"))("x", de)
local function spec(s) local t = {}; for x in s:gmatch("%%[sd]") do t[#t + 1] = x end return table.concat(t) end
for k2, v in pairs(de.L) do eq(spec(v), spec(k2), k2) end
for _, f in ipairs({ "Core", "Alert", "Book", "Minimap" }) do
	for key in io.open("DeathNotebook/" .. f .. ".lua"):read("*a"):gmatch('L%["(.-[^\\])"%]') do
		key = key:gsub("\\n", "\n"):gsub('\\"', '"')
		eq(rawget(de.L, key) ~= nil, true, "German for " .. key)
	end
end
print_(n .. " checks passed")

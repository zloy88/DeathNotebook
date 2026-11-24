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

local DW = {}
for _, f in ipairs({ "Core", "Nameplates", "Book", "Minimap" }) do assert(loadfile("DeathWish/" .. f .. ".lua"))("DeathWish", DW) end
fire("PLAYER_LOGIN")
local E = DW.Entries()
for i = 1, 3 do fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
eq(markOf("nameplate1"), nil, "unmarked")
DeathWish_AddTarget(); eq(#E, 1); eq(DW.FullName(E[1]), "Bob Smith"); eq(markOf("nameplate1"), true, "marked")
DW.Add("bob"); DW.Add("bob-smith"); DW.Add("Bob Smith"); eq(#E, 1, "dup")
DW.Add("foe"); eq(E[2].name, "Foe"); eq(markOf("nameplate2"), true, "cross-realm wildcard")
eq(markOf("nameplate3"), nil, "secret ignored")
for _, bad in ipairs({ "", "  ", "a b c", "x1" }) do DW.Add(bad) end; eq(#E, 2, "invalid")
fire("PARTY_KILL", "Player-1-ME", "Player-1-B"); eq(E[1].kills, 1)
fire("PARTY_KILL", "Pet-1", "Player-1-B"); eq(E[1].kills, 2, "pet")
fire("PARTY_KILL", "Player-9-X", "Player-1-B"); eq(E[1].kills, 2, "party member")
fire("PARTY_KILL", "Player-1-ME", "Player-2-B"); eq(E[1].kills, 2, "other Bob")
fire("PARTY_KILL", SECRET, SECRET); fire("PARTY_KILL", "Player-1-ME", "Creature-0-1")
fire("PARTY_KILL", "Player-1-ME", "Player-2-F"); eq(E[2].kills, 1)
eq(select(2, markOf("nameplate1")), "x2", "plate counter")
DW.Add("Élan"); DW.Add("élan"); DW.Add("Жук"); DW.Add("жук"); eq(#E, 4, "utf8 case")
DeathWish_Toggle(); eq(DeathWishBook.shown, true)
for i = 1, 30 do DW.Add("Enemy" .. string.char(96 + (i % 26) + 1) .. string.rep("q", i)) end
eq(#E, 34); eq(DeathWishBook.page.txt, "2 / 2", "jump to new page")
DeathWishBook.scripts.OnMouseWheel(DeathWishBook, 1); eq(DeathWishBook.page.txt, "1 / 2")
local row; for _, f in ipairs(frames) do if f.entry == E[1] then row = f end end
row.remove.scripts.OnClick(); eq(#E, 34, "asks first"); row.remove.scripts.OnClick(); eq(#E, 33, "removed")
eq(markOf("nameplate1"), false, "unmarked after removal")
local label, click; local root = { CreateDivider = function() end, CreateTitle = function() end, CreateButton = function(_, l, c) label, click = l, c end }
menuFn(nil, root, { unit = "target" }); eq(label, "Write into the book"); click(); eq(#E, 34)
menuFn(nil, root, { unit = "target" }); eq(label, "Strike from the book"); click(); eq(#E, 33)
SlashCmdList.DEATHWISH("add zed some"); eq(DW.FullName(E[34]), "Zed Some"); SlashCmdList.DEATHWISH("remove zed"); eq(#E, 33)
fire("NAME_PLATE_UNIT_REMOVED", "nameplate2"); eq(markOf("nameplate2"), false)
DeathWish_Toggle(); DW.Entries()[1].check = true
eq(DeathWishDB.entries[1].check, true, "saved")
local b = DeathWishMinimapButton
b.scripts.OnDragStart(b); b.scripts.OnUpdate(b); b.scripts.OnDragStop(b)
eq(math.floor(DeathWishDB.minimapAngle + .5), 90, "dragged to top"); eq(b.scripts.OnUpdate, nil)
b.scripts.OnClick(b, "LeftButton"); eq(DeathWishBook.shown, true)
local before = #E; b.scripts.OnEnter(b); b.scripts.OnClick(b, "RightButton"); eq(#E, before + 1, "right-click adds target")
print_(n .. " checks passed")

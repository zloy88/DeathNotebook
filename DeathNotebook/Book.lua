local _, DN = ...
local L = DN.L

local ROWS = 8              -- per page side
local PER_SPREAD = ROWS * 2
local INK, RED, FADED = { 0.86, 0.83, 0.76 }, { 0.86, 0.16, 0.14 }, { 0.55, 0.53, 0.50 }
local PAGE_X = { 62, 448 }  -- left edge of the writing area on each page
local PAGE_W = 330
local SORTS = { "written", "name", "kills", "deaths", "last seen" }
local COOLDOWNS = { 30, 60, 120, 300 }

local book
local view, spread, query = "names", 1, ""
local detail -- entry shown in the detail view
local rows, tabs, settings = {}, {}, {}
local parts = { names = {}, recent = {}, detail = {}, settings = {} } -- view -> widgets

local function Text(parent, font, color, justify)
	local t = parent:CreateFontString(nil, "OVERLAY", font)
	t:SetTextColor(unpack(color))
	t:SetShadowOffset(0, 0)
	t:SetJustifyH(justify or "LEFT")
	return t
end

-- Plain text written on the page that turns red under the cursor.
local function InkButton(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b.color = INK
	b.text = Text(b, "QuestFont", INK, "CENTER")
	b.text:SetPoint("CENTER")
	function b:SetLabel(s)
		self.text:SetText(s)
		self:SetSize(math.max(self.text:GetStringWidth() + 10, 18), 22)
	end
	function b:SetInk(color)
		self.color = color
		self.text:SetTextColor(unpack(color))
	end
	b:SetLabel(label)
	b:SetScript("OnEnter", function() b.text:SetTextColor(unpack(RED)) end)
	b:SetScript("OnLeave", function() b.text:SetTextColor(unpack(b.color)) end)
	b:SetScript("OnClick", onClick)
	return b
end

local function Line(parent)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(0.8, 0.78, 0.72, 0.6)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
end

-- One-line input with a hint while it is empty.
local function Input(width, hintText, onChange)
	local input = CreateFrame("EditBox", nil, book)
	input:SetSize(width, 24)
	input:SetAutoFocus(false)
	input:SetMaxLetters(48)
	input:SetFontObject("QuestTitleFont")
	input:SetTextColor(unpack(INK))
	input:SetShadowOffset(0, 0)
	Line(input)
	local hint = Text(input, "QuestFont", FADED)
	hint:SetPoint("LEFT", 2, 0)
	hint:SetText(hintText)
	local function Hint() hint:SetShown(input:GetText() == "" and not input:HasFocus()) end
	input:SetScript("OnEscapePressed", function() input:ClearFocus() end)
	input:SetScript("OnEditFocusGained", Hint)
	input:SetScript("OnEditFocusLost", Hint)
	input:SetScript("OnTextChanged", function()
		Hint()
		if onChange then onChange(input:GetText()) end
	end)
	return input
end

local function Matches(e)
	if query == "" then return true end
	for _, s in ipairs({ DN.FullName(e), e.note or "", e.guild or "", e.zone or "" }) do
		if DN.Lower(s):find(query, 1, true) then return true end
	end
	return false
end

local COMPARE = {
	name = function(a, b) return DN.Lower(DN.FullName(a)) < DN.Lower(DN.FullName(b)) end,
	kills = function(a, b) return a.kills > b.kills end,
	deaths = function(a, b) return a.deaths > b.deaths end,
	["last seen"] = function(a, b) return (a.seen or 0) > (b.seen or 0) end,
}

-- What the pages of the current view list, searched and sorted.
local function List()
	local list, place = {}, {}
	for i, e in ipairs(view == "recent" and DN.Recent() or DN.Entries()) do
		if Matches(e) then
			list[#list + 1] = e
			place[e] = i
		end
	end
	local compare = view == "recent" and COMPARE["last seen"] or COMPARE[DN.Option("sort")]
	if compare then
		table.sort(list, function(a, b)
			if compare(a, b) then return true end
			if compare(b, a) then return false end
			return place[a] < place[b]
		end)
	end
	return list
end

local function SpreadCount(list)
	return math.max(1, math.ceil(#list / PER_SPREAD))
end

local function Turn(delta)
	if view ~= "names" and view ~= "recent" then return end
	local n = math.min(math.max(spread + delta, 1), SpreadCount(List()))
	if n == spread then return end
	spread = n
	PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
	DN.RefreshBook()
end

local function Open(newView, entry)
	if book.note then book.note:ClearFocus() end
	GameTooltip:Hide()
	if not entry and newView ~= view and view ~= "detail" then spread = 1 end
	view, detail = newView, entry
	DN.RefreshBook()
end

local function ResetRemove(row)
	row.armed = false
	row.remove:SetLabel("x")
	row.remove:SetShown(row:IsMouseOver())
	row.add:SetShown(view == "recent")
end

local function When(t) return date("%d.%m.%Y %H:%M", t) end

local function Place(e)
	if not e.zone then return "" end
	return ", " .. e.zone .. (e.x and (" %.0f, %.0f"):format(e.x * 100, e.y * 100) or "")
end

local function CreateRow(i)
	local side = i <= ROWS and 1 or 2
	local line = (i - 1) % ROWS
	local row = CreateFrame("Button", nil, book)
	row:SetSize(PAGE_W, 26)
	row:SetPoint("TOPLEFT", PAGE_X[side], -112 - line * 27)

	local rule = row:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(0.8, 0.78, 0.72, 0.14)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)

	row.name = Text(row, "QuestTitleFont", INK)
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetWidth(170)
	row.name:SetWordWrap(false)

	row.score = Text(row, "QuestFont", RED, "RIGHT")
	row.score:SetPoint("RIGHT", -62, 0)

	row.skull = row:CreateTexture(nil, "ARTWORK")
	row.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
	row.skull:SetSize(15, 15)
	row.skull:SetPoint("RIGHT", row.score, "LEFT", -4, 0)

	-- First click asks, second click removes: the score goes with it.
	row.remove = InkButton(row, "x", function()
		if view == "recent" then
			DN.RemoveRecent(row.entry)
		elseif row.armed then
			DN.Remove(row.entry)
		else
			row.armed = true
			row.remove:SetLabel(L["Sure?"])
		end
	end)
	row.remove:SetPoint("RIGHT", -2, 0)
	row.remove:Hide()
	row.add = InkButton(row, "+", function()
		local r = row.entry
		DN.Add(r.name, r.surname, r.guid)
	end)
	row.add:SetPoint("RIGHT", -24, 0)
	row.add:Hide()

	local function Leave()
		if not row:IsMouseOver() then
			ResetRemove(row)
			GameTooltip:Hide()
		end
	end
	row:SetScript("OnEnter", function()
		local e = row.entry
		if not e then return end
		row.remove:Show()
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:SetText(DN.FullName(e))
		if view == "names" then
			if not e.surname then
				GameTooltip:AddLine(L["No surname: matches anyone with that first name"], 1, 0.8, 0.4)
			end
			if e.note and e.note ~= "" then GameTooltip:AddLine(e.note, 1, 1, 1, true) end
		end
		if e.seen then GameTooltip:AddLine(L["Last seen: %s"]:format(When(e.seen) .. Place(e)), 0.7, 0.7, 0.7) end
		GameTooltip:AddLine(view == "names" and L["Click for details"] or "+  " .. L["Write into the book"], 0.5, 0.8, 0.5)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", Leave)
	row:SetScript("OnClick", function()
		if view == "names" and row.entry then Open("detail", row.entry) end
	end)
	row.remove:HookScript("OnLeave", Leave)
	row.add:HookScript("OnLeave", Leave)
	return row
end

local function CreateDetail()
	local add = function(w) table.insert(parts.detail, w) return w end
	local back = add(InkButton(book, L["< Back"], function() Open("names") end))
	back:SetPoint("TOPLEFT", PAGE_X[1], -345)
	local way = add(InkButton(book, L["Set waypoint"], function() DN.Waypoint(detail) end))
	way:SetPoint("TOP", book, "TOPLEFT", PAGE_X[1] + PAGE_W / 2, -345)
	book.way = way
	local strike
	strike = add(InkButton(book, L["Strike out"], function()
		if strike.armed then return DN.Remove(detail) end
		strike.armed = true
		strike:SetLabel(L["Sure?"])
	end))
	strike:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[1] + PAGE_W, -345)
	book.strike = strike

	book.detailName = add(Text(book, "QuestTitleFont", RED))
	book.detailName:SetPoint("TOPLEFT", PAGE_X[1] + 4, -90)
	book.detailName:SetWidth(PAGE_W - 10)
	book.detailText = add(Text(book, "QuestFont", INK))
	book.detailText:SetPoint("TOPLEFT", PAGE_X[1] + 4, -120)
	book.detailText:SetWidth(PAGE_W - 10)
	book.detailText:SetSpacing(6)

	local title = add(Text(book, "QuestTitleFont", INK))
	title:SetPoint("TOPLEFT", PAGE_X[2] + 4, -90)
	title:SetText(L["Note"])
	local area = add(CreateFrame("Button", nil, book))
	area:SetPoint("TOPLEFT", PAGE_X[2], -116)
	area:SetSize(PAGE_W, 215)
	local note = add(CreateFrame("EditBox", nil, book))
	book.note = note
	note:SetMultiLine(true)
	note:SetAutoFocus(false)
	note:SetMaxLetters(300)
	note:SetFontObject("QuestFont")
	note:SetTextColor(unpack(INK))
	note:SetShadowOffset(0, 0)
	note:SetPoint("TOPLEFT", PAGE_X[2] + 4, -120)
	note:SetWidth(PAGE_W - 10)
	note:SetFrameLevel(area:GetFrameLevel() and area:GetFrameLevel() + 1 or 5)
	local hint = Text(note, "QuestFont", FADED)
	hint:SetPoint("TOPLEFT")
	hint:SetText(L["Write a reason or a note here."])
	book.noteHint = hint
	area:SetScript("OnClick", function() note:SetFocus() end)
	note:SetScript("OnEscapePressed", function() note:ClearFocus() end)
	note:SetScript("OnTextChanged", function(_, byUser)
		hint:SetShown(note:GetText() == "")
		if byUser and detail then detail.note = note:GetText() end
	end)
end

local function CreateSettings()
	local list = {
		{ "alert", "Warn me when a written enemy is near" }, { "sound", "Play a sound with the warning" },
		{ "plates", "Mark nameplates" }, { "tooltip", "Show the book in tooltips" },
		{ "enemiesOnly", "Only enemy players" }, { "recent", "Remember recent enemies" },
		{ "autoAdd", "Write my killers down at once" },
	}
	for i, s in ipairs(list) do
		local b = InkButton(book, "", function() DN.SetOption(s[1], not DN.Option(s[1])) end)
		b:SetPoint("TOPLEFT", PAGE_X[1], -84 - i * 30)
		b.key, b.label = s[1], L[s[2]]
		settings[i] = b
		table.insert(parts.settings, b)
	end
	book.cooldown = InkButton(book, "", function()
		local nextValue = COOLDOWNS[1]
		for i, v in ipairs(COOLDOWNS) do
			if v == DN.Option("cooldown") then nextValue = COOLDOWNS[i + 1] or COOLDOWNS[1] end
		end
		DN.SetOption("cooldown", nextValue)
	end)
	book.cooldown:SetPoint("TOPLEFT", PAGE_X[2], -114)
	table.insert(parts.settings, book.cooldown)
	local test = InkButton(book, L["Test the warning"], function()
		DN.ShowAlert({ name = "Grimtooth", surname = "Vale", kills = 2, deaths = 1, note = "Test" })
	end)
	test:SetPoint("TOPLEFT", PAGE_X[2], -144)
	table.insert(parts.settings, test)
end

local function CreateBook()
	book = CreateFrame("Frame", "DeathNotebookBook", UIParent)
	book:Hide()
	book:SetSize(840, 420)
	book:SetPoint("CENTER")
	book:SetFrameStrata("HIGH")
	book:SetToplevel(true)
	book:SetClampedToScreen(true)
	book:SetMovable(true)
	book:EnableMouse(true)
	book:RegisterForDrag("LeftButton")
	book:SetScript("OnDragStart", book.StartMoving)
	book:SetScript("OnDragStop", book.StopMovingOrSizing)
	book:EnableMouseWheel(true)
	book:SetScript("OnMouseWheel", function(_, d) Turn(-d) end)
	book:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
		DN.RefreshBook()
	end)
	book:SetScript("OnHide", function()
		GameTooltip:Hide()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
	end)
	tinsert(UISpecialFrames, "DeathNotebookBook") -- Escape closes

	local art = book:CreateTexture(nil, "BACKGROUND")
	art:SetAllPoints()
	art:SetTexture("Interface\\AddOns\\DeathNotebook\\Media\\Book.tga")

	local title = Text(book, "QuestTitleFont", INK)
	title:SetPoint("TOPLEFT", PAGE_X[1] + 4, -48)
	title:SetText("Death Notebook")
	book.total = Text(book, "QuestFont", FADED, "RIGHT")
	book.total:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[1] + PAGE_W, -50)

	local left
	for _, t in ipairs({ { "names", "Names" }, { "recent", "Recent" }, { "settings", "Settings" } }) do
		local b = InkButton(book, L[t[2]], function() Open(t[1]) end)
		if left then b:SetPoint("LEFT", left, "RIGHT", 12, 0) else b:SetPoint("TOPLEFT", PAGE_X[2], -44) end
		b.view, left = t[1], b
		tabs[#tabs + 1] = b
	end
	local close = InkButton(book, "X", function() book:Hide() end)
	close:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[2] + PAGE_W, -44)

	book.search = Input(180, L["Search..."], function(s)
		s = DN.Lower(strtrim(s))
		if s == query then return end
		query, spread = s, 1
		DN.RefreshBook()
	end)
	book.search:SetPoint("TOPLEFT", PAGE_X[1] + 4, -80)
	book.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	book.sort = InkButton(book, "", function()
		local nextSort = SORTS[1]
		for i, v in ipairs(SORTS) do
			if v == DN.Option("sort") then nextSort = SORTS[i + 1] or SORTS[1] end
		end
		spread = 1
		DN.SetOption("sort", nextSort)
	end)
	book.sort:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[2] + PAGE_W, -82)

	for i = 1, PER_SPREAD do rows[i] = CreateRow(i) end

	book.empty = Text(book, "QuestFont", FADED)
	book.empty:SetPoint("TOPLEFT", PAGE_X[1] + 4, -120)
	book.empty:SetWidth(PAGE_W - 20)

	book.prev = InkButton(book, L["< Previous"], function() Turn(-1) end)
	book.prev:SetPoint("TOPLEFT", PAGE_X[1], -345)
	book.page = Text(book, "QuestFont", FADED, "CENTER")
	book.page:SetPoint("TOP", book, "TOPLEFT", PAGE_X[1] + PAGE_W / 2, -350)
	book.next = InkButton(book, L["Next >"], function() Turn(1) end)
	book.next:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[1] + PAGE_W, -345)

	local input = Input(145, L["Write a name..."])
	book.input = input
	input:SetPoint("TOPLEFT", PAGE_X[2] + 4, -344)
	local function Submit()
		if strtrim(input:GetText()) == "" then return input:SetFocus() end
		DN.Add(input:GetText())
		input:SetText("")
	end
	input:SetScript("OnEnterPressed", Submit)
	local add = InkButton(book, L["Write"], Submit)
	add:SetPoint("LEFT", input, "RIGHT", 6, 0)
	local target = InkButton(book, L["Add target"], DeathNotebook_AddTarget)
	target:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[2] + PAGE_W, -345)

	parts.names = { book.search, book.page, book.sort, input, add, target }
	parts.recent = { book.search, book.page }
	CreateDetail()
	CreateSettings()
end

-- Turns to the page with this entry.
function DN.ShowEntry(entry)
	if view ~= "names" and view ~= "recent" then return end
	if view == "recent" then return end -- stay there while writing names down
	if query ~= "" then
		query = ""
		if book then book.search:SetText("") end
	end
	for i, e in ipairs(List()) do
		if e == entry then spread = math.ceil(i / PER_SPREAD) end
	end
end

local function RefreshList()
	local list = List()
	local pages = SpreadCount(list)
	spread = math.min(spread, pages)
	book.page:SetText(("%d / %d"):format(spread, pages))
	book.prev:SetShown(spread > 1)
	book.next:SetShown(spread < pages)
	book.sort:SetLabel(L["Sort: %s"]:format(L[DN.Option("sort")]))

	book.empty:SetShown(#list == 0)
	if query ~= "" then
		book.empty:SetText(L["No name matches your search."])
	elseif view == "recent" then
		book.empty:SetText(L["Nobody here. Enemies who kill or fight you will appear on these pages."])
	else
		book.empty:SetText(L["The pages are still blank...\n\nWrite a name on the right page, or target an enemy and choose \"Add target\"."])
	end

	for i, row in ipairs(rows) do
		local e = list[(spread - 1) * PER_SPREAD + i]
		row.entry = e
		row:SetShown(e ~= nil)
		if e then
			local c = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
			row.name:SetText(DN.FullName(e))
			if c then row.name:SetTextColor(c.r, c.g, c.b) else row.name:SetTextColor(unpack(INK)) end
			if view == "recent" then
				row.score:SetText(e.deaths > 0 and L["killed you (%d)"]:format(e.deaths) or L["fought you"])
				row.skull:SetShown(false)
			else
				row.score:SetText(e.kills .. " : " .. e.deaths)
				row.skull:SetShown(true)
				row.skull:SetAlpha(e.kills > 0 and 1 or 0.3)
			end
			ResetRemove(row)
		end
	end
end

local function RefreshDetail()
	local e = detail
	book.detailName:SetText(DN.FullName(e))
	local class = e.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class)
	local level = e.level and L["Level %s"]:format(e.level > 0 and e.level or "??")
	local t = {}
	local function Put(s) if s and s ~= "" then t[#t + 1] = s end end
	Put((level or "") .. (level and class and ", " or "") .. (class or ""))
	Put(e.guild and L["Guild: %s"]:format(e.guild))
	Put(L["You %d : %d them"]:format(e.kills, e.deaths))
	Put(not e.surname and L["No surname: matches anyone with that first name"])
	Put(L["Written: %s"]:format(When(e.added)))
	Put(e.seen and L["Last seen: %s"]:format(When(e.seen) .. Place(e)))
	Put(e.lastKill and L["Last slain: %s"]:format(When(e.lastKill)))
	Put(e.lastDeath and L["Last killed you: %s"]:format(When(e.lastDeath)))
	book.detailText:SetText(table.concat(t, "\n"))
	book.way:SetShown(e.map ~= nil)
	book.strike.armed = false
	book.strike:SetLabel(L["Strike out"])
	if not book.note:HasFocus() then book.note:SetText(e.note or "") end
	book.noteHint:SetShown((e.note or "") == "")
end

function DN.RefreshBook()
	if not book or not book:IsShown() then return end
	local entries = DN.Entries()
	if view == "detail" then
		local found = false
		for _, e in ipairs(entries) do found = found or e == detail end
		if not found then
			book.note:ClearFocus()
			view, detail = "names", nil
		end
	end

	local total = 0
	for _, e in ipairs(entries) do total = total + e.kills end
	book.total:SetText(#entries == 1 and L["1 name, %d slain"]:format(total)
		or L["%d names, %d slain"]:format(#entries, total))
	for _, b in ipairs(tabs) do
		b:SetInk((b.view == view or (view == "detail" and b.view == "names")) and RED or INK)
	end

	-- Only hide what goes away: hiding an input would take its keyboard focus.
	local keep = {}
	for _, w in ipairs(parts[view]) do keep[w] = true end
	for _, list in pairs(parts) do
		for _, w in ipairs(list) do
			if not keep[w] then w:Hide() end
		end
	end
	for w in pairs(keep) do w:Show() end
	if view == "detail" or view == "settings" then
		book.prev:Hide()
		book.next:Hide()
		book.empty:Hide()
		for _, row in ipairs(rows) do row:Hide() end
	end

	if view == "detail" then
		RefreshDetail()
	elseif view == "settings" then
		for _, b in ipairs(settings) do
			b:SetLabel((DN.Option(b.key) and "[x]  " or "[  ]  ") .. b.label)
		end
		book.cooldown:SetLabel(L["Warn again after: %d seconds"]:format(DN.Option("cooldown")))
	else
		RefreshList()
	end
end

function DeathNotebook_Toggle()
	if not book then CreateBook() end
	book:SetShown(not book:IsShown())
end

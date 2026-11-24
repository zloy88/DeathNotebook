local _, DW = ...

local ROWS = 9              -- per page side
local PER_SPREAD = ROWS * 2
local INK, RED, FADED = { 0.16, 0.09, 0.04 }, { 0.55, 0.05, 0.03 }, { 0.42, 0.31, 0.18 }
local PAGE_X = { 62, 448 }  -- left edge of the writing area on each page
local PAGE_W = 330

local book, spread = nil, 1
local rows = {}

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
	b.text = Text(b, "QuestFont", INK, "CENTER")
	b.text:SetPoint("CENTER")
	function b:SetLabel(s)
		self.text:SetText(s)
		self:SetSize(math.max(self.text:GetStringWidth() + 10, 18), 22)
	end
	b:SetLabel(label)
	b:SetScript("OnEnter", function() b.text:SetTextColor(unpack(RED)) end)
	b:SetScript("OnLeave", function() b.text:SetTextColor(unpack(INK)) end)
	b:SetScript("OnClick", onClick)
	return b
end

local function SpreadCount()
	return math.max(1, math.ceil(#DW.Entries() / PER_SPREAD))
end

local function Turn(delta)
	local n = math.min(math.max(spread + delta, 1), SpreadCount())
	if n == spread then return end
	spread = n
	PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
	DW.RefreshBook()
end

local function ResetRemove(row)
	row.armed = false
	row.remove:SetLabel("x")
	row.remove:SetShown(row:IsMouseOver())
end

local function CreateRow(i)
	local side = i <= ROWS and 1 or 2
	local line = (i - 1) % ROWS
	local row = CreateFrame("Frame", nil, book)
	row:SetSize(PAGE_W, 26)
	row:SetPoint("TOPLEFT", PAGE_X[side], -82 - line * 27)
	row:EnableMouse(true)

	local rule = row:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(0.35, 0.22, 0.1, 0.28)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)

	row.name = Text(row, "QuestTitleFont", INK)
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetWidth(215)
	row.name:SetWordWrap(false)

	row.kills = Text(row, "QuestTitleFont", RED, "RIGHT")
	row.kills:SetPoint("RIGHT", -62, 0)

	row.skull = row:CreateTexture(nil, "ARTWORK")
	row.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
	row.skull:SetSize(15, 15)
	row.skull:SetPoint("RIGHT", row.kills, "LEFT", -4, 0)

	-- First click asks, second click removes: the kill count goes with it.
	row.remove = InkButton(row, "x", function()
		if row.armed then
			DW.Remove(row.entry)
		else
			row.armed = true
			row.remove:SetLabel("Sure?")
		end
	end)
	row.remove:SetPoint("RIGHT", -2, 0)
	row.remove:Hide()

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
		GameTooltip:SetText(DW.FullName(e))
		if not e.surname then
			GameTooltip:AddLine("No surname: matches anyone with this first name", 1, 0.8, 0.4)
		end
		GameTooltip:AddLine("Kills: " .. e.kills, 1, 1, 1)
		GameTooltip:AddLine("Written: " .. date("%d %b %Y", e.added), 0.7, 0.7, 0.7)
		if e.lastKill then
			GameTooltip:AddLine("Last slain: " .. date("%d %b %Y, %H:%M", e.lastKill), 0.7, 0.7, 0.7)
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", Leave)
	row.remove:HookScript("OnLeave", Leave)
	return row
end

local function CreateBook()
	book = CreateFrame("Frame", "DeathWishBook", UIParent)
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
		DW.RefreshBook()
	end)
	book:SetScript("OnHide", function()
		GameTooltip:Hide()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
	end)
	tinsert(UISpecialFrames, "DeathWishBook") -- Escape closes

	local art = book:CreateTexture(nil, "BACKGROUND")
	art:SetAllPoints()
	art:SetTexture("Interface\\AddOns\\DeathWish\\Media\\Book.tga")

	local title = Text(book, "QuestTitleFont", RED)
	title:SetPoint("TOPLEFT", PAGE_X[1] + 4, -48)
	title:SetText("Death Wish")
	book.total = Text(book, "QuestFont", FADED, "RIGHT")
	book.total:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[2] + PAGE_W - 30, -50)

	local close = InkButton(book, "X", function() book:Hide() end)
	close:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[2] + PAGE_W, -44)

	for i = 1, PER_SPREAD do rows[i] = CreateRow(i) end

	book.empty = Text(book, "QuestFont", FADED)
	book.empty:SetPoint("TOPLEFT", PAGE_X[1] + 4, -90)
	book.empty:SetWidth(PAGE_W - 20)
	book.empty:SetText("The pages are still blank...\n\nWrite a name on the right page, or target an enemy and choose \"Add target\".")

	book.prev = InkButton(book, "< Previous", function() Turn(-1) end)
	book.prev:SetPoint("TOPLEFT", PAGE_X[1], -345)
	book.page = Text(book, "QuestFont", FADED, "CENTER")
	book.page:SetPoint("TOP", book, "TOPLEFT", PAGE_X[1] + PAGE_W / 2, -350)
	book.next = InkButton(book, "Next >", function() Turn(1) end)
	book.next:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[1] + PAGE_W, -345)

	local input = CreateFrame("EditBox", nil, book)
	book.input = input
	input:SetPoint("TOPLEFT", PAGE_X[2] + 4, -344)
	input:SetSize(160, 24)
	input:SetAutoFocus(false)
	input:SetMaxLetters(48)
	input:SetFontObject("QuestTitleFont")
	input:SetTextColor(unpack(INK))
	input:SetShadowOffset(0, 0)
	local line = input:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(0.25, 0.12, 0.05, 0.8)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
	local hint = Text(input, "QuestFont", FADED)
	hint:SetPoint("LEFT", 2, 0)
	hint:SetText("Write a name...")

	local function Hint() hint:SetShown(input:GetText() == "" and not input:HasFocus()) end
	local function Submit()
		if strtrim(input:GetText()) == "" then return input:SetFocus() end
		DW.Add(input:GetText())
		input:SetText("")
	end
	input:SetScript("OnEnterPressed", Submit)
	input:SetScript("OnEscapePressed", function() input:ClearFocus() end)
	input:SetScript("OnEditFocusGained", Hint)
	input:SetScript("OnEditFocusLost", Hint)
	input:SetScript("OnTextChanged", Hint)

	local add = InkButton(book, "Write", Submit)
	add:SetPoint("LEFT", input, "RIGHT", 6, 0)
	local target = InkButton(book, "Add target", DeathWish_AddTarget)
	target:SetPoint("TOPRIGHT", book, "TOPLEFT", PAGE_X[2] + PAGE_W, -345)
end

function DW.ShowLastPage()
	spread = SpreadCount()
end

function DW.RefreshBook()
	if not book or not book:IsShown() then return end
	local entries = DW.Entries()
	local pages = SpreadCount()
	spread = math.min(spread, pages)

	local total = 0
	for _, e in ipairs(entries) do total = total + e.kills end
	book.total:SetText(("%d names, %d slain"):format(#entries, total))
	book.empty:SetShown(#entries == 0)
	book.page:SetText(("%d / %d"):format(spread, pages))
	book.prev:SetShown(spread > 1)
	book.next:SetShown(spread < pages)

	for i, row in ipairs(rows) do
		local e = entries[(spread - 1) * PER_SPREAD + i]
		row.entry = e
		row:SetShown(e ~= nil)
		if e then
			row.name:SetText(DW.FullName(e))
			row.kills:SetText(e.kills)
			row.skull:SetShown(true)
			row.skull:SetAlpha(e.kills > 0 and 1 or 0.3)
			ResetRemove(row)
		end
	end
end

function DeathWish_Toggle()
	if not book then CreateBook() end
	book:SetShown(not book:IsShown())
end

--[[
  Craftwise bags: is an item in your bags or bank worth keeping?

  A small badge in the corner of each slot (bags and bank):
    green tick      still levels your profession
    blue tick       another character of yours levels with it
    gold coin       still needed, but you hold more than leveling takes
    green arrow     make it into something better first (ore -> bar)
    red cross       can go: junk, no longer levels anything, far below
                    your level, or a trade good none of your recipes use

  The same verdict is a line in the item's tooltip, and /craftwise bags
  sums it up: what can go (and what a vendor pays), what is spare, what
  to refine. The bank is counted as it was on your last visit.

  The logic is Core.lua's C.Assess (tested); this file only reads the
  game and draws.
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local B = {}
ns.Bags = B

local P = "|cff8fd16aCraftwise|r "

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(fn, ...)
	if ok then
		return a, b, c, d, e, f, g, h, i, j, k, l
	end
	return nil
end

local function DB()
	local db = C.DB()
	if db.badges == nil then
		db.badges = true
	end
	db.bank = type(db.bank) == "table" and db.bank or {}
	return db
end

-- GetItemInfo as the table C.Assess wants (nil while the item loads).
function B.Info(id)
	local name, _, quality, _, minLevel, _, _, _, equipLoc, _, sell, class = Call(GetItemInfo, id)
	if not name then
		return nil
	end
	return { name = name, quality = quality, minLevel = minLevel, equipLoc = equipLoc, sell = sell or 0, class = class }
end

local function Have(id)
	local all = Call(GetItemCount, id, true)
	return type(all) == "number" and all or 0
end

function B.AssessID(id, have)
	local info = B.Info(id)
	if not info then
		return nil
	end
	return C.Assess(id, info, { me = C.Me(), level = Call(UnitLevel, "player"), have = have or Have(id) }), info
end

local function ItemName(id)
	local info = B.Info(id)
	return info and info.name or ("item " .. id)
end

------------------------------------------------------------------------
-- Tooltip line
------------------------------------------------------------------------

-- Lines for the tooltip: list of { text }.
function B.TipLines(id)
	local a = B.AssessID(id)
	if not a then
		return {}
	end
	local out = {}
	if a.kind == "need" then
		if a.keep > 0 and a.use then
			out[#out + 1] = { "|cffaaaaaa" .. string.format(T("To level: about %d (%s)"), a.keep, a.use.recipe) .. "|r" }
		end
		if a.spare > 0 then
			out[#out + 1] = { "|cffffd100" .. string.format(T("Spare: %d, more than leveling takes"), a.spare) .. "|r" }
		end
	elseif a.kind == "refine" then
		local s = string.format(T("Make it into %s first"), ItemName(a.product))
		if a.makes > 0 then
			s = s .. " (" .. string.format(T("enough for %d"), a.makes) .. ")"
		end
		out[#out + 1] = { "|cff40c0ff" .. s .. "|r" }
	elseif a.kind == "alt" then
		out[#out + 1] = { "|cff80b0ff" .. string.format(T("%s still levels with it: keep it for them"), a.who) .. "|r" }
	elseif a.kind == "junk" then
		out[#out + 1] = { "|cff9d9d9d" .. T("Junk: sell it to a vendor") .. "|r" }
	elseif a.kind == "outdated" then
		out[#out + 1] = { "|cff9d9d9d" .. string.format(T("Far below your level (from %d): sell it"), a.minLevel) .. "|r" }
	elseif a.kind == "unused" then
		out[#out + 1] = { "|cff9d9d9d" .. T("None of your recipes use it") .. "|r" }
	end
	return out
end

------------------------------------------------------------------------
-- Badges on slots
------------------------------------------------------------------------

B.BADGE = {
	need = { "Interface\\RaidFrame\\ReadyCheck-Ready" },
	alt = { "Interface\\RaidFrame\\ReadyCheck-Ready", 0.45, 0.7, 1 },
	spare = { "Interface\\MoneyFrame\\UI-GoldIcon" },
	refine = { "Interface\\Buttons\\UI-MicroStream-Green" },
	go = { "Interface\\RaidFrame\\ReadyCheck-NotReady" },
}

-- Which badge an assessment gets (nil: none).
function B.BadgeFor(a)
	if not a then
		return nil
	end
	if a.kind == "need" then
		return a.spare > 0 and "spare" or "need"
	elseif a.kind == "alt" or a.kind == "refine" then
		return a.kind
	elseif a.kind == "junk" or a.kind == "grey" or a.kind == "outdated" or a.kind == "unused" then
		return "go"
	end
	return nil
end

local cache, cacheTime = {}, 0

local function Badge(button, bag, slot)
	local tex = button.craftwiseBadge
	local info = bag and slot and C_Container and Call(C_Container.GetContainerItemInfo, bag, slot)
	local id = type(info) == "table" and info.itemID or nil
	local kind
	if id and DB().badges then
		local have = Have(id)
		local key = id .. ":" .. have
		if cache[key] == nil then
			cache[key] = B.BadgeFor((B.AssessID(id, have))) or false
		end
		kind = cache[key] or nil
	end
	if not kind then
		if tex then
			tex:Hide()
		end
		return
	end
	if not tex then
		tex = button:CreateTexture(nil, "OVERLAY", nil, 7)
		tex:SetSize(13, 13)
		tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		button.craftwiseBadge = tex
	end
	local b = B.BADGE[kind]
	tex:SetTexture(b[1])
	tex:SetVertexColor(b[2] or 1, b[3] or 1, b[4] or 1)
	tex:Show()
end

local function ContainerFrames()
	local list = {}
	if ContainerFrameCombinedBags then
		list[#list + 1] = ContainerFrameCombinedBags
	end
	for i = 1, 13 do
		local f = _G["ContainerFrame" .. i]
		if f then
			list[#list + 1] = f
		end
	end
	return list
end

function B.Refresh()
	local now = Call(GetTime) or 0
	if now - cacheTime > 5 then
		cache, cacheTime = {}, now -- recipes and levels change: look again now and then
	end
	for _, f in ipairs(ContainerFrames()) do
		if f:IsShown() then
			if f.EnumerateValidItems then
				for _, b in f:EnumerateValidItems() do
					Badge(b, Call(b.GetBagID, b), Call(b.GetID, b))
				end
			else
				local name = f:GetName()
				for j = 1, 36 do
					local b = name and _G[name .. "Item" .. j]
					if b and b:IsShown() then
						Badge(b, f:GetID(), b:GetID())
					end
				end
			end
		end
	end
	local panel = _G.BankPanel
	if panel and panel:IsShown() and panel.itemButtonPool then
		for b in panel.itemButtonPool:EnumerateActive() do
			Badge(b, Call(b.GetBankTabID, b), Call(b.GetContainerSlotID, b))
		end
	elseif BankFrame and BankFrame:IsShown() then
		for j = 1, 28 do
			local b = _G["BankFrameItem" .. j]
			if b then
				Badge(b, -1, b:GetID())
			end
		end
	end
end

------------------------------------------------------------------------
-- What is where: bags now, bank as of the last visit
------------------------------------------------------------------------

function B.BagIDs()
	local ids = {}
	for i = 0, 4 do
		ids[#ids + 1] = i
	end
	return ids
end

function B.BankIDs()
	local ids, seen = {}, {}
	local function Add(i)
		if type(i) == "number" and not seen[i] then
			seen[i] = true
			ids[#ids + 1] = i
		end
	end
	Add(-1)
	for i = 5, 11 do
		Add(i)
	end
	if Enum and type(Enum.BagIndex) == "table" then
		for k, v in pairs(Enum.BagIndex) do
			if type(k) == "string" and k:find("Bank") and not k:find("Account") then
				Add(v)
			end
		end
	end
	return ids
end

local function Contents(ids, into)
	into = into or {}
	if not (C_Container and C_Container.GetContainerNumSlots) then
		return into
	end
	for _, bag in ipairs(ids) do
		local n = Call(C_Container.GetContainerNumSlots, bag) or 0
		for slot = 1, n do
			local info = Call(C_Container.GetContainerItemInfo, bag, slot)
			if type(info) == "table" and info.itemID then
				into[info.itemID] = (into[info.itemID] or 0) + (info.stackCount or 1)
			end
		end
	end
	return into
end

local bankOpen = false

function B.SaveBank()
	if not bankOpen then
		return
	end
	local got = Contents(B.BankIDs())
	DB().bank[C.Me()] = got
end

-- Sorted report from contents { [id] = count }.
--   assess(id, count) -> assessment, info (B.AssessID in the game)
-- Returns { go = { {id, name, count, value, kind} }, goValue,
--           spare = { {id, name, count} }, refine = { {id, name, product, makes} } }
function B.Report(contents, assess)
	local r = { go = {}, goValue = 0, spare = {}, refine = {} }
	for id, count in pairs(contents) do
		local a, info = assess(id, count)
		local name = info and info.name or ("item " .. id)
		if a then
			if a.kind == "junk" or a.kind == "grey" or a.kind == "outdated" or a.kind == "unused" then
				local value = (info and info.sell or 0) * count
				r.go[#r.go + 1] = { id = id, name = name, count = count, value = value, kind = a.kind }
				r.goValue = r.goValue + value
			elseif a.kind == "need" and a.spare > 0 then
				r.spare[#r.spare + 1] = { id = id, name = name, count = a.spare }
			elseif a.kind == "refine" then
				r.refine[#r.refine + 1] = { id = id, name = name, product = a.product, makes = a.makes }
			end
		end
	end
	table.sort(r.go, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.name < b.name
	end)
	table.sort(r.spare, function(a, b) return a.name < b.name end)
	table.sort(r.refine, function(a, b) return a.name < b.name end)
	return r
end

local WHY = {
	junk = "junk",
	grey = "no longer levels anything",
	outdated = "far below your level",
	unused = "no recipe of yours uses it",
}

function B.PrintReport()
	local all = Contents(B.BagIDs())
	if bankOpen then
		B.SaveBank()
	end
	local bank = DB().bank[C.Me()]
	for id, n in pairs(bank or {}) do
		all[id] = (all[id] or 0) + n
	end
	local r = B.Report(all, function(id, count)
		return B.AssessID(id, Have(id) > 0 and Have(id) or count)
	end)
	print(P .. (bank and T("Bags and bank (as of your last visit):") or T("Bags (open the bank once to count it too):")))
	if #r.go > 0 then
		print("|cffff6060" .. T("Can go") .. "|r  |cffaaaaaa" .. string.format(T("a vendor pays %s"), C.Money(r.goValue)) .. "|r")
		for _, x in ipairs(r.go) do
			print(string.format("  %s ×%d  |cffaaaaaa%s%s|r", x.name, x.count, T(WHY[x.kind]),
				x.value > 0 and (", " .. C.Money(x.value)) or ""))
		end
	end
	if #r.spare > 0 then
		print("|cffffd100" .. T("Spare: more than leveling takes") .. "|r")
		for _, x in ipairs(r.spare) do
			print(string.format("  %s ×%d", x.name, x.count))
		end
	end
	if #r.refine > 0 then
		print("|cff40c0ff" .. T("Make into something better first") .. "|r")
		for _, x in ipairs(r.refine) do
			print(string.format("  %s → %s%s", x.name, ItemName(x.product),
				x.makes > 0 and (" (" .. string.format(T("enough for %d"), x.makes) .. ")") or ""))
		end
	end
	if #r.go + #r.spare + #r.refine == 0 then
		print("  " .. T("Nothing to clear out."))
	end
	if not C.AnyScanned() then
		print("  |cffaaaaaa" .. T("Open each profession window once so Craftwise learns your recipes.") .. "|r")
	end
end

------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------

ns.commands = ns.commands or {}
ns.commands.bags = B.PrintReport
ns.commands.badges = function()
	local db = DB()
	db.badges = not db.badges
	print(P .. T("Badges on bag and bank slots:") .. " " .. (db.badges and T("on") or T("off")))
	cache = {}
	B.Refresh()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
	if event == "BANKFRAME_OPENED" then
		bankOpen = true
		if C_Timer and C_Timer.After then
			C_Timer.After(0.5, B.SaveBank)
		end
	elseif event == "BANKFRAME_CLOSED" then
		B.SaveBank()
		bankOpen = false
	elseif event == "BAG_UPDATE_DELAYED" then
		B.SaveBank()
	end
	cache = {}
	B.Refresh()
end)
for _, e in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "TRADE_SKILL_UPDATE" }) do
	pcall(ev.RegisterEvent, ev, e)
end
-- the bag frames refill their buttons on their own: a light look twice a
-- second while any of them is open keeps the badges in step
if C_Timer and C_Timer.NewTicker then
	C_Timer.NewTicker(0.5, function()
		B.Refresh()
	end)
end

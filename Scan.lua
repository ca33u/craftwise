--[[
  Craftwise scanner: reads your recipes when a profession window is open.

  Trade skills (Mining/Smelting, Engineering, Blacksmithing, Tailoring,
  Leatherworking, Alchemy, Cooking, First Aid...) use the TradeSkill API;
  Enchanting uses the Craft API. Both are read the same way: every recipe,
  its colour for you, what it makes and its reagents with counts.
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local S = {}
ns.Scan = S

local P = "|cff8fd16aCraftwise|r "

-- The two window APIs behind one shape (nil where the client has none).
S.API = {
	trade = {
		line = function()
			if GetTradeSkillLine then
				return GetTradeSkillLine()
			end
		end,
		num = function() return GetNumTradeSkills and GetNumTradeSkills() or 0 end,
		info = function(i) return GetTradeSkillInfo(i) end, -- name, type, available, expanded
		link = function(i) return GetTradeSkillItemLink and GetTradeSkillItemLink(i) end,
		made = function(i)
			if GetTradeSkillNumMade then
				return GetTradeSkillNumMade(i)
			end
		end,
		nreag = function(i) return GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0 end,
		reag = function(i, j) return GetTradeSkillReagentInfo(i, j) end, -- name, tex, count, have
		reaglink = function(i, j) return GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j) end,
	},
	craft = {
		line = function()
			if GetCraftDisplaySkillLine then
				return GetCraftDisplaySkillLine()
			end
		end,
		num = function() return GetNumCrafts and GetNumCrafts() or 0 end,
		info = function(i)
			local name, _, kind, available, expanded = GetCraftInfo(i)
			return name, kind, available, expanded
		end,
		link = function(i) return GetCraftItemLink and GetCraftItemLink(i) end,
		made = function() return 1, 1 end,
		nreag = function(i) return GetCraftNumReagents and GetCraftNumReagents(i) or 0 end,
		reag = function(i, j) return GetCraftReagentInfo(i, j) end,
		reaglink = function(i, j) return GetCraftReagentItemLink and GetCraftReagentItemLink(i, j) end,
	},
}

-- Reads one open window. Returns prof, rank, max, recipes or nil.
function S.Read(api)
	local okLine, prof, rank, max = pcall(api.line)
	if not okLine or type(prof) ~= "string" or prof == "" or prof == "UNKNOWN" then
		return nil
	end
	local recipes = {}
	local okNum, n = pcall(api.num)
	for i = 1, (okNum and n or 0) do
		local ok, name, kind = pcall(api.info, i)
		if ok and name and kind and kind ~= "header" and kind ~= "subheader" then
			local r = { diff = kind, reagents = {} }
			local _, link = pcall(api.link, i)
			local id = C.ItemID(link)
			-- enchants make no item; their "link" is a spell
			if id and type(link) == "string" and link:find("|Hitem:", 1, true) then
				r.product = id
				local _, lo, hi = pcall(api.made, i)
				r.made = lo or 1
				if hi and hi ~= lo then
					r.madeMax = hi
				end
			end
			local _, nr = pcall(api.nreag, i)
			for j = 1, (nr or 0) do
				local okR, _, _, count = pcall(api.reag, i, j)
				local _, rl = pcall(api.reaglink, i, j)
				local rid = C.ItemID(rl)
				if okR and rid then
					r.reagents[#r.reagents + 1] = { rid, count or 1 }
				end
			end
			recipes[name] = r
		end
	end
	return prof, rank, max, recipes
end

------------------------------------------------------------------------
-- Newer profession window (C_TradeSkillUI), used by WoW Forever's
-- ProfessionsFrame: recipe IDs, their colour and a schematic of reagents.
------------------------------------------------------------------------

S.DIFF = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then
		return a, b, c, d
	end
end

-- Profession name, rank, max for the window that is open.
function S.ModernLine()
	local U = C_TradeSkillUI
	for _, fname in ipairs({ "GetChildProfessionInfo", "GetBaseProfessionInfo" }) do
		local info = Call(U[fname])
		if type(info) == "table" and type(info.professionName) == "string" and info.professionName ~= "" then
			local name = info.parentProfessionName and info.parentProfessionName ~= "" and info.parentProfessionName or info.professionName
			return name, info.skillLevel, info.maxSkillLevel
		end
	end
	local name, rank, max = Call(U.GetTradeSkillLine)
	if type(name) == "string" and name ~= "" then
		return name, rank, max
	end
	return Call(GetTradeSkillLine)
end

function S.ReadModern()
	local U = C_TradeSkillUI
	if not (U and U.GetAllRecipeIDs) then
		return nil
	end
	local prof, rank, max = S.ModernLine()
	if type(prof) ~= "string" or prof == "" or prof == "UNKNOWN" then
		return nil
	end
	local ids = Call(U.GetAllRecipeIDs)
	if type(ids) ~= "table" or #ids == 0 then
		return nil
	end
	local recipes = {}
	for _, id in ipairs(ids) do
		local info = Call(U.GetRecipeInfo, id)
		if type(info) == "table" and info.learned ~= false and not info.isDummyRecipe and info.name then
			local r = { diff = S.DIFF[info.relativeDifficulty] or info.difficulty or "trivial", reagents = {} }
			local sch = U.GetRecipeSchematic and Call(U.GetRecipeSchematic, id, false)
			if type(sch) == "table" then
				if sch.outputItemID and sch.outputItemID > 0 then
					r.product = sch.outputItemID
					r.made = sch.quantityMin or 1
				end
				for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
					local first = slot.reagents and slot.reagents[1]
					if first and first.itemID then
						r.reagents[#r.reagents + 1] = { first.itemID, slot.quantityRequired or 1 }
					end
				end
			else
				-- older form of the same API
				r.product = C.ItemID(Call(U.GetRecipeItemLink, id))
				local lo = Call(U.GetRecipeNumItemsProduced, id)
				r.made = lo or 1
				for j = 1, (Call(U.GetRecipeNumReagents, id) or 0) do
					local _, _, count = Call(U.GetRecipeReagentInfo, id, j)
					local rid = C.ItemID(Call(U.GetRecipeReagentItemLink, id, j))
					if rid then
						r.reagents[#r.reagents + 1] = { rid, count or 1 }
					end
				end
			end
			recipes[info.name] = r
		end
	end
	return prof, rank, max, recipes
end

function S.Run(which, quiet)
	local prof, rank, max, recipes
	if which == "trade" then
		prof, rank, max, recipes = S.ReadModern()
	end
	if not prof then
		local api = S.API[which]
		if not api then
			return
		end
		prof, rank, max, recipes = S.Read(api)
	end
	if not prof then
		return
	end
	local key, name = C.Me()
	local n = C.SaveProfession(key, name, prof, rank, max, recipes)
	if not quiet and not S.told[prof] and n > 0 then
		S.told[prof] = true
		print(P .. string.format(T("Recipes saved: %s, %d"), prof, n))
	end
end
S.told = {}

-- /craftwise debug: what this client offers, for bug reports
function S.Debug()
	local U = C_TradeSkillUI
	local function Has(v) return v and "yes" or "no" end
	print(P .. "debug")
	print("  ProfessionsFrame: " .. (ProfessionsFrame and (ProfessionsFrame:IsShown() and "open" or "closed") or "no")
		.. ", TradeSkillFrame: " .. Has(TradeSkillFrame))
	print("  classic API: " .. Has(GetNumTradeSkills) .. (GetNumTradeSkills and (" (" .. tostring(Call(GetNumTradeSkills)) .. " rows, " .. tostring(Call(GetTradeSkillLine)) .. ")") or ""))
	print("  C_TradeSkillUI: " .. Has(U) .. (U and (", GetAllRecipeIDs " .. Has(U.GetAllRecipeIDs) .. ", schematic " .. Has(U.GetRecipeSchematic) .. ", profession info " .. Has(U.GetChildProfessionInfo or U.GetBaseProfessionInfo)) or ""))
	if U and U.GetAllRecipeIDs then
		local ids = Call(U.GetAllRecipeIDs)
		print("  recipes in the open window: " .. (type(ids) == "table" and #ids or "?") .. ", line: " .. tostring((S.ModernLine())))
	end
end

------------------------------------------------------------------------
-- Events: read when the window opens and when it changes (skill up,
-- new recipe). Updates are batched so a scroll does not rescan 20 times.
------------------------------------------------------------------------

local ev = CreateFrame("Frame")
local pending = {}
local function Queue(which)
	if pending[which] then
		return
	end
	pending[which] = true
	local function Run()
		pending[which] = nil
		S.Run(which)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.5, Run)
	else
		Run()
	end
end

ev:SetScript("OnEvent", function(_, event)
	if event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
		Queue("craft")
	else
		Queue("trade")
	end
	-- the Forever window: also read whenever it is shown
	if ProfessionsFrame and not S.hooked then
		S.hooked = true
		ProfessionsFrame:HookScript("OnShow", function() Queue("trade") end)
	end
end)
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "CRAFT_SHOW", "CRAFT_UPDATE", "PLAYER_LOGIN" }) do
	pcall(ev.RegisterEvent, ev, e)
end

ns.commands = ns.commands or {}
ns.commands.debug = S.Debug

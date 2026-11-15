--[[
  Craftwise tooltip: extra lines on every item tooltip.

    Used in
      Engineering: Bronze Tube ×2             (orange: still levels you)
      Blacksmithing: Rough Bronze Boots ×6  Alt (another character)
      and 3 more
    Made from: Copper Bar ×1, Tin Bar ×1
    You have: 14 (10 in bags, 4 in bank)
    Enough for: 7× Bronze Tube
    Still levels your profession: keep it
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local TT = {}
ns.Tooltip = TT

TT.MAX_USES = 6

local function Name(id)
	if GetItemInfo then
		local ok, name = pcall(GetItemInfo, id)
		if ok and type(name) == "string" then
			return name
		end
	end
	return "item " .. id
end

local function Color(diff)
	return "|cff" .. (C.DIFF_COLOR[diff] or "ffffff")
end

local function Count(id)
	if not GetItemCount then
		return nil
	end
	local okB, bags = pcall(GetItemCount, id)
	local okA, all = pcall(GetItemCount, id, true)
	if not okB or type(bags) ~= "number" then
		return nil
	end
	all = okA and type(all) == "number" and all or bags
	return all, bags, all - bags
end

-- The lines to add for an item: list of { left, r, g, b } or { left, right }.
function TT.Lines(id)
	local me = C.Me()
	local out = {}
	local uses = C.UsesOf(id, me)
	if #uses > 0 then
		out[#out + 1] = { "|cff8fd16a" .. T("Used in") .. "|r" }
		for i, u in ipairs(uses) do
			if i > TT.MAX_USES then
				out[#out + 1] = { "  |cffaaaaaa" .. string.format(T("and %d more"), #uses - TT.MAX_USES) .. "|r" }
				break
			end
			local who = u.char ~= me and ("  |cffaaaaaa" .. (u.who or "") .. "|r") or ""
			out[#out + 1] = { "  " .. u.prof .. ": " .. Color(u.r.diff) .. u.recipe .. "|r ×" .. u.count .. who }
		end
	end
	local makers = C.MakersOf(id, me)
	if #makers > 0 then
		local parts = {}
		for _, re in ipairs(makers[1].r.reagents or {}) do
			parts[#parts + 1] = Name(re[1]) .. " ×" .. re[2]
		end
		if #parts > 0 then
			out[#out + 1] = { "|cff8fd16a" .. T("Made from") .. ":|r " .. table.concat(parts, ", ") }
		end
	end
	if #uses > 0 then
		local all, bags, bank = Count(id)
		local verdict, best = C.Verdict(id, me)
		if all and all > 0 then
			local where = bank and bank > 0 and (" (" .. string.format(T("%d in bags, %d in bank"), bags, bank) .. ")") or ""
			out[#out + 1] = { string.format(T("You have: %d"), all) .. where }
			if verdict == "keep" then
				local n = C.EnoughFor(all, best.count)
				if n > 0 then
					out[#out + 1] = { string.format(T("Enough for: %d× %s"), n, best.recipe) }
				end
			end
		end
		if verdict == "keep" then
			out[#out + 1] = { "|cff40ff40" .. T("Still levels your profession: keep it") .. "|r" }
		elseif verdict == "grey" then
			out[#out + 1] = { "|cff808080" .. T("Your recipes for it no longer give skill") .. "|r" }
		end
	end
	-- keep it or clear it out (Bags.lua)
	if ns.Bags then
		for _, l in ipairs(ns.Bags.TipLines(id)) do
			out[#out + 1] = l
		end
	end
	return out
end

-- Adds the lines once per shown item.
function TT.Add(tip, link)
	local id = C.ItemID(link)
	if not id or tip.craftwiseID == id then
		return
	end
	tip.craftwiseID = id
	local lines = TT.Lines(id)
	if #lines == 0 then
		return
	end
	tip:AddLine(" ")
	for _, l in ipairs(lines) do
		tip:AddLine(l[1], 1, 1, 1, true)
	end
	tip:Show()
end

local function FromTip(tip)
	if not (tip and tip.GetItem) then
		return
	end
	local ok, _, link = pcall(tip.GetItem, tip)
	if ok and link and not (issecretvalue and issecretvalue(link)) then
		TT.Add(tip, link)
	end
end

local function Cleared(tip)
	tip.craftwiseID = nil
end

-- Modern clients: one post-call for every item tooltip.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
		FromTip(tip)
	end)
	for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
		if tip and tip.HookScript then
			pcall(tip.HookScript, tip, "OnTooltipCleared", Cleared)
		end
	end
else
	for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
		if tip and tip.HookScript then
			pcall(tip.HookScript, tip, "OnTooltipSetItem", FromTip)
			pcall(tip.HookScript, tip, "OnTooltipCleared", Cleared)
		end
	end
end

------------------------------------------------------------------------
-- Veins and herbs in the world: the skill they need, and yours
------------------------------------------------------------------------

local N = ns.Nodes

function TT.Node(tip)
	if not (tip and tip.GetName and N and N.ByName) then
		return
	end
	local okU, unit = pcall(tip.GetUnit, tip)
	if okU and unit then
		return
	end
	local fs = _G[(tip:GetName() or "") .. "TextLeft1"]
	local okT, name = pcall(fs and fs.GetText or function() end, fs)
	if not okT or type(name) ~= "string" or (issecretvalue and issecretvalue(name)) or tip.craftwiseNode == name then
		return
	end
	local node = N.ByName(name)
	if not node then
		return
	end
	tip.craftwiseNode = name
	local text, r, g, b = N.TipLine(node, N.Skills())
	tip:AddLine(text, r, g, b, true)
	tip:Show()
end

if GameTooltip and hooksecurefunc then
	hooksecurefunc(GameTooltip, "Show", TT.Node)
	pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(tip)
		tip.craftwiseNode = nil
	end)
end

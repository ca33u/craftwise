--[[
  Craftwise nodes: mining veins and herbs for your gathering professions.

  Where they are comes from QuestieDB (the WoW Forever build, so Forever's
  own zones and nodes are included). Only the object IDs below are part of
  Craftwise; the spawn points are read from QuestieDB in the game.

  Each node: profession, skill needed to gather it, and the item it gives
  (for the icon and the localized name in tooltips).
]]

local _, ns = ...
local C = ns.Core

local N = {}
ns.Nodes = N

-- { object IDs }, profession, skill, item, English name
N.TYPES = {
	-- Mining
	{ { 1731, 2055, 3763, 103713 }, "mining", 1, 2770, "Copper Vein" },      -- Copper Vein
	{ { 562111 }, "mining", 1, 2770, "Poor Copper Vein" },                        -- Poor Copper Vein (Forever)
	{ { 1732, 2054, 3764, 103711 }, "mining", 65, 2771, "Tin Vein" },     -- Tin Vein
	{ { 1610, 1667 }, "mining", 65, 3340, "Incendicite Mineral Vein" },                   -- Incendicite Mineral Vein
	{ { 2653 }, "mining", 75, 4278, "Lesser Bloodstone Deposit" },                         -- Lesser Bloodstone Deposit
	{ { 1733, 105569, 73940 }, "mining", 75, 2775, "Silver Vein" },          -- Silver Vein
	{ { 1735 }, "mining", 125, 2772, "Iron Deposit" },                        -- Iron Deposit
	{ { 19903 }, "mining", 150, 5833, "Indurium Mineral Vein" },                       -- Indurium Mineral Vein
	{ { 1734, 150080, 73941 }, "mining", 155, 2776, "Gold Vein" },         -- Gold Vein
	{ { 2040, 150079, 176645, 123310 }, "mining", 175, 3858, "Mithril Deposit" }, -- Mithril Deposit
	{ { 2047, 150081, 123309 }, "mining", 230, 7911, "Truesilver Deposit" },        -- Truesilver Deposit
	{ { 165658 }, "mining", 230, 11370, "Dark Iron Deposit" },                     -- Dark Iron Deposit
	{ { 324, 150082, 176643, 123848 }, "mining", 245, 10620, "Small Thorium Vein" }, -- Small Thorium Vein
	{ { 175404, 177388, 180215 }, "mining", 275, 10620, "Rich Thorium Vein" },     -- Rich Thorium Vein
	{ { 439628 }, "mining", nil, nil, "Fool's Gold Vein" },                       -- Fool's Gold Vein (Forever)
	{ { 439778 }, "mining", nil, nil, "Starsilver Vein" },                       -- Starsilver Vein (Forever)
	{ { 656332, 656333 }, "mining", nil, nil, "Chunk of Amber" },               -- Chunk of Amber (Forever)
	-- Herbalism
	{ { 1618, 3724, 657382, 657456 }, "herbalism", 1, 2447, "Peacebloom" }, -- Peacebloom
	{ { 656160 }, "herbalism", 1, 2447, "Wilted Peacebloom" },                     -- Wilted Peacebloom (Forever)
	{ { 1617, 3725, 657457 }, "herbalism", 1, 765, "Silverleaf" },          -- Silverleaf
	{ { 656161 }, "herbalism", 1, 765, "Stunted Silverleaf" },                      -- Stunted Silverleaf (Forever)
	{ { 1619, 3726, 657383, 657458 }, "herbalism", 15, 2449, "Earthroot" }, -- Earthroot
	{ { 1620, 3727, 657459 }, "herbalism", 50, 785, "Mageroyal" },         -- Mageroyal
	{ { 1621, 3729, 657385, 657460 }, "herbalism", 70, 2450, "Briarthorn" }, -- Briarthorn
	{ { 2045, 657394 }, "herbalism", 85, 3820, "Stranglekelp" },              -- Stranglekelp
	{ { 1622, 3730, 657386, 657461 }, "herbalism", 100, 2453, "Bruiseweed" }, -- Bruiseweed
	{ { 1623, 657387 }, "herbalism", 115, 3355, "Wild Steelbloom" },             -- Wild Steelbloom
	{ { 1628 }, "herbalism", 120, 3369, "Grave Moss" },                     -- Grave Moss
	{ { 1624 }, "herbalism", 125, 3356, "Kingsblood" },                     -- Kingsblood
	{ { 2041, 657390 }, "herbalism", 150, 3357, "Liferoot" },             -- Liferoot
	{ { 2042 }, "herbalism", 160, 3818, "Fadeleaf" },                     -- Fadeleaf
	{ { 2046 }, "herbalism", 170, 3821, "Goldthorn" },                     -- Goldthorn
	{ { 2043 }, "herbalism", 185, 3358, "Khadgar's Whisker" },                     -- Khadgar's Whisker
	{ { 2044 }, "herbalism", 195, 3819, "Wintersbite" },                     -- Wintersbite
	{ { 2866 }, "herbalism", 205, 4625, "Firebloom" },                     -- Firebloom
	{ { 142140, 180165 }, "herbalism", 210, 8831, "Purple Lotus" },           -- Purple Lotus
	{ { 142141, 176642 }, "herbalism", 220, 8836, "Arthas' Tears" },           -- Arthas' Tears
	{ { 142142, 176636, 180164 }, "herbalism", 230, 8838, "Sungrass" },   -- Sungrass
	{ { 142143 }, "herbalism", 235, 8839, "Blindweed" },                   -- Blindweed
	{ { 142144 }, "herbalism", 245, 8845, "Ghost Mushroom" },                   -- Ghost Mushroom
	{ { 142145, 176637 }, "herbalism", 250, 8846, "Gromsblood" },           -- Gromsblood
	{ { 176583, 176638, 180167 }, "herbalism", 260, 13464, "Golden Sansam" },  -- Golden Sansam
	{ { 176584, 176639, 180168 }, "herbalism", 270, 13463, "Dreamfoil" },  -- Dreamfoil
	{ { 176586, 176640, 180166 }, "herbalism", 280, 13465, "Mountain Silversage" },  -- Mountain Silversage
	{ { 176587, 176641 }, "herbalism", 285, 13466, "Plaguebloom" },          -- Plaguebloom
	{ { 176588 }, "herbalism", 290, 13467, "Icecap" },                  -- Icecap
	{ { 176589 }, "herbalism", 300, 13468, "Black Lotus" },                  -- Black Lotus
	{ { 439762 }, "herbalism", nil, nil, "Star Lotus" },                    -- Star Lotus (Forever)
	{ { 439810 }, "herbalism", nil, nil, "Moonroot" },                    -- Moonroot (Forever)
	{ { 667362 }, "herbalism", nil, nil, "Mirkweed" },                    -- Mirkweed (Forever)
	{ { 619450 }, "herbalism", nil, nil, "Lady's Tear Moss" },                    -- Lady's Tear Moss (Forever)
	{ { 694855 }, "herbalism", nil, nil, "Overgrown Duskweed" },                    -- Overgrown Duskweed (Forever)
}

N.FALLBACK_ICON = {
	mining = "Interface\\Icons\\INV_Ore_Copper_01",
	herbalism = "Interface\\Icons\\INV_Misc_Flower_02",
}

-- Skill line names (English and Russian clients).
N.SKILL_NAMES = {
	mining = { ["Mining"] = true, ["Горное дело"] = true },
	herbalism = { ["Herbalism"] = true, ["Травничество"] = true },
}

-- Object ID -> node type
N.byObject = {}
for _, t in ipairs(N.TYPES) do
	local node = { prof = t[2], skill = t[3], item = t[4] }
	for _, id in ipairs(t[1]) do
		N.byObject[id] = node
	end
end

------------------------------------------------------------------------
-- Data source (tests replace it)
------------------------------------------------------------------------

local function Safe(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if not ok or (issecretvalue and issecretvalue(a)) then
		return nil
	end
	return a, b
end

local function LoadTable(value)
	if type(value) == "table" then
		return value
	end
	if type(value) == "string" and type(loadstring or load) == "function" then
		local fn = (loadstring or load)(value)
		local ok, t = pcall(fn or function() end)
		if ok and type(t) == "table" then
			return t
		end
	end
	return nil
end

local areaMap

N.source = {
	available = function()
		local lib = _G.LibQuestieDB
		return type(lib) == "table" and type(lib.Object) == "table"
	end,
	name = function(id)
		local lib = _G.LibQuestieDB
		return lib and lib.Object and Safe(lib.Object.Get, id, "name")
	end,
	spawns = function(id)
		local lib = _G.LibQuestieDB
		return lib and lib.Object and Safe(lib.Object.Get, id, "spawns")
	end,
	uiMap = function(areaId)
		if areaMap == nil then
			areaMap = {}
			local lib = _G.LibQuestieDB
			local z = lib and lib.Support and Safe(lib.Support.Get, "ZoneDB")
			z = type(z) == "table" and z.private
			if type(z) == "table" then
				for _, key in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
					for k, v in pairs(LoadTable(z[key]) or {}) do
						areaMap[k] = v
					end
				end
			end
		end
		local m = areaMap[areaId]
		return (m and m > 0) and m or nil
	end,
}

------------------------------------------------------------------------
-- Your gathering skills
------------------------------------------------------------------------

-- prof -> rank for the gathering professions you have (nil if none).
function N.Skills()
	local out = {}
	if GetNumSkillLines and GetSkillLineInfo then
		local n = Safe(GetNumSkillLines) or 0
		for i = 1, n do
			local ok, name, header, _, rank = pcall(GetSkillLineInfo, i)
			if ok and name and not header then
				for prof, names in pairs(N.SKILL_NAMES) do
					if names[name] then
						out[prof] = rank or 1
					end
				end
			end
		end
	end
	-- the Mining window scanned by Craftwise also knows the rank
	if not out.mining then
		local key = C.Me()
		local ch = C.DB().chars[key]
		for prof, p in pairs(ch and ch.profs or {}) do
			if N.SKILL_NAMES.mining[prof] then
				out.mining = p.rank
			end
		end
	end
	return out
end

-- Gathering colour, as in the game: red (cannot yet), orange, yellow,
-- green, grey (gives no more skill). "unknown" when the skill is not known.
function N.Difficulty(skill, rank)
	if not skill or not rank then
		return "unknown"
	end
	if rank < skill then
		return "red"
	elseif rank < skill + 25 then
		return "optimal"
	elseif rank < skill + 50 then
		return "medium"
	elseif rank < skill + 100 then
		return "easy"
	end
	return "trivial"
end

N.SHOW_ABOVE = 25 -- also show nodes up to this much above your skill (in red)

-- Is a node worth drawing for these skills?
function N.Wanted(node, skills, showGrey)
	local rank = skills[node.prof]
	if not rank then
		return false
	end
	local diff = N.Difficulty(node.skill, rank)
	if diff == "red" then
		return node.skill <= rank + N.SHOW_ABOVE, diff
	end
	if diff == "trivial" and not showGrey then
		return false, diff
	end
	return true, diff
end

------------------------------------------------------------------------
-- A vein or herb by the name in its tooltip
------------------------------------------------------------------------

local byName

-- The node type for a tooltip's first line (English names, plus the names
-- QuestieDB gives in your client's language). nil when it is not a node.
function N.ByName(name)
	if type(name) ~= "string" then
		return nil
	end
	if not byName then
		byName = {}
		for _, t in ipairs(N.TYPES) do
			local node = { prof = t[2], skill = t[3], item = t[4] }
			if t[5] then
				byName[t[5]:lower()] = node
			end
			if N.source.available() then
				for _, id in ipairs(t[1]) do
					local n = N.source.name(id)
					if type(n) == "string" then
						byName[n:lower()] = node
					end
				end
			end
		end
	end
	return byName[name:lower()]
end

-- The tooltip line for a node and your skills: text, r, g, b.
function N.TipLine(node, skills)
	local T = ns.T
	local prof = T(node.prof == "mining" and "Mining" or "Herbalism")
	local rank = skills[node.prof]
	if not node.skill then
		return string.format(T("%s: skill needed unknown (Forever node)"), prof), 0.7, 0.7, 0.7
	end
	if not rank then
		return string.format(T("Requires %s %d: you do not have %s"), prof, node.skill, prof), 1, 0.25, 0.25
	end
	local diff = N.Difficulty(node.skill, rank)
	if diff == "red" then
		return string.format(T("Requires %s %d: you have %d, %d more to go"), prof, node.skill, rank, node.skill - rank), 1, 0.25, 0.25
	end
	local hex = C.DIFF_COLOR[diff] or "ffffff"
	local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
	local gives = diff == "trivial" and T("no more skill from it") or T("you can gather it")
	return string.format(T("%s %d: you have %d, %s"), prof, node.skill, rank, gives), r, g, b
end

------------------------------------------------------------------------
-- Spawn index: uiMapID -> list of { x, y (0..1), node }
------------------------------------------------------------------------

function N.Build()
	if N.index then
		return N.index
	end
	if not N.source.available() then
		return nil
	end
	local index = {}
	for id, node in pairs(N.byObject) do
		local spawns = N.source.spawns(id)
		if type(spawns) == "table" then
			if not node.name then
				node.name = N.source.name(id)
			end
			for area, points in pairs(spawns) do
				local map = type(area) == "number" and N.source.uiMap(area)
				if map and type(points) == "table" then
					local list = index[map] or {}
					index[map] = list
					for _, p in ipairs(points) do
						local x, y = p[1], p[2]
						if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 then
							list[#list + 1] = { x = x / 100, y = y / 100, node = node }
						end
					end
				end
			end
		end
	end
	N.index = index
	return index
end

-- Points to draw on a map for the current skills.
function N.PointsFor(map, skills, showGrey)
	local index = N.Build()
	local out = {}
	for _, p in ipairs(index and index[map] or {}) do
		local want, diff = N.Wanted(p.node, skills, showGrey)
		if want then
			out[#out + 1] = { x = p.x, y = p.y, node = p.node, diff = diff }
		end
	end
	return out
end

-- Icon and name of a node type, from the item it gives.
function N.Icon(node)
	if node.item then
		local icon = (C_Item and C_Item.GetItemIconByID and Safe(C_Item.GetItemIconByID, node.item))
			or (GetItemIcon and Safe(GetItemIcon, node.item))
		if icon then
			return icon
		end
	end
	return N.FALLBACK_ICON[node.prof]
end

function N.Label(node)
	local item = node.item and GetItemInfo and Safe(GetItemInfo, node.item)
	local name = node.name or item or "?"
	if item and node.name and item ~= node.name then
		return node.name .. " (" .. item .. ")"
	end
	return name
end

return N

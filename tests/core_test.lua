-- Craftwise logic outside the game: lua tests/core_test.lua
package.path = "./tests/?.lua;" .. package.path
dofile("tests/stubs.lua")

local NAMES = { [2840] = "Copper Bar", [2841] = "Bronze Bar", [2880] = "Weak Flux", [4371] = "Bronze Tube", [2770] = "Copper Ore" }
local SELL = { [2840] = 15, [4371] = 200 }
function UnitName() return "Saz" end
function GetRealmName() return "Forever" end
function GetItemInfo(id) return NAMES[id], nil, 1, 1, 1, "", "", 20, "", "", SELL[id] or 0 end
local COUNT = { [2841] = { 10, 14 } }
function GetItemCount(id, bank)
	local c = COUNT[id] or { 0, 0 }
	return bank and c[2] or c[1]
end
function time() return 1 end

LoadFile("Locale.lua")
LoadFile("Core.lua")
local C = NS.Core
LoadFile("Scan.lua")
local S = NS.Scan
LoadFile("Tooltip.lua")
local TT = NS.Tooltip
LoadFile("Auction.lua")
local A = NS.Auction
WorldMapFrame = StubObj()
LoadFile("Nodes.lua")
local N = NS.Nodes
LoadFile("Map.lua")
local M = NS.Map

-- a fake Engineering window
local ROWS = {
	{ "Parts", "header" },
	{ "Bronze Tube", "optimal", 4371, { { 2841, 2 }, { 2880, 1 } } },
	{ "Copper Modulator", "trivial", 4363, { { 2840, 2 } } },
	{ "Rough Dynamite", "trivial", 4358, { { 2840, 1 } } },
}
GetTradeSkillLine = function() return "Engineering", 112, 150 end
GetNumTradeSkills = function() return #ROWS end
GetTradeSkillInfo = function(i) return ROWS[i][1], ROWS[i][2], 0, true end
GetTradeSkillItemLink = function(i) return ROWS[i][3] and ("|cffffffff|Hitem:" .. ROWS[i][3] .. "::::|h[x]|h|r") end
GetTradeSkillNumMade = function() return 1, 1 end
GetTradeSkillNumReagents = function(i) return ROWS[i][4] and #ROWS[i][4] or 0 end
GetTradeSkillReagentInfo = function(i, j) return NAMES[ROWS[i][4][j][1]], "", ROWS[i][4][j][2], 0 end
GetTradeSkillReagentItemLink = function(i, j) return "|Hitem:" .. ROWS[i][4][j][1] .. "|h" end

S.Run("trade", true)
local ch = CraftwiseDB.chars["Saz-Forever"]
Check(ch and ch.profs.Engineering and ch.profs.Engineering.rank == 112, "engineering saved with its skill")
local tube = ch.profs.Engineering.recipes["Bronze Tube"]
Check(tube and tube.product == 4371 and #tube.reagents == 2 and tube.reagents[1][2] == 2, "recipe: product and reagents with counts")
Check(ch.profs.Engineering.recipes.Parts == nil, "headers are not recipes")

-- an alt with Blacksmithing
C.SaveProfession("Alt-Forever", "Alt", "Blacksmithing", 90, 150, {
	["Rough Bronze Boots"] = { diff = "medium", product = 6350, reagents = { { 2841, 6 } } },
})
local uses = C.UsesOf(2841, "Saz-Forever")
Check(#uses == 2 and uses[1].char == "Saz-Forever" and uses[1].recipe == "Bronze Tube", "uses: your recipe first")
Check(uses[2].who == "Alt" and uses[2].count == 6, "uses: the alt's recipe too")
local v, best = C.Verdict(2841, "Saz-Forever")
Check(v == "keep" and best.recipe == "Bronze Tube", "bronze still levels engineering: keep")
Check(C.Verdict(2840, "Saz-Forever") == "grey", "copper bar: only grey recipes")
Check(C.Verdict(2770, "Saz-Forever") == nil, "copper ore: no recipe of yours")
Check(C.EnoughFor(14, 2) == 7, "14 bars make 7 tubes")
local makers = C.MakersOf(4371)
Check(#makers == 1 and makers[1].recipe == "Bronze Tube", "tube is made by engineering")

-- a later scan with a filter on keeps recipes it did not see
ROWS = { { "Bronze Tube", "medium", 4371, { { 2841, 2 }, { 2880, 1 } } } }
S.Run("trade", true)
local recipes = CraftwiseDB.chars["Saz-Forever"].profs.Engineering.recipes
Check(recipes["Rough Dynamite"] and recipes["Bronze Tube"].diff == "medium", "rescan updates colours, keeps hidden recipes")

-- the newer window (C_TradeSkillUI), as in WoW Forever
C_TradeSkillUI = {
	GetAllRecipeIDs = function() return { 101, 102, 103 } end,
	GetBaseProfessionInfo = function() return { professionName = "First Aid", skillLevel = 150, maxSkillLevel = 150 } end,
	GetRecipeInfo = function(id)
		return ({ [101] = { name = "Linen Bandage", learned = true, relativeDifficulty = 3 },
			[102] = { name = "First Aid Kit", learned = true, relativeDifficulty = 0 },
			[103] = { name = "Runecloth Bandage", learned = false } })[id]
	end,
	GetRecipeSchematic = function(id)
		if id == 102 then
			return { outputItemID = 9001, quantityMin = 1, reagentSlotSchematics = {
				{ reagents = { { itemID = 1251 } }, quantityRequired = 3 },
				{ reagents = { { itemID = 159 } }, quantityRequired = 1 } } }
		end
		return { outputItemID = 1251, quantityMin = 1, reagentSlotSchematics = { { reagents = { { itemID = 2589 } }, quantityRequired = 1 } } }
	end,
}
S.Run("trade", true)
local fa = CraftwiseDB.chars["Saz-Forever"].profs["First Aid"]
Check(fa and fa.rank == 150 and fa.recipes["First Aid Kit"].diff == "optimal", "new window: profession and colour read")
Check(fa.recipes["First Aid Kit"].reagents[1][1] == 1251 and fa.recipes["First Aid Kit"].reagents[1][2] == 3, "new window: reagents with counts")
Check(fa.recipes["Runecloth Bandage"] == nil, "new window: unlearned recipes skipped")
Check(C.UsesOf(159)[1].recipe == "First Aid Kit", "water is used in the First Aid Kit")
Check(pcall(SlashCmdList.CRAFTWISE, "debug"), "/craftwise debug runs")
C_TradeSkillUI = nil

-- tooltip lines
local function Has(lines, s)
	for _, l in ipairs(lines) do
		if l[1]:find(s, 1, true) then return true end
	end
	return false
end
local lines = TT.Lines(2841)
Check(Has(lines, "Engineering: ") and Has(lines, "Bronze Tube"), "tooltip: used in engineering")
Check(Has(lines, "Alt"), "tooltip: alt named")
Check(Has(lines, "You have: 14") and Has(lines, "10 in bags, 4 in bank"), "tooltip: count in bags and bank")
Check(Has(lines, "Enough for: 7"), "tooltip: enough for")
Check(Has(lines, "keep it"), "tooltip: keep verdict")
Check(Has(TT.Lines(4371), "Made from") and Has(TT.Lines(4371), "Bronze Bar ×2"), "tooltip: made from")
Check(#TT.Lines(2770) == 0, "tooltip: nothing for unrelated items")
local added = 0
local tip = StubObj({ AddLine = function() added = added + 1 end })
TT.Add(tip, "|Hitem:2841|h")
local first = added
TT.Add(tip, "|Hitem:2841|h")
Check(first > 0 and added == first, "tooltip lines added once per item")

-- auction: the sale in numbers
Check(C.SellMath(100, 0, 30).verdict == "noprice", "no price: nothing to compare")
Check(C.SellMath(100, 100, 30).verdict == "vendor", "after the cut below vendor: vendor")
local m = C.SellMath(100, 1000, 30)
Check(m.net == 950 and m.gain == 850 and m.verdict == "good", "big gain, small deposit: post it")
Check(math.abs(m.need - 30 / 880) < 1e-9, "chance needed = deposit / (gain + deposit)")
Check(C.SellMath(100, 200, 60).verdict == "ok", "gain 90 vs deposit 60: worth it if it sells often (40%)")
Check(C.SellMath(100, 120, 30).verdict == "risky", "gain 14 vs deposit 30: risky (68%)")
Check(C.Cut("Tanaris") == 0.15 and C.Cut("Orgrimmar") == 0.05, "neutral auction house takes 15%")
-- the other auctions
Check(C.Market({}, 100) == nil and C.Market({ { unit = 50, qty = 3, mine = true } }, 100) == nil, "nobody else: no market")
local mk = C.Market({ { unit = 90, qty = 5 }, { unit = 80, qty = 2 }, { unit = 120, qty = 10 }, { unit = 70, qty = 1, mine = true } }, 100)
Check(mk.cheapest == 80 and mk.items == 17 and mk.auctions == 3 and mk.ahead == 7 and mk.undercut == 79, "market: cheapest, on sale, cheaper than yours, your own ignored")

-- new auction house: a commodity in the sell frame
local function Frame(t) t.IsVisible = function() return true end; t.IsShown = t.IsVisible; return t end
C_Item = { GetItemID = function() return 2589 end, GetItemName = function() return "Linen Cloth" end,
	GetItemInfo = function() return "Linen Cloth", nil, 1, 5, 0, "Trade Goods", "Cloth", 20, 0, "", 7 end }
local price = 30
AuctionHouseFrame = Frame({
	CommoditiesSellFrame = Frame({
		GetItem = function() return {} end,
		GetQuantity = function() return 20 end,
		GetUnitPrice = function() return price end,
		GetDepositAmount = function() return 12 end,
		PriceInput = { SetAmount = function(_, v) price = v end },
	}),
})
C_AuctionHouse = {
	GetNumCommoditySearchResults = function() return 2 end,
	GetCommoditySearchResultInfo = function(_, i) return ({ { unitPrice = 25, quantity = 40 }, { unitPrice = 31, quantity = 5 } })[i] end,
}
local cur = A.Current()
Check(cur and cur.items == 20 and cur.vendor == 140 and cur.buyout == 600 and cur.deposit == 12 and #cur.results == 2, "new AH: 20 cloth at 30c, vendor 7c each, deposit 12c")
local rows, adv, v = A.Lines(cur, "Orgrimmar")
Check(v == "good" and #rows == 5, "cloth: post it; five rows with the market")
Check(adv[2] and adv[2][2] == 24, "40 cheaper on sale: suggests 24c to sell first")
A.UsePrice(cur.frame, 24)
Check(price == 24, "Use puts the price in the sell frame")
C_AuctionHouse.GetCommoditySearchResultInfo = function(_, i) return ({ { unitPrice = 6, quantity = 40 }, { unitPrice = 31, quantity = 5 } })[i] end
local _, adv2, v2 = A.Lines(A.Current(), "Orgrimmar")
Check(v2 == "vendor" and adv2[1][1]:find("vendor"), "others sell under the vendor price: vendor it")
AuctionHouseFrame = nil

-- old auction house
GetAuctionSellItemInfo = function() return "Bronze Tube", "", 5, 1, true, 0, 0, 5, 20, 4371 end
AuctionsStackSizeEntry = { GetNumber = function() return 5 end }
AuctionsNumStacksEntry = { GetNumber = function() return 2 end }
BuyoutPrice = {}
MoneyInputFrame_GetCopper = function() return 150 end
AuctionFrameAuctions = { priceType = 1, duration = 1, IsVisible = function() return true end }
AuctionsDepositMoneyFrame = { staticMoney = 60 }
C_Item.GetItemInfo = function() return "Bronze Tube", nil, 1, 5, 0, "", "", 20, 0, "", 200 end
cur = A.Current()
Check(cur.items == 10 and cur.vendor == 2000 and cur.buyout == 1500 and cur.deposit == 60, "old AH: 2 stacks of 5, per-item buyout")
Check(select(3, A.Lines(cur)) == "vendor", "tubes at 1.5s each: vendor pays more")
AuctionFrameAuctions.priceType = 2
MoneyInputFrame_GetCopper = function() return 5000 end
cur = A.Current()
Check(cur.buyout == 10000 and select(3, A.Lines(cur)) == "good", "per-stack buyout: post it")
C_Item = nil

-- veins and herbs in the world: tooltip line
local tin = N.ByName("Tin Vein")
Check(tin and tin.prof == "mining" and tin.skill == 65 and N.ByName("tin vein") == tin and N.ByName("Orgrimmar Grunt") == nil, "tooltip name finds the node")
local text = N.TipLine(tin, { mining = 50 })
Check(text:find("65") and text:find("50") and text:find("15"), "tin at 50: needs 65, 15 more to go")
Check(N.TipLine(tin, {}):find("do not have"), "no mining: says so")
Check(N.TipLine(tin, { mining = 70 }):find("can gather"), "tin at 70: you can gather it")
Check(N.TipLine(N.ByName("Fool's Gold Vein"), { mining = 70 }):find("unknown"), "Forever node: skill unknown")

-- gathering nodes
Check(N.byObject[1731].prof == "mining" and N.byObject[1731].skill == 1, "copper vein is mining 1")
Check(N.byObject[1618].prof == "herbalism", "peacebloom is herbalism")
Check(N.Difficulty(1, 30) == "medium" and N.Difficulty(65, 50) == "red" and N.Difficulty(1, 150) == "trivial", "gathering colours")
Check(N.Difficulty(nil, 50) == "unknown", "Forever nodes without a known skill")
Check(N.Wanted(N.byObject[1732], { mining = 50 }) == true, "tin (65) shown in red at 50")
Check(N.Wanted(N.byObject[1735], { mining = 50 }) == false, "iron (125) hidden at 50")
Check(N.Wanted(N.byObject[1731], { mining = 150 }) == false, "grey copper hidden by default")
Check(N.Wanted(N.byObject[1731], { mining = 150 }, true) == true, "grey copper shown on request")
Check(N.Wanted(N.byObject[1618], { mining = 150 }) == false, "no herbalism: no herbs")
N.source = {
	available = function() return true end,
	name = function(id) return ({ [1731] = "Copper Vein", [1618] = "Peacebloom" })[id] end,
	spawns = function(id)
		if id == 1731 then return { [12] = { { 50, 50 }, { -1, -1 } }, [999] = { { 1, 1 } } } end
		if id == 1618 then return { [12] = { { 20, 30 } } } end
	end,
	uiMap = function(area) return area == 12 and 1429 or nil end,
}
local pts = N.PointsFor(1429, { mining = 10 })
Check(#pts == 1 and pts[1].x == 0.5 and pts[1].node.name == "Copper Vein", "map points: copper in Elwynn, no dungeon (-1) points")
Check(#N.PointsFor(1429, { mining = 10, herbalism = 10 }) == 2, "both professions: veins and herbs")
Check(#N.PointsFor(9999, { mining = 10 }) == 0, "other map: nothing")
local dx, dy, dist = M.Offset(0, 0, 100, 0, 400, 140)
Check(math.abs(dx) < 1e-9 and math.abs(dy - 35) < 1e-9, "100 yards north: straight up")
dx, dy = M.Offset(0, 0, 0, -100, 400, 140)
Check(math.abs(dx - 35) < 1e-9 and math.abs(dy) < 1e-9, "100 yards east: right")
dx, dy = M.Offset(0, 0, 100, 0, 400, 140, math.pi / 2)
Check(math.abs(dx - 35) < 1e-6 and math.abs(dy) < 1e-6, "facing west, rotating minimap: north is to the right")
SlashCmdList.CRAFTWISE("grey")
Check(M.Settings().grey == true, "/craftwise grey toggles grey nodes")
LoadFile("Minimap.lua")
SlashCmdList.CRAFTWISE("pins")
Check(M.Settings().off == true, "/craftwise pins: all veins and herbs off")
Check(pcall(M.RefreshMinimap) and pcall(M.RefreshWorld), "maps refresh with pins off")
SlashCmdList.CRAFTWISE("pins")
Check(M.Settings().off == false, "and back on")
Check(pcall(NS.MinimapButton.Refresh) and pcall(SlashCmdList.CRAFTWISE, "button"), "minimap button toggles")

-- bags and bank: keep it or clear it out
function UnitLevel() return 34 end
LoadFile("Bags.lua")
local B = NS.Bags
local me = "Saz-Forever"
local need = C.NeedToLevel(2841, me)
Check(need == 114, "bronze to level: 38 points x 1.5 (yellow) x 2 per tube = 114")
local a = C.Assess(2841, { quality = 1, class = 7 }, { me = me, level = 34, have = 14 })
Check(a.kind == "need" and a.keep == 114 and a.spare == 0, "14 bronze: all needed")
a = C.Assess(2841, { quality = 1, class = 7 }, { me = me, level = 34, have = 200 })
Check(a.kind == "need" and a.spare == 86, "200 bronze: 86 spare")
Check(C.Assess(2840, { quality = 1, class = 7 }, { me = me, level = 34, have = 5 }).kind == "grey", "copper bar: only grey recipes left")
C.SaveProfession(me, "Saz", "Mining", 60, 75, {
	["Smelt Bronzeite"] = { diff = "trivial", product = 2841, reagents = { { 2772, 2 } } },
})
a = C.Assess(2772, { quality = 1, class = 7 }, { me = me, level = 34, have = 9 })
Check(a.kind == "refine" and a.product == 2841 and a.makes == 4, "ore that smelts into bars you level with: refine, 9 make 4")
C.SaveProfession("Alt-Forever", "Alt", "Blacksmithing", 90, 150, {
	["Rough Bronze Boots"] = { diff = "medium", product = 6350, reagents = { { 2841, 6 } } },
	["Silver Rod"] = { diff = "optimal", product = 6338, reagents = { { 2842, 1 } } },
})
a = C.Assess(2842, { quality = 1, class = 7 }, { me = me, level = 34, have = 3 })
Check(a.kind == "alt" and a.who == "Alt", "silver: only your alt levels with it")
Check(C.Assess(9999, { quality = 0 }, { me = me, level = 34 }).kind == "junk", "grey quality: junk")
Check(C.Assess(9998, { quality = 1, class = 0, minLevel = 5 }, { me = me, level = 34 }).kind == "outdated", "level 5 food at 34: outdated")
Check(C.Assess(9997, { quality = 1, class = 0, minLevel = 25 }, { me = me, level = 34 }) == nil, "level 25 food at 34: fine")
Check(C.Assess(9996, { quality = 2, class = 4, minLevel = 10, equipLoc = "INVTYPE_CHEST" }, { me = me, level = 34 }).kind == "outdated", "level 10 chest at 34: outdated")
Check(C.Assess(9995, { quality = 1, class = 1, minLevel = 5, equipLoc = "INVTYPE_BAG" }, { me = me, level = 34 }) == nil, "a bag is never outdated")
Check(C.Assess(9994, { quality = 1, class = 7 }, { me = me, level = 34 }).kind == "unused", "a trade good none of your recipes use")
Check(C.Assess(9993, { quality = 1, class = 12 }, { me = me, level = 34 }) == nil, "quest items and the rest: nothing to say")
Check(B.BadgeFor({ kind = "need", spare = 0 }) == "need" and B.BadgeFor({ kind = "need", spare = 3 }) == "spare", "badges: needed, spare")
Check(B.BadgeFor({ kind = "grey" }) == "go" and B.BadgeFor({ kind = "unused" }) == "go" and B.BadgeFor(nil) == nil, "badges: can go")
local FAKE = {
	[1] = { { kind = "junk" }, { name = "Broken Fang", sell = 5 } },
	[2] = { { kind = "need", spare = 10, keep = 5 }, { name = "Bronze Bar", sell = 50 } },
	[3] = { { kind = "refine", product = 2841, makes = 4 }, { name = "Ore", sell = 1 } },
	[4] = { { kind = "outdated", minLevel = 5 }, { name = "Bread", sell = 20 } },
}
local r = B.Report({ [1] = 4, [2] = 15, [3] = 9, [4] = 3 }, function(id) return FAKE[id][1], FAKE[id][2] end)
Check(#r.go == 2 and r.go[1].name == "Bread" and r.goValue == 80, "report: what can go, priciest first, vendor total")
Check(#r.spare == 1 and r.spare[1].count == 10 and #r.refine == 1, "report: spare and refine")
Check(Has(B.TipLines(2841), "To level: about 114"), "tooltip: how many to keep for leveling")
local slots = { [0] = { { itemID = 2841, stackCount = 14 }, { itemID = 2840, stackCount = 5 } } }
C_Container = {
	GetContainerNumSlots = function(bag) return slots[bag] and #slots[bag] or 0 end,
	GetContainerItemInfo = function(bag, slot) return slots[bag] and slots[bag][slot] end,
}
Check(pcall(SlashCmdList.CRAFTWISE, "bags"), "/craftwise bags runs")
Check(pcall(B.Refresh) and pcall(SlashCmdList.CRAFTWISE, "badges"), "badges refresh and toggle")

SlashCmdList.CRAFTWISE("list")
SlashCmdList.CRAFTWISE("reset")
Check(next(CraftwiseDB.chars) == nil, "reset forgets everything")
Report("core_test")

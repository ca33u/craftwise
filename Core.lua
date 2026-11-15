--[[
  Craftwise core: the saved recipes of all your characters and the lookups
  the tooltip and the auction helper use. No frames here (tests/core_test.lua).

  CraftwiseDB = {
    chars = {
      ["Name-Realm"] = {
        name = "Name",
        profs = {
          ["Engineering"] = {
            rank = 112, max = 150, scanned = <time>,
            recipes = {
              ["Bronze Tube"] = {
                product = 4371, made = 1, diff = "optimal",
                reagents = { { 2841, 2 }, { 2880, 1 } },  -- item ID, count
              },
            },
          },
        },
      },
    },
  }

  diff is the recipe's colour for that character: "optimal" (orange),
  "medium" (yellow), "easy" (green), "trivial" (grey, gives no skill).
]]

local _, ns = ...

local C = {}
ns.Core = C

C.DIFF_ORDER = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
C.DIFF_COLOR = {
	optimal = "ff8040",
	medium = "ffff00",
	easy = "40bf40",
	trivial = "808080",
}
C.AH_CUT = 0.05

function C.DB()
	CraftwiseDB = type(CraftwiseDB) == "table" and CraftwiseDB or {}
	CraftwiseDB.chars = type(CraftwiseDB.chars) == "table" and CraftwiseDB.chars or {}
	return CraftwiseDB
end

function C.Me()
	local name = UnitName and UnitName("player") or "?"
	local realm = GetRealmName and GetRealmName() or ""
	return name .. "-" .. realm, name
end

-- Item ID from a link or an ID.
function C.ItemID(link)
	if type(link) == "number" then
		return link
	end
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(link:match("item:(%d+)"))
end

------------------------------------------------------------------------
-- Saving a scanned profession
------------------------------------------------------------------------

-- Merges recipes seen in a profession window into the character's record.
-- Recipes not seen this time are kept: a filter or a collapsed header
-- may hide them, and a learned recipe is never forgotten.
function C.SaveProfession(key, name, prof, rank, max, seen)
	if type(prof) ~= "string" or prof == "" then
		return 0
	end
	local db = C.DB()
	local ch = db.chars[key] or { profs = {} }
	db.chars[key] = ch
	ch.name = name or ch.name
	ch.profs = ch.profs or {}
	local p = ch.profs[prof] or { recipes = {} }
	ch.profs[prof] = p
	p.rank, p.max = rank or p.rank, max or p.max
	p.scanned = time and time() or 0
	p.recipes = p.recipes or {}
	local n = 0
	for recipe, r in pairs(seen or {}) do
		p.recipes[recipe] = r
		n = n + 1
	end
	C.index = nil
	return n
end

------------------------------------------------------------------------
-- Index: which recipes use an item, which make it
------------------------------------------------------------------------

function C.Index()
	if C.index then
		return C.index
	end
	local usedIn, madeBy = {}, {}
	for key, ch in pairs(C.DB().chars) do
		for prof, p in pairs(ch.profs or {}) do
			for recipe, r in pairs(p.recipes or {}) do
				local use = { char = key, who = ch.name, prof = prof, recipe = recipe, r = r }
				for _, re in ipairs(r.reagents or {}) do
					local id, count = re[1], re[2]
					if id then
						usedIn[id] = usedIn[id] or {}
						table.insert(usedIn[id], { char = key, who = ch.name, prof = prof, recipe = recipe, r = r, count = count or 1 })
					end
				end
				if r.product then
					madeBy[r.product] = madeBy[r.product] or {}
					table.insert(madeBy[r.product], use)
				end
			end
		end
	end
	C.index = { usedIn = usedIn, madeBy = madeBy }
	return C.index
end

-- Your own recipes first, then the ones still giving skill, then by name.
local function ByRelevance(me)
	return function(a, b)
		local am, bm = a.char == me, b.char == me
		if am ~= bm then
			return am
		end
		local ad, bd = C.DIFF_ORDER[a.r.diff] or 5, C.DIFF_ORDER[b.r.diff] or 5
		if ad ~= bd then
			return ad < bd
		end
		if a.prof ~= b.prof then
			return a.prof < b.prof
		end
		return a.recipe < b.recipe
	end
end

-- Recipes that need this item, most relevant first.
function C.UsesOf(id, me)
	local list = {}
	for _, u in ipairs(C.Index().usedIn[id] or {}) do
		list[#list + 1] = u
	end
	table.sort(list, ByRelevance(me or C.Me()))
	return list
end

-- Recipes that make this item, most relevant first.
function C.MakersOf(id, me)
	local list = {}
	for _, u in ipairs(C.Index().madeBy[id] or {}) do
		list[#list + 1] = u
	end
	table.sort(list, ByRelevance(me or C.Me()))
	return list
end

-- What your current character should do with the item:
--   "keep"    a recipe of yours that still gives skill needs it
--   "grey"    only recipes that no longer give skill need it
--   nil       none of your recipes use it (or nothing scanned)
-- and the best recipe to level with (for "enough for").
function C.Verdict(id, me)
	me = me or C.Me()
	local grey, best
	for _, u in ipairs(C.UsesOf(id, me)) do
		if u.char == me then
			if u.r.diff ~= "trivial" then
				best = best or u
			else
				grey = grey or u
			end
		end
	end
	if best then
		return "keep", best
	elseif grey then
		return "grey", grey
	end
	return nil
end

-- How many times the recipe can be made from `have` of this reagent.
function C.EnoughFor(have, count)
	if type(have) ~= "number" or type(count) ~= "number" or count <= 0 then
		return 0
	end
	return math.floor(have / count)
end

------------------------------------------------------------------------
-- Auction or vendor
------------------------------------------------------------------------

-- Neutral auction houses (Gadgetzan, Booty Bay, Everlook) take 15%.
C.NEUTRAL_CUT = 0.15
C.NEUTRAL_ZONES = {
	["Tanaris"] = true, ["Танарис"] = true,
	["Stranglethorn Vale"] = true, ["Тернистая долина"] = true,
	["Winterspring"] = true, ["Зимние Ключи"] = true,
}

function C.Cut(zone)
	return C.NEUTRAL_ZONES[zone or ""] and C.NEUTRAL_CUT or C.AH_CUT
end

-- The sale in numbers.
--   vendor:  what a vendor pays for the whole lot (copper)
--   total:   what buyers pay for the whole lot (copper)
--   deposit: the auction house deposit (copper)
-- If it sells you get the total minus the cut, and the deposit back.
-- If it does not, the deposit is gone and the items come back to your
-- bags (a vendor still buys them then). So posting beats the vendor when
--   chance * (net - vendor + deposit) > deposit
-- and the chance it has to sell with is deposit / (net - vendor + deposit).
-- Returns { verdict, net, gain, need }:
--   "noprice" no price set
--   "vendor"  the auction after the cut pays no more than a vendor
--   "good"    worth it even if it sells only 1 time in 4 (need <= 25%)
--   "ok"      worth it if it sells about half the time (need <= 60%)
--   "risky"   the deposit eats most of the gain (need > 60%)
function C.SellMath(vendor, total, deposit, cut)
	vendor, deposit = vendor or 0, deposit or 0
	if type(total) ~= "number" or total <= 0 then
		return { verdict = "noprice", net = 0, gain = 0 }
	end
	local net = math.floor(total * (1 - (cut or C.AH_CUT)))
	local gain = net - vendor
	if gain <= 0 then
		return { verdict = "vendor", net = net, gain = gain }
	end
	local need = deposit / (gain + deposit)
	local verdict = need <= 0.25 and "good" or need <= 0.6 and "ok" or "risky"
	return { verdict = verdict, net = net, gain = gain, need = need }
end

-- The other auctions for the same item, cheapest first.
--   list: { {unit=, qty=, mine=bool} } as the auction house returns them
--   mine: your price per item
-- Returns nil when nobody else sells it, else
--   { cheapest, items, auctions, ahead (items cheaper than yours),
--     undercut (a price 1 copper under the cheapest, or nil) }
function C.Market(list, mine)
	local cheapest, items, auctions, ahead = nil, 0, 0, 0
	for _, r in ipairs(list or {}) do
		if not r.mine and type(r.unit) == "number" and r.unit > 0 then
			local q = type(r.qty) == "number" and r.qty or 1
			items, auctions = items + q, auctions + 1
			if not cheapest or r.unit < cheapest then
				cheapest = r.unit
			end
			if mine and r.unit < mine then
				ahead = ahead + q
			end
		end
	end
	if not cheapest then
		return nil
	end
	return {
		cheapest = cheapest,
		items = items,
		auctions = auctions,
		ahead = ahead,
		undercut = cheapest > 1 and cheapest - 1 or nil,
	}
end

-- 12345 -> "1g 23s 45c" (coin icons in the game when available)
function C.Money(copper)
	copper = math.floor(math.abs(copper or 0))
	if GetCoinTextureString then
		local ok, s = pcall(GetCoinTextureString, copper)
		if ok and type(s) == "string" then
			return s
		end
	end
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 or #out == 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end

------------------------------------------------------------------------
-- Bags and bank: is an item worth keeping?
------------------------------------------------------------------------

-- Crafts per skill point by recipe colour (orange always gives a point,
-- yellow mostly, green now and then).
C.CRAFTS_PER_POINT = { optimal = 1, medium = 1.5, easy = 3 }
C.OUTDATED_LEVELS = 15 -- food, potions and gear this far under your level

-- About how many of an item your character still needs to level the
-- professions that use it: for each of your recipes that still gives
-- skill, reagent count x crafts to the profession's current cap. The
-- largest of those, not the sum: one recipe at a time gets you there.
-- Returns need (0 when capped or unknown) and the recipe behind it.
function C.NeedToLevel(id, me)
	me = me or C.Me()
	local need, why = 0, nil
	local ch = C.DB().chars[me]
	for _, u in ipairs(C.UsesOf(id, me)) do
		if u.char == me and u.r.diff ~= "trivial" then
			local p = ch and ch.profs and ch.profs[u.prof]
			local left = p and type(p.rank) == "number" and type(p.max) == "number" and (p.max - p.rank) or 0
			local n = math.ceil(math.max(left, 0) * (C.CRAFTS_PER_POINT[u.r.diff] or 1) * (u.count or 1))
			if n > need then
				need, why = n, u
			end
		end
	end
	return need, why
end

-- A recipe of yours that turns this item, and only this item, into
-- something your recipes still level with (ore -> bar, cloth -> bolt):
-- the refined thing is what is worth keeping.
-- Returns { recipe use, product id, makes (how many you can make) } or nil.
function C.Refine(id, have, me)
	me = me or C.Me()
	for _, u in ipairs(C.UsesOf(id, me)) do
		local r = u.r
		if u.char == me and r.product and r.product ~= id and #(r.reagents or {}) == 1 then
			local verdict = C.Verdict(r.product, me)
			local alt = C.NeededByAlt(r.product, me)
			if verdict == "keep" or alt then
				return { use = u, product = r.product, makes = C.EnoughFor(have or 0, u.count) }
			end
		end
	end
	return nil
end

-- Another character of yours still levels with it: their name, or nil.
function C.NeededByAlt(id, me)
	me = me or C.Me()
	for _, u in ipairs(C.UsesOf(id, me)) do
		if u.char ~= me and u.r.diff ~= "trivial" then
			return u.who or "?"
		end
	end
	return nil
end

function C.AnyScanned()
	for _, ch in pairs(C.DB().chars) do
		for _ in pairs(ch.profs or {}) do
			return true
		end
	end
	return false
end

-- What to do with an item in your bags or bank.
--   id:   item ID
--   info: { quality, class (classID), minLevel, equipLoc, sell } (GetItemInfo)
--   ctx:  { me, level, have (bags + bank) }
-- Returns nil (nothing to say) or { kind, ... }, kind one of:
--   "need"     still levels your profession (keep = about how many, spare)
--   "alt"      another character of yours levels with it (who)
--   "refine"   make it into something better first (product, makes)
--   "grey"     your recipes with it no longer give skill
--   "junk"     grey quality: a vendor item
--   "outdated" food, potions or gear far below your level
--   "unused"   a trade good none of your recipes use
function C.Assess(id, info, ctx)
	info, ctx = info or {}, ctx or {}
	local me = ctx.me or C.Me()
	local have = ctx.have or 0
	if info.quality == 0 then
		return { kind = "junk" }
	end
	local verdict = C.Verdict(id, me)
	if verdict == "keep" then
		local need, why = C.NeedToLevel(id, me)
		local spare = need > 0 and have > need and (have - need) or 0
		return { kind = "need", keep = need, spare = spare, use = why }
	end
	local refine = C.Refine(id, have, me)
	if refine then
		return { kind = "refine", product = refine.product, makes = refine.makes, use = refine.use }
	end
	local alt = C.NeededByAlt(id, me)
	if alt then
		return { kind = "alt", who = alt }
	end
	if verdict == "grey" then
		return { kind = "grey" }
	end
	local level, min = ctx.level, info.minLevel
	if type(level) == "number" and type(min) == "number" and min > 0 and min <= level - C.OUTDATED_LEVELS then
		local gear = info.equipLoc and info.equipLoc ~= "" and info.equipLoc ~= "INVTYPE_BAG"
			and info.equipLoc ~= "INVTYPE_AMMO" and info.equipLoc ~= "INVTYPE_QUIVER"
		if info.class == 0 or gear then
			return { kind = "outdated", minLevel = min }
		end
	end
	if info.class == 7 and C.AnyScanned() and #C.UsesOf(id, me) == 0 then
		return { kind = "unused" }
	end
	return nil
end

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------

local P = "|cff8fd16aCraftwise|r "

SLASH_CRAFTWISE1 = "/craftwise"
SLASH_CRAFTWISE2 = "/cw"
SlashCmdList = SlashCmdList or {}
SlashCmdList.CRAFTWISE = function(msg)
	local T = ns.T
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "reset" then
		C.DB().chars = {}
		C.index = nil
		print(P .. T("Forgot all saved recipes."))
	elseif msg == "list" or msg == "" then
		print(P .. T("Known professions:"))
		local any = false
		for _, ch in pairs(C.DB().chars) do
			for prof, p in pairs(ch.profs or {}) do
				local n = 0
				for _ in pairs(p.recipes or {}) do n = n + 1 end
				print(string.format("  %s: %s %s/%s, %d", ch.name or "?", prof, p.rank or "?", p.max or "?", n))
				any = true
			end
		end
		if not any then
			print("  " .. T("none yet") .. ". " .. T("Open each profession window once so Craftwise learns your recipes."))
		end
		if msg == "" then
			print(P .. T("Commands: /craftwise list | bags | badges | reset | pins | map | minimap | grey | button"))
		end
	elseif ns.commands and ns.commands[msg] then
		ns.commands[msg]()
	else
		print(P .. T("Commands: /craftwise list | bags | badges | reset | pins | map | minimap | grey | button"))
	end
end

return C

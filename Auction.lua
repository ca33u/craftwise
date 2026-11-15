--[[
  Craftwise auction helper: while you set up an auction, a panel next to
  the auction house tells you whether it is worth it.

    Selling 5 × Linen Cloth
    Vendor                              25s
    If it sells, after the 5% cut    1g 42s
    Deposit, lost if it does not sell   30s
    Cheapest now          28s each · 40 on sale
    Cheaper than yours                12 items

    Worth it if it sells at least 1 time in 2 (35%): +1g 17s over the vendor.
    12 cheaper on sale: price it at 27s 99c to sell first.   [Use]

  Why a chance: if an auction does not sell you lose the deposit but get
  the items back (a vendor still buys them). So the gain over the vendor
  only pays off when it sells often enough; the shorter the duration, the
  smaller the deposit.

  Works with the new auction house (Forever) and the old one.
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local A = {}
ns.Auction = A

local function Secret(v)
	return issecretvalue and issecretvalue(v) or false
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if not ok or Secret(a) then
		return nil
	end
	return a, b
end

local function Num(v)
	if Secret(v) then
		return nil
	end
	return type(v) == "number" and v or tonumber(v)
end

local function SellPrice(item)
	if not item then
		return 0
	end
	local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if type(get) ~= "function" then
		return 0
	end
	local ok, r = pcall(function()
		return { get(item) }
	end)
	return ok and Num(r[11]) or 0
end

------------------------------------------------------------------------
-- New auction house (C_AuctionHouse)
------------------------------------------------------------------------

-- The sell frame in use and its item, or nil.
function A.SellFrame()
	local ah = AuctionHouseFrame
	if not (ah and ah:IsShown()) then
		return nil
	end
	for _, key in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
		local f = ah[key]
		if f and f:IsVisible() and f.GetItem then
			local loc = Call(f.GetItem, f)
			if loc then
				return f, loc, key == "CommoditiesSellFrame"
			end
		end
	end
	return nil
end

-- Other auctions of this item, as the auction house lists them next to
-- the sell frame.
function A.Results(commodity, itemID, loc)
	local list, AH = {}, C_AuctionHouse
	if not AH then
		return list
	end
	if commodity then
		for i = 1, Num(Call(AH.GetNumCommoditySearchResults, itemID)) or 0 do
			local r = Call(AH.GetCommoditySearchResultInfo, itemID, i)
			if type(r) == "table" then
				list[#list + 1] = { unit = Num(r.unitPrice), qty = Num(r.quantity), mine = r.containsOwnerItem or r.containsAccountItem }
			end
		end
	else
		local key = Call(AH.GetItemKeyFromItem, loc)
		if key then
			for i = 1, Num(Call(AH.GetNumItemSearchResults, key)) or 0 do
				local r = Call(AH.GetItemSearchResultInfo, key, i)
				if type(r) == "table" then
					list[#list + 1] = { unit = Num(r.buyoutAmount), qty = Num(r.quantity), mine = r.containsOwnerItem or r.containsAccountItem }
				end
			end
		end
	end
	return list
end

local function ModernDeposit(f, loc, itemID, commodity, qty)
	local d = f.GetDepositAmount and Num(Call(f.GetDepositAmount, f))
	if d then
		return d
	end
	local AH = C_AuctionHouse
	local duration = f.GetDuration and Num(Call(f.GetDuration, f)) or 2
	if AH and commodity then
		d = Num(Call(AH.CalculateCommodityDeposit, itemID, duration, qty))
	elseif AH then
		d = Num(Call(AH.CalculateItemDeposit, loc, duration, qty))
	end
	return d or 0
end

function A.CurrentModern()
	local f, loc, commodity = A.SellFrame()
	if not f then
		return nil
	end
	local itemID = C_Item and Num(Call(C_Item.GetItemID, loc))
	local name = C_Item and Call(C_Item.GetItemName, loc)
	local qty = f.GetQuantity and Num(Call(f.GetQuantity, f))
	if not qty and f.QuantityInput and f.QuantityInput.GetQuantity then
		qty = Num(Call(f.QuantityInput.GetQuantity, f.QuantityInput))
	end
	qty = math.max(1, qty or 1)
	local unit = commodity and f.GetUnitPrice and Num(Call(f.GetUnitPrice, f))
	if not unit and f.PriceInput and f.PriceInput.GetAmount then
		unit = Num(Call(f.PriceInput.GetAmount, f.PriceInput))
	end
	unit = unit or 0
	local vendorUnit = SellPrice(itemID)
	return {
		item = itemID,
		name = name,
		items = qty,
		unit = unit,
		vendorUnit = vendorUnit,
		vendor = vendorUnit * qty,
		buyout = unit * qty,
		deposit = ModernDeposit(f, loc, itemID, commodity, qty),
		results = A.Results(commodity, itemID, loc),
		frame = f,
	}
end

-- Puts a price into the sell frame's price box.
function A.UsePrice(f, copper)
	local input = f and f.PriceInput
	if not (input and input.SetAmount and copper and copper > 0) then
		return
	end
	pcall(input.SetAmount, input, copper)
	for _, m in ipairs({ "OnPriceChanged", "UpdateTotalPrice", "UpdatePostState" }) do
		if f[m] then
			pcall(f[m], f)
		end
	end
	A.Refresh()
end

------------------------------------------------------------------------
-- Old auction house (the Auctions tab)
------------------------------------------------------------------------

local function EditNum(name)
	local eb = _G[name]
	if eb and eb.GetNumber then
		local ok, n = pcall(eb.GetNumber, eb)
		if ok and type(n) == "number" and n > 0 then
			return n
		end
	end
	return nil
end

function A.CurrentLegacy()
	if not (GetAuctionSellItemInfo and AuctionFrameAuctions and AuctionFrameAuctions:IsVisible()) then
		return nil
	end
	local ok, name, _, count, _, _, _, _, _, totalCount, itemID = pcall(GetAuctionSellItemInfo)
	if not ok or not name then
		return nil
	end
	local stack = EditNum("AuctionsStackSizeEntry") or Num(count) or 1
	local stacks = EditNum("AuctionsNumStacksEntry") or 1
	local items = stack * stacks
	if Num(totalCount) and items > totalCount then
		items = totalCount
	end
	local buyout = 0
	if BuyoutPrice and MoneyInputFrame_GetCopper then
		local okB, b = pcall(MoneyInputFrame_GetCopper, BuyoutPrice)
		buyout = okB and Num(b) or 0
	end
	-- the buyout box is per item or per stack depending on the price type
	if AuctionFrameAuctions.priceType == 1 then
		buyout = buyout * stack
	end
	buyout = buyout * stacks
	local deposit
	if AuctionsDepositMoneyFrame and Num(AuctionsDepositMoneyFrame.staticMoney) then
		deposit = AuctionsDepositMoneyFrame.staticMoney
	elseif CalculateAuctionDeposit then
		local okD, d = pcall(CalculateAuctionDeposit, AuctionFrameAuctions.duration, stack, stacks)
		deposit = okD and Num(d) or 0
	end
	local vendorUnit = SellPrice(itemID)
	return {
		item = itemID,
		name = name,
		items = items,
		unit = items > 0 and buyout / items or 0,
		vendorUnit = vendorUnit,
		vendor = vendorUnit * items,
		buyout = buyout,
		deposit = deposit or 0,
	}
end

function A.Current()
	return A.CurrentModern() or A.CurrentLegacy()
end

------------------------------------------------------------------------
-- What the panel says
------------------------------------------------------------------------

local function Pct(x)
	return math.floor(x * 100 + 0.5)
end

-- "1 time in 3" from a chance
local function OneIn(need)
	return math.max(1, math.floor(1 / need))
end

-- Returns the rows { left, right }, the advice lines { text, price } and
-- the verdict. price on an advice line: a price the Use button puts in.
function A.Lines(cur, zone)
	local rows, advice = {}, {}
	local cut = C.Cut(zone)
	if cur.vendor > 0 then
		local each = cur.items > 1 and ("  |cff999999(" .. string.format(T("%s each"), C.Money(cur.vendorUnit)) .. ")|r") or ""
		rows[#rows + 1] = { T("Vendor"), C.Money(cur.vendor) .. each }
	else
		rows[#rows + 1] = { T("Vendor"), "|cff999999" .. T("will not buy it") .. "|r" }
	end
	local m = C.SellMath(cur.vendor, cur.buyout, cur.deposit, cut)
	local market = cur.results and C.Market(cur.results, cur.unit)
	if m.verdict ~= "noprice" then
		rows[#rows + 1] = { string.format(T("If it sells, after the %d%% cut"), Pct(cut)), C.Money(m.net) }
	end
	rows[#rows + 1] = { T("Deposit, lost if it does not sell"), C.Money(cur.deposit) }
	if cur.results then
		if market then
			rows[#rows + 1] = { T("Cheapest now"), string.format(T("%s each · %d on sale"), C.Money(market.cheapest), market.items) }
			if m.verdict ~= "noprice" then
				rows[#rows + 1] = { T("Cheaper than yours"), market.ahead > 0 and ("|cffffd100" .. string.format(T("%d items"), market.ahead) .. "|r") or ("|cff40ff40" .. T("none, yours is the cheapest") .. "|r") }
			end
		else
			rows[#rows + 1] = { T("Cheapest now"), "|cff999999" .. T("nobody else sells it") .. "|r" }
		end
	end

	local v = m.verdict
	if v == "noprice" then
		advice[#advice + 1] = { "|cffaaaaaa" .. T("Set a price to see if it is worth it.") .. "|r" }
		if market and market.undercut then
			advice[#advice + 1] = { string.format(T("Cheapest now is %s each."), C.Money(market.cheapest)), market.undercut }
		end
		return rows, advice, v
	end
	-- others sell below what a vendor pays: nothing to win here
	if market and cur.vendorUnit > 0 and market.cheapest * (1 - cut) <= cur.vendorUnit then
		advice[#advice + 1] = { "|cffff6060" .. T("Others sell it for less than a vendor pays. Just sell it to a vendor.") .. "|r" }
		return rows, advice, "vendor"
	end
	if v == "vendor" then
		advice[#advice + 1] = { "|cffff6060" .. T("Sell it to a vendor: after the cut the auction gives you less.") .. "|r" }
	elseif v == "good" then
		advice[#advice + 1] = { "|cff40ff40" .. string.format(T("Post it: +%s over the vendor. Pays off even if it sells only 1 time in %d."), C.Money(m.gain), OneIn(m.need)) .. "|r" }
	elseif v == "ok" then
		advice[#advice + 1] = { "|cffffd100" .. string.format(T("Worth it if it sells at least %d%% of the time: +%s over the vendor."), Pct(m.need), C.Money(m.gain)) .. "|r" }
	else
		advice[#advice + 1] = { "|cffff9933" .. string.format(T("Risky: +%s over the vendor, but it has to sell %d%% of the time to pay off the deposit. A shorter duration costs less."), C.Money(m.gain), Pct(m.need)) .. "|r" }
	end
	if market and v ~= "vendor" then
		if market.ahead > 0 and market.undercut then
			-- only suggest a price that still beats the vendor
			if math.floor(market.undercut * (1 - cut)) > cur.vendorUnit then
				advice[#advice + 1] = { string.format(T("%d cheaper on sale: price it at %s to sell first."), market.ahead, C.Money(market.undercut)), market.undercut }
			end
		elseif cur.unit > 0 and cur.unit < market.cheapest * 0.8 then
			local ask = market.undercut or market.cheapest
			advice[#advice + 1] = { string.format(T("You are %d%% under the cheapest: you could ask %s."), Pct(1 - cur.unit / market.cheapest), C.Money(ask)), ask }
		end
	end
	return rows, advice, v
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------

local panel
local WIDTH = 320

local function Font(parent, template)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	fs:SetJustifyH("LEFT")
	return fs
end

local function Build(anchor)
	if panel or not anchor then
		return
	end
	panel = CreateFrame("Frame", "CraftwiseAuctionPanel", anchor, BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetWidth(WIDTH)
	panel:SetHeight(40)
	panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2, -30)
	if panel.SetBackdrop then
		panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		panel:SetBackdropColor(0.05, 0.05, 0.07, 0.92)
		panel:SetBackdropBorderColor(0.56, 0.82, 0.42, 0.5)
	end
	panel.title = Font(panel, "GameFontNormalSmall")
	panel.title:SetPoint("TOPLEFT", 10, -8)
	panel.title:SetPoint("RIGHT", -10, 0)
	panel.title:SetWordWrap(false)
	panel.rows, panel.advice = {}, {}
	-- the panel stays shown with its parent and only fades out when
	-- nothing is being sold, so this keeps ticking
	local wait = 0
	panel:SetScript("OnUpdate", function(_, elapsed)
		wait = wait - elapsed
		if wait > 0 then
			return
		end
		wait = 0.3
		A.Refresh()
	end)
end

local function Row(i)
	local r = panel.rows[i]
	if not r then
		r = { l = Font(panel), r = Font(panel) }
		r.r:SetJustifyH("RIGHT")
		panel.rows[i] = r
	end
	return r
end

local function Advice(i)
	local a = panel.advice[i]
	if not a then
		a = { text = Font(panel) }
		a.text:SetWordWrap(true)
		a.button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		a.button:SetSize(54, 20)
		a.button:SetText(T("Use"))
		panel.advice[i] = a
	end
	return a
end

function A.Refresh()
	if not panel then
		return
	end
	local cur = A.Current()
	if not cur then
		panel:SetAlpha(0)
		for _, a in ipairs(panel.advice) do
			a.button:Hide()
		end
		return
	end
	panel:SetAlpha(1)
	local zone = GetZoneText and GetZoneText() or nil
	local rows, advice = A.Lines(cur, zone)
	panel.title:SetText("|cff8fd16aCraftwise|r  " .. string.format(T("Selling %d × %s"), cur.items, cur.name or "?"))
	local y = 28
	for i, line in ipairs(rows) do
		local r = Row(i)
		r.l:ClearAllPoints()
		r.l:SetPoint("TOPLEFT", 10, -y)
		r.r:ClearAllPoints()
		r.r:SetPoint("TOPRIGHT", -10, -y)
		r.l:SetText(line[1])
		r.r:SetText(line[2])
		r.l:Show()
		r.r:Show()
		y = y + 15
	end
	for i = #rows + 1, #panel.rows do
		panel.rows[i].l:Hide()
		panel.rows[i].r:Hide()
	end
	y = y + 6
	for i, line in ipairs(advice) do
		local a = Advice(i)
		local withButton = line[2] and cur.frame and true or false
		a.text:ClearAllPoints()
		a.text:SetPoint("TOPLEFT", 10, -y)
		a.text:SetWidth(WIDTH - 20 - (withButton and 62 or 0))
		a.text:SetText(line[1])
		a.text:Show()
		local h = math.max(14, a.text:GetStringHeight() or 14)
		if withButton then
			local price, f = line[2], cur.frame
			a.button:ClearAllPoints()
			a.button:SetPoint("TOPRIGHT", -8, -(y - 2))
			a.button:SetScript("OnClick", function()
				A.UsePrice(f, price)
			end)
			a.button:Show()
			h = math.max(h, 20)
		else
			a.button:Hide()
		end
		y = y + h + 5
	end
	for i = #advice + 1, #panel.advice do
		panel.advice[i].text:Hide()
		panel.advice[i].button:Hide()
	end
	panel:SetHeight(y + 6)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name ~= "Blizzard_AuctionHouseUI" and name ~= "Blizzard_AuctionUI" then
		return
	end
	Build(AuctionHouseFrame or AuctionFrame)
	A.Refresh()
end)
for _, e in ipairs({ "ADDON_LOADED", "AUCTION_HOUSE_SHOW" }) do
	pcall(ev.RegisterEvent, ev, e)
end

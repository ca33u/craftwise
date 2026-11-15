--[[
  Craftwise map: veins and herbs of your gathering professions on the
  world map and the minimap.

  Only what you can gather is shown (plus the next tier, in red), coloured
  by how much skill it still gives. Grey nodes are hidden unless you ask.

  /craftwise map       world map pins on/off
  /craftwise minimap   minimap pins on/off
  /craftwise grey      also show nodes that give no more skill
]]

local _, ns = ...
local T = ns.T
local C = ns.Core
local N = ns.Nodes

local M = {}
ns.Map = M

local P = "|cff8fd16aCraftwise|r "

local TINT = {
	red = { 1, 0.35, 0.35, 0.75 },
	optimal = { 1, 1, 1, 1 },
	medium = { 1, 1, 1, 1 },
	easy = { 1, 1, 1, 0.9 },
	trivial = { 0.6, 0.6, 0.6, 0.55 },
	unknown = { 1, 1, 1, 1 },
}

function M.Settings()
	local db = C.DB()
	db.map = type(db.map) == "table" and db.map or {}
	local s = db.map
	if s.world == nil then s.world = true end
	if s.minimap == nil then s.minimap = true end
	if s.grey == nil then s.grey = false end
	return s
end

------------------------------------------------------------------------
-- Pins (shared look)
------------------------------------------------------------------------

local function PinEnter(self)
	if not self.node then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(N.Label(self.node))
	if self.node.skill then
		local col = C.DIFF_COLOR[self.diff] or (self.diff == "red" and "ff4040") or "ffffff"
		GameTooltip:AddLine("|cff" .. col .. string.format(T("Skill needed: %d"), self.node.skill) .. "|r")
	end
	GameTooltip:Show()
end

local function PinLeave()
	GameTooltip:Hide()
end

local function NewPin(parent, size)
	local pin = CreateFrame("Frame", nil, parent)
	pin:SetSize(size, size)
	pin.icon = pin:CreateTexture(nil, "OVERLAY")
	pin.icon:SetAllPoints()
	pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pin:EnableMouse(true)
	pin:SetScript("OnEnter", PinEnter)
	pin:SetScript("OnLeave", PinLeave)
	return pin
end

local function Dress(pin, p)
	pin.node, pin.diff = p.node, p.diff
	pin.icon:SetTexture(N.Icon(p.node))
	local t = TINT[p.diff] or TINT.unknown
	pin.icon:SetVertexColor(t[1], t[2], t[3])
	pin:SetAlpha(t[4])
end

------------------------------------------------------------------------
-- World map
------------------------------------------------------------------------

local worldPins, worldScale = {}, nil
local WORLD_SIZE = 14

local function Canvas()
	return WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
end

local function CanvasScale()
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	if sc and sc.GetCanvasScale then
		local ok, s = pcall(sc.GetCanvasScale, sc)
		if ok and type(s) == "number" and s > 0 then
			return s
		end
	end
	return 1
end

function M.RefreshWorld()
	local canvas = Canvas()
	if not canvas then
		return
	end
	for _, pin in ipairs(worldPins) do
		pin:Hide()
	end
	if M.Settings().off or not M.Settings().world or not WorldMapFrame:IsShown() then
		return
	end
	local map = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
	if not map then
		return
	end
	local points = N.PointsFor(map, N.Skills(), M.Settings().grey)
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	local cs = CanvasScale()
	worldScale = cs
	for i, p in ipairs(points) do
		local pin = worldPins[i]
		if not pin then
			pin = NewPin(canvas, WORLD_SIZE)
			pin:SetFrameStrata("HIGH")
			worldPins[i] = pin
		end
		Dress(pin, p)
		-- keep the pin the same size on screen whatever the zoom
		pin:SetScale(1 / cs)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", canvas, "TOPLEFT", p.x * w * cs, -p.y * h * cs)
		pin:Show()
	end
end

-- A small check box in the corner of the world map: veins and herbs on/off.
local function WorldCheck()
	if M.check or not WorldMapFrame then
		return
	end
	local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
	local c = CreateFrame("CheckButton", "CraftwiseWorldMapCheck", parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	c:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 6, 6)
	c:SetFrameStrata("HIGH")
	c.label = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
	c.label:SetText(T("Veins and herbs"))
	c:SetScript("OnClick", function() ns.commands.pins() end)
	M.check = c
end

local function HookWorld()
	if M.worldHooked or not WorldMapFrame then
		return
	end
	M.worldHooked = true
	WorldCheck()
	WorldMapFrame:HookScript("OnShow", function()
		if M.check then
			M.check:SetChecked(not M.Settings().off)
			M.check:SetShown(next(N.Skills()) ~= nil)
		end
	end)
	if WorldMapFrame.OnMapChanged then
		hooksecurefunc(WorldMapFrame, "OnMapChanged", M.RefreshWorld)
	end
	WorldMapFrame:HookScript("OnShow", M.RefreshWorld)
	local wait = 0
	WorldMapFrame:HookScript("OnUpdate", function(_, elapsed)
		wait = wait - elapsed
		if wait > 0 then
			return
		end
		wait = 0.25
		if worldScale and CanvasScale() ~= worldScale then
			M.RefreshWorld()
		end
	end)
end

------------------------------------------------------------------------
-- Minimap
------------------------------------------------------------------------

local miniPins = {}
local MINI_SIZE = 12

-- Yards across the minimap at each zoom level.
M.MINIMAP_YARDS = {
	outdoor = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
	indoor = { 300, 240, 180, 120, 80, 50 },
}

local function WorldPos(map, x, y)
	if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
		return nil
	end
	local ok, _, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
	if ok and pos and pos.x and not (issecretvalue and issecretvalue(pos.x)) then
		return pos.x, pos.y
	end
	return nil
end

-- Minimap offset (pixels, right/up) of a world point from the player.
-- World x grows north and world y grows west.
function M.Offset(px, py, nx, ny, yardsAcross, pixelsAcross, facing)
	local north, west = nx - px, ny - py
	local scale = pixelsAcross / yardsAcross
	local dx, dy = -west * scale, north * scale
	if facing then
		local c, s = math.cos(facing), math.sin(facing)
		dx, dy = dx * c + dy * s, -dx * s + dy * c
	end
	return dx, dy, math.sqrt(dx * dx + dy * dy)
end

local cache = { map = nil, points = nil }

local function MiniPoints(map)
	if cache.map == map and cache.points and cache.when and (GetTime() - cache.when) < 10 then
		return cache.points
	end
	local list = {}
	for _, p in ipairs(N.PointsFor(map, N.Skills(), M.Settings().grey)) do
		local wx, wy = WorldPos(map, p.x, p.y)
		if wx then
			p.wx, p.wy = wx, wy
			list[#list + 1] = p
		end
	end
	cache.map, cache.points, cache.when = map, list, GetTime()
	return list
end

function M.RefreshMinimap()
	local used = 0
	if not M.Settings().off and M.Settings().minimap and Minimap and Minimap:IsVisible() and C_Map and C_Map.GetBestMapForUnit then
		local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
		local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
		if okM and map and okP and pos and pos.x and not (issecretvalue and issecretvalue(pos.x)) then
			local px, py = WorldPos(map, pos.x, pos.y)
			if px then
				local zoom = (Minimap.GetZoom and Minimap:GetZoom() or 0) + 1
				local inside = IsIndoors and IsIndoors()
				local yards = M.MINIMAP_YARDS[inside and "indoor" or "outdoor"][zoom] or 466
				local size = Minimap:GetWidth()
				local radius = size / 2 - MINI_SIZE / 2
				local facing
				if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
					local okF, f = pcall(GetPlayerFacing)
					facing = okF and type(f) == "number" and not (issecretvalue and issecretvalue(f)) and f or nil
				end
				for _, p in ipairs(MiniPoints(map)) do
					local dx, dy, dist = M.Offset(px, py, p.wx, p.wy, yards, size, facing)
					if dist <= radius then
						used = used + 1
						local pin = miniPins[used]
						if not pin then
							pin = NewPin(Minimap, MINI_SIZE)
							pin:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
							miniPins[used] = pin
						end
						Dress(pin, p)
						pin:ClearAllPoints()
						pin:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
						pin:Show()
					end
				end
			end
		end
	end
	for i = used + 1, #miniPins do
		miniPins[i]:Hide()
	end
end

local driver = CreateFrame("Frame")
local wait = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	wait = wait - elapsed
	if wait > 0 then
		return
	end
	wait = 0.1
	M.RefreshMinimap()
end)

------------------------------------------------------------------------
-- Events and commands
------------------------------------------------------------------------

local function Changed()
	cache.points = nil
	M.RefreshWorld()
	M.RefreshMinimap()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		HookWorld()
		if C_Timer and C_Timer.After then
			C_Timer.After(5, function()
				if not N.source.available() and next(N.Skills()) then
					print(P .. T("Install QuestieDB to see veins and herbs on the map."))
				end
			end)
		end
	end
	Changed()
end)
for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
	pcall(ev.RegisterEvent, ev, e)
end

local function Toggle(key, label)
	local s = M.Settings()
	s[key] = not s[key]
	print(P .. T(label) .. ": " .. (s[key] and T("on") or T("off")))
	Changed()
end

ns.commands = ns.commands or {}
ns.commands.map = function() Toggle("world", "World map pins") end
ns.commands.minimap = function() Toggle("minimap", "Minimap pins") end
ns.commands.grey = function() Toggle("grey", "Grey nodes") end
-- the main switch: everything off on both maps (the minimap button and the
-- check box on the world map use it)
ns.commands.pins = function()
	local s = M.Settings()
	s.off = not s.off
	print(P .. T("Veins and herbs on the map") .. ": " .. (s.off and T("off") or T("on")))
	Changed()
	if M.check then
		M.check:SetChecked(not s.off)
	end
	if ns.MinimapButton and ns.MinimapButton.Refresh then
		ns.MinimapButton.Refresh()
	end
end
ns.commands.button = function()
	if ns.MinimapButton then
		ns.MinimapButton.Toggle()
	end
end

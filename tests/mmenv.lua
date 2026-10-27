-- Mock WoW 1.12 world map + saved-instance API for ModernMapMarkers. Requires global MM_DIR.
local DIR = assert(MM_DIR, "MM_DIR not set")
table.getn = table.getn or function(t) return #t end
getn = table.getn; tinsert = table.insert; tremove = table.remove; strlower = string.lower; strupper = string.upper
strfind = string.find; strsub = string.sub; strlen = string.len; strgsub = string.gsub; format = string.format
string.gfind = string.gmatch; floor = math.floor; max = math.max; min = math.min
mod = function(a, b) return a - math.floor(a / b) * b end
unpack = unpack or table.unpack
function getglobal(n) return _G[n] end
function setglobal(n, v) _G[n] = v end
local oldpairs = pairs
CLOCK = 5000.0; CHAT = {}; ERRORS = {}; UNKNOWN = {}
local function logerr(w, m) ERRORS[#ERRORS + 1] = { where = w, msg = tostring(m) } end
function try(w, fn, ...) local ok, r = xpcall(fn, function(m) return debug.traceback(tostring(m), 2) end, ...); if not ok then logerr(w, r) end return ok, r end

local ALL, Obj = {}, {}
local MT = { __index = function(t, k)
  if k == "SetDesaturated" and W and W.noDesaturate then return nil end   -- client without desaturation support
  local v = Obj[k]; if v ~= nil then return v end
  if type(k) == "string" and k:match("^[A-Z]") then return function() UNKNOWN[k] = (UNKNOWN[k] or 0) + 1 end end
end }
local function new(kind, name, parent)
  local o = setmetatable({ _kind = kind, _name = name, _parent = parent, _shown = true, _scripts = {}, _events = {}, _alpha = 1, _w = 0, _h = 0,
    _text = "", _lines = {}, _points = {}, _vertex = { 1, 1, 1 }, _desat = nil }, MT)
  if name then _G[name] = o end
  ALL[#ALL + 1] = o; return o
end
local function runHook(f, hook, ...)
  local fn = f._scripts[hook]; if not fn then return end
  local old = _G.this; _G.this = f; local a = { ... }; for i = 1, 9 do _G["arg" .. i] = a[i] end
  local ok, e = xpcall(fn, function(m) return debug.traceback(tostring(m), 2) end); _G.this = old
  if not ok then logerr((f._name or f._kind) .. ":" .. hook, e) end
end
function Obj.GetName(s) return s._name end
function Obj.GetParent(s) return s._parent end
function Obj.SetScript(s, h, fn) s._scripts[h] = fn end
function Obj.GetScript(s, h) return s._scripts[h] end
function Obj.RegisterEvent(s, e) s._events[e] = true end
function Obj.UnregisterEvent(s, e) s._events[e] = nil end
function Obj.Show(s) if not s._shown then s._shown = true; runHook(s, "OnShow") end end
function Obj.Hide(s) if s._shown then s._shown = false; runHook(s, "OnHide") end end
function Obj.IsShown(s) return s._shown and 1 or nil end
function Obj.IsVisible(s) local f = s; while f do if not f._shown then return nil end f = f._parent end return 1 end
function Obj.SetAlpha(s, a) s._alpha = a end
function Obj.GetAlpha(s) return s._alpha end
function Obj.SetWidth(s, w) s._w = w end
function Obj.SetHeight(s, h) s._h = h end
function Obj.GetWidth(s) return s._w end
function Obj.GetHeight(s) return s._h end
function Obj.SetTexture(s, t) s._tex = t end
function Obj.GetTexture(s) return s._tex end
function Obj.SetText(s, t) s._text = t end
function Obj.GetText(s) return s._text end
function Obj.SetVertexColor(s, r, g, b) s._vertex = { r, g, b } end
function Obj.ClearAllPoints(s) s._points = {} end
function Obj.SetPoint(s, ...) s._points[#s._points + 1] = { ... } end
function Obj.GetFrameLevel(s) return 1 end
function Obj.CreateTexture(s, name) local t = new("Texture", name, s); return t end
function Obj.CreateFontString(s, name) return new("FontString", name, s) end
-- desaturation exists on some clients only
function Obj.SetDesaturated(s, v) s._desat = (v and v ~= 0) or nil end
-- tooltip
function Obj.SetOwner(s, o) s._owner = o; s._lines = {} end
function Obj.ClearLines(s) s._lines = {} end
function Obj.AddLine(s, t, r, g, b) if t == nil then error("AddLine(nil)", 2) end s._lines[#s._lines + 1] = t end
function Obj.NumLines(s) return #s._lines end
function CreateFrame(kind, name, parent) return new(kind, name, parent or UIParent) end
UIParent = new("Frame", "UIParent", nil)
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) CHAT[#CHAT + 1] = tostring(m) end }
SlashCmdList = {}
function GetTime() return CLOCK end
date = os.date
function time() return 1700000000 + math.floor(CLOCK) end
function UnitName(u) return "Tester" end
function GetRealmName() return "TestRealm" end
W_ZONE = { real = "Feralas", sub = "Dire Maul", instanceType = "none", instanceName = "Feralas" }
function GetRealZoneText() return W_ZONE.real end
function GetSubZoneText() return W_ZONE.sub end
function UseClassicInstanceAPI(on) if on then GetInstanceInfo = function() return W_ZONE.instanceName, W_ZONE.instanceType, 1, "Normal", 5, 0, false, 1, 5 end else GetInstanceInfo = nil end end
-- walk into / out of a dungeon: sets the zone texts and fires the event the client fires
function EnterDungeon(zoneText, sub, itype) W_ZONE.real = zoneText; W_ZONE.sub = sub or zoneText; W_ZONE.instanceType = itype or "party"; W_ZONE.instanceName = zoneText; FireEvent("ZONE_CHANGED_NEW_AREA") end
function LeaveDungeon(world) W_ZONE.real = world or "Feralas"; W_ZONE.sub = "Dire Maul"; W_ZONE.instanceType = "none"; W_ZONE.instanceName = W_ZONE.real; FireEvent("ZONE_CHANGED_NEW_AREA") end
INSTANCE_RESET_SUCCESS = "%s has been reset."
INSTANCE_RESET_FAILED = "Cannot reset %s.  There are players still inside the instance."
RESET_CALLS = 0
function ResetInstances() RESET_CALLS = RESET_CALLS + 1 end
function GetLocale() return "enUS" end
function IsAddOnLoaded() return nil end
function UnitFactionGroup() return W and W.faction or "Alliance" end
function MouseIsOver() return W.mouseOver end
function IsControlKeyDown() return W.ctrl end
function PlaySound() end
function IsShiftKeyDown() return nil end
for _, n in ipairs({ "UIDropDownMenu_Initialize", "UIDropDownMenu_SetWidth", "UIDropDownMenu_SetText", "UIDropDownMenu_AddButton", "CloseDropDownMenus", "ToggleDropDownMenu", "UIDropDownMenu_SetSelectedID", "UIDropDownMenu_JustifyText", "UIDropDownMenu_SetButtonWidth" }) do _G[n] = function() end end
function UIDropDownMenu_CreateInfo() return {} end

-- ------------------------------------------------ world map
W = { saved = {}, raidInfoMode = "event", requests = 0, cont = 2, zone = 1, mouseOver = nil }
local zones = { {}, {} }
local P = dofile(DIR .. "/MarkerData.lua") or ModernMapMarkers_Points
function BuildZoneLists()
  -- built after MarkerData has been loaded
  for c = 1, 2 do local t = {} for z in oldpairs(ModernMapMarkers_Points[c]) do t[#t + 1] = z end table.sort(t); zones[c] = t end
end
function GetMapContinents() return "Kalimdor", "Eastern Kingdoms" end
function GetMapZones(c) return unpack(zones[c] or {}) end
function GetCurrentMapContinent() return W.cont end
function GetCurrentMapZone() return W.zone end
WorldMapFrame = new("Frame", "WorldMapFrame", UIParent); WorldMapFrame._shown = false
WorldMapButton = new("Button", "WorldMapButton", WorldMapFrame)
WorldMapDetailFrame = new("Frame", "WorldMapDetailFrame", WorldMapFrame); WorldMapDetailFrame._w = 1002; WorldMapDetailFrame._h = 668
WorldMapTooltip = new("GameTooltip", "WorldMapTooltip", UIParent)
function WorldMapFrame_Update() W.blizzardUpdates = (W.blizzardUpdates or 0) + 1 end
function SetMapZoom(c, z) W.cont = c; W.zone = z or 0; WorldMapFrame_Update() end

-- saved instances / raid info
function GetNumSavedInstances() return #W.saved end
function GetSavedInstanceInfo(i) local s = W.saved[i]; if not s then return end
  local remaining = math.max(0, math.floor(s.expire - CLOCK)); return s.name, s.id or 1, remaining end
function RequestRaidInfo() W.requests = W.requests + 1; if W.raidInfoMode == "event" then W.pendingEvent = CLOCK + 0.5 end end
function AddSaved(name, seconds) W.saved[#W.saved + 1] = { name = name, expire = CLOCK + seconds } end

function LoadAddon()
  for _, f in ipairs({ "Localization.lua", "Locales/Locale_deDE.lua", "Locales/Locale_esES.lua", "Locales/Locale_ptBR.lua", "Locales/Locale_zhCN.lua", "MarkerData.lua", "ModernMapMarkers_UI.lua", "ModernMapMarkers.lua" }) do
    local chunk, err = loadfile(DIR .. "/" .. f); if not chunk then error("compile " .. f .. ": " .. tostring(err)) end
    if f == "ModernMapMarkers_UI.lua" then BuildZoneLists() end
    local ok, e = xpcall(chunk, function(m) return debug.traceback(tostring(m), 2) end); if not ok then logerr("load " .. f, e) end
  end
end
function FireEvent(ev, a1, a2) _G.event = ev
  for _, f in ipairs(ALL) do if f._events[ev] and f._scripts.OnEvent then runHook(f, "OnEvent", a1, a2) end end end
function Tick(dt, n)
  n = n or 1
  for _ = 1, n do
    CLOCK = CLOCK + dt
    if W.pendingEvent and CLOCK >= W.pendingEvent then W.pendingEvent = nil; FireEvent("UPDATE_INSTANCE_INFO") end
    for _, f in ipairs(ALL) do if f._scripts.OnUpdate and f._shown then runHook(f, "OnUpdate", dt) end end
  end
end
function OpenMap(contName, zoneName)
  local c = (contName == "Kalimdor") and 1 or 2
  local idx; for i, z in ipairs(zones[c]) do if z == zoneName then idx = i end end
  assert(idx, "zone not found: " .. tostring(zoneName))
  W.cont, W.zone = c, idx
  WorldMapFrame:Show(); WorldMapFrame_Update()
end
function CloseMap() WorldMapFrame:Hide() end
function Markers()
  local out = {}
  for _, o in ipairs(ALL) do if o._kind == "Button" and o.name and o._shown and o.markerType then out[#out + 1] = o end end
  return out
end
function Marker(name) for _, m in ipairs(Markers()) do if m.name == name then return m end end end
function Hover(m) W.mouseOver = m; runHook(m, "OnEnter") end
function Unhover(m) W.mouseOver = nil; runHook(m, "OnLeave") end
function Tooltip() local t = {}; for _, l in ipairs(WorldMapTooltip._lines) do t[#t + 1] = l end return t end
function IsGrey(m) local v = m.texture._vertex; return (v[1] < 0.99 or v[2] < 0.99 or v[3] < 0.99) or m.texture._desat == true end

-- minimal InstanceJournal: entrance pins in a POI submap (here: Burning Steppes)
function InstallIJ()
  IJDB = { POI = { { MapContinentId = 2, MapZoneId = 0 } }, DG = {}, R = {} }
  IJLib = { InstanceType = { Raid = "raid", Dungeon = "dungeon" } }
  IJ_CreatedMapInstanceEntrance = {}
  IJ_InstanceJournalFrame = new("Frame", "IJ_InstanceJournalFrame", UIParent)
  function IJ_ShowInstanceEntrancesIcon(instance)
    local clean = string.gsub(instance.Name or "", "%s+", "")
    local pin = new("Button", "IJ_EntrancePin_" .. clean, WorldMapButton)
    pin.icon = pin:CreateTexture(nil); pin.icon:SetTexture("Interface\\IJ\\default")
    pin._scripts.OnEnter = function() WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT"); WorldMapTooltip:AddLine(instance.Name, 1, 1, 1) end
    pin._scripts.OnLeave = function() WorldMapTooltip:Hide() end
    IJ_CreatedMapInstanceEntrance[#IJ_CreatedMapInstanceEntrance + 1] = pin
    return pin
  end
end
function IJPinFor(name) for _, p in ipairs(IJ_CreatedMapInstanceEntrance) do if p._name and p._name:find("IJ_EntrancePin_" .. string.gsub(name, "%s+", ""), 1, true) then return p end end end

local _G = _G or getfenv(0)
local MMM = CreateFrame("Frame", "ModernMapMarkersCore", UIParent)
MMM.markers = {}
MMM.Data = {}
MMM.ZoneMarkers = {}
MMM.FlatDropdownData = nil
MMM.ijInstalled = false

-- Localization shorthand
local L = ModernMapMarkers_Locale

-- Filter constants
local ALL_TYPES = { "DUNGEON", "RAID", "WORLDBOSS", "BOAT", "ZEPPELIN", "TRAM" }

-- InstanceJournal Integration
-- MMM markers to hide when IJ is installed (covered by IJ POI entrances)
local IJ_HIDDEN_MARKERS = {
    ["Blackrock Depths"]               = true,
    ["Lower Blackrock Spire"]          = true,
    ["Upper Blackrock Spire"]          = true,
    ["Blackwing Lair"]                 = true,
    ["Molten Core"]                     = true,
    ["Dire Maul - East"]               = true,
    ["Dire Maul - North"]              = true,
    ["Dire Maul - West"]               = true,
    ["Black Morass"]                    = true,
    ["The Deadmines"]                   = true,
    ["Temple of Ahn'Qiraj"]            = true,
    ["Ruins of Ahn'Qiraj"]             = true,
    ["Gnomeregan"]                      = true,
    ["Maraudon"]                        = true,
    ["Scarlet Monastery - Armory"]      = true,
    ["Scarlet Monastery - Cathedral"]   = true,
    ["Scarlet Monastery - Graveyard"]   = true,
    ["Scarlet Monastery - Library"]     = true,
    ["Uldaman - Main Entrance"]         = true,
    ["Uldaman - Back Entrance"]         = true,
    ["Wailing Caverns"]                 = true,
    ["Windhorn Canyon"]                  = true,
    ["Timbermaw Hold"]                   = true,
}

-- Map MMM marker names to IJ database keys for click behavior
-- { db = "DG" or "R", key = IJDB key }
local MMM_TO_IJ = {
    -- Dungeons
    ["Blackfathom Deeps"]                   = { db = "DG", key = "BFD" },
    ["Crescent Grove"]                      = { db = "DG", key = "CG" },
    ["Ragefire Chasm"]                      = { db = "DG", key = "RFC" },
    ["Razorfen Downs"]                      = { db = "DG", key = "RFD" },
    ["Razorfen Kraul"]                      = { db = "DG", key = "RFK" },
    ["Zul'Farrak"]                          = { db = "DG", key = "ZF" },
    ["Shadowfang Keep"]                     = { db = "DG", key = "SFK" },
    ["The Stockade"]                        = { db = "DG", key = "STOCKADES" },
    ["Stormwind Vault"]                     = { db = "DG", key = "SV" },
    ["Stormwind Vault - Horde Entrance"]    = { db = "DG", key = "SV" },
    ["Stratholme"]                          = { db = "DG", key = "STRAT" },
    ["Stratholme - Back Gate"]              = { db = "DG", key = "STRAT" },
    ["Scholomance"]                         = { db = "DG", key = "SCHOLO" },
    ["The Sunken Temple"]                   = { db = "DG", key = "ST" },
    ["Hateforge Quarry"]                    = { db = "DG", key = "HQ" },
    ["Dragonmaw Retreat"]                   = { db = "DG", key = "DMR" },
    ["Karazhan Crypt"]                      = { db = "DG", key = "KC" },
    ["Lower Blackrock Spire"]              = { db = "DG", key = "LBRS" },
    ["Upper Blackrock Spire"]              = { db = "DG", key = "UBRS" },
    ["Gilneas City"]                        = { db = "DG", key = "GC" },
    ["Stormwrought Ruins"]                  = { db = "DG", key = "SWR" },
    ["Stormwrought Ruins - Back Entrance"]  = { db = "DG", key = "SWR" },
    ["Frostmane Hollow"]                    = { db = "DG", key = "FH" },
    ["Windhorn Canyon"]                     = { db = "DG", key = "WHC" },
    -- Raids
    ["Onyxia's Lair"]                       = { db = "R", key = "ONY" },
    ["Emerald Sanctum"]                     = { db = "R", key = "ES" },
    ["Lower Karazhan Halls"]                = { db = "R", key = "KARA10" },
    ["Blackwing Lair"]                      = { db = "R", key = "BWL" },
    ["Tower of Karazhan"]                   = { db = "R", key = "KARA40" },
    ["Naxxramas"]                           = { db = "R", key = "NAXX" },
    ["Zul'Gurub"]                           = { db = "R", key = "ZG" },
    ["Timbermaw Hold"]                      = { db = "R", key = "TH" },
}

-- Keep POI submap zone markers
local IJ_SUBMAP_ZONES = {}

-- Default filters
MMM.filters = {
    DUNGEON   = true,
    RAID      = true,
    BOAT      = true,
    ZEPPELIN  = true,
    TRAM      = true,
    WORLDBOSS = true,
    FACTION   = "ALL"
}

-- Dirty-check state for RefreshMarkers
local lastContinent = nil
local lastZone      = nil
local forceRefresh  = false

-- Textures
local TEX_BASE = "Interface\\AddOns\\ModernMapMarkers\\Textures\\"
local TEXTURE_MAP = {
    DUNGEON   = TEX_BASE .. "dungeon.tga",
    RAID      = TEX_BASE .. "raid.tga",
    BOAT      = TEX_BASE .. "boat.tga",
    ZEPPELIN  = TEX_BASE .. "zepp.tga",
    TRAM      = TEX_BASE .. "tram.tga",
    WORLDBOSS = TEX_BASE .. "worldboss.tga",
}
local HIGHLIGHT_MAP = {
    DUNGEON   = TEX_BASE .. "dungeon-highlight.tga",
    RAID      = TEX_BASE .. "raid-highlight.tga",
}

-- Zone name cache
local ZONE_CACHE = {}
function MMM:CacheZones()
    ZONE_CACHE[1] = { GetMapZones(1) } -- Kalimdor
    ZONE_CACHE[2] = { GetMapZones(2) } -- Eastern Kingdoms
end

-- ---------------------------------------------------------------------------
-- Helpers (Lua 5.0 safe: no #, no %, no varargs)
-- ---------------------------------------------------------------------------
local function Msg(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7fModernMapMarkers:|r " .. text)
    end
end

-- Localized UI string (falls back to the English key when untranslated)
local function T(key)
    return L:GetLocalizedMarkerName(key)
end

-- "Dire Maul - East" -> "Dire Maul"
local function BaseName(name)
    name = name or ""
    local i = string.find(name, " %- ")
    if i then return string.sub(name, 1, i - 1) end
    return name
end

local function FormatDuration(sec)
    sec = math.floor(sec)
    local d = math.floor(sec / 86400)
    local h = math.floor((sec - d * 86400) / 3600)
    local m = math.floor((sec - d * 86400 - h * 3600) / 60)
    if d > 0 then return d .. "d " .. h .. "h" end
    if h > 0 then return h .. "h " .. m .. "m" end
    return m .. "m"
end

local function VecXY(v)
    if type(v) ~= "table" then return nil, nil end
    if v.GetXY then return v:GetXY() end
    return v.x, v.y
end

-- ---------------------------------------------------------------------------
-- ClassicAPI (C_Map) integration. Everything is feature-detected and wrapped
-- in pcall, so the addon behaves exactly as before without the client mod.
-- ---------------------------------------------------------------------------
local function HasMapAPI()
    return type(C_Map) == "table" and type(C_Map.GetMapChildrenInfo) == "function"
end

local function HasWaypointAPI()
    return type(C_Map) == "table" and type(C_Map.SetUserWaypoint) == "function"
       and type(C_Map.GetUserWaypointPositionForMap) == "function"
       and type(UiMapPoint) == "table" and type(UiMapPoint.CreateFromCoordinates) == "function"
end

local function SafeChildren(id)
    local ok, res = pcall(C_Map.GetMapChildrenInfo, id)
    if ok and type(res) == "table" then return res end
    return {}
end

-- uiMapIDs: zones use their positive AreaTable id, continents are negative
-- (Kalimdor -13, Eastern Kingdoms -14). Resolved by localized name so it works
-- on every locale; falls back to the documented continent ids.
function MMM:BuildMapIDs()
    if self.mapIDsBuilt then return end
    self.contMapID = {}
    self.zoneMapID = { {}, {} }
    if not HasMapAPI() then return end

    local worldID = type(C_Map.GetFallbackWorldMapID) == "function" and C_Map.GetFallbackWorldMapID()
    if worldID and worldID ~= 0 then
        local conts = { GetMapContinents() }
        for _, kid in ipairs(SafeChildren(worldID)) do
            for i, cname in ipairs(conts) do
                if kid.name == cname then self.contMapID[i] = kid.mapID end
            end
        end
    end
    if not self.contMapID[1] then self.contMapID[1] = -13 end
    if not self.contMapID[2] then self.contMapID[2] = -14 end

    for i = 1, 2 do
        local byName = {}
        for _, kid in ipairs(SafeChildren(self.contMapID[i])) do
            if kid.name and kid.mapID then byName[kid.name] = kid.mapID end
        end
        self.zoneMapID[i] = byName
    end
    -- Only remember the result once the zone lists were really filled,
    -- so an early (empty) call is retried later instead of cached forever.
    local filled = false
    for _ in pairs(self.zoneMapID[1]) do filled = true end
    if filled then self.mapIDsBuilt = true end
end

-- uiMapID of the map currently shown in the world map frame (nil if unknown)
function MMM:GetViewedMapID()
    self:BuildMapIDs()
    local cont = GetCurrentMapContinent()
    local zone = GetCurrentMapZone()
    if not cont or cont <= 0 then return nil end
    if zone == 0 then return self.contMapID[cont] end
    local zones = ZONE_CACHE[cont]
    local name = zones and zones[zone]
    local byName = self.zoneMapID[cont]
    return name and byName and byName[name] or nil
end

function MMM:GetMapIDForZone(contID, englishZone)
    self:BuildMapIDs()
    local byName = self.zoneMapID[contID]
    if not byName then return nil end
    return byName[L:GetLocalizedZoneName(englishZone)] or byName[englishZone]
end

-- Straight-line distance (yards) from the player to a point on a zone map.
-- Returns nil when the player is not inside that zone (GetPlayerMapPosition
-- returns nil there) or the API is unavailable.
local function ComputeDistance(mapID, x, y)
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py = VecXY(pos)
    if not px or not py then return nil end
    local w, h = C_Map.GetMapWorldSize(mapID)
    if not w or not h or w <= 0 or h <= 0 then return nil end
    local dx = (x - px) * w
    local dy = (y - py) * h
    return math.sqrt(dx * dx + dy * dy)
end

function MMM:GetDistanceYards(mapID, x, y)
    if not mapID or mapID <= 0 or not x or not y then return nil end
    if type(C_Map) ~= "table" or type(C_Map.GetPlayerMapPosition) ~= "function"
       or type(C_Map.GetMapWorldSize) ~= "function" then
        return nil
    end
    local ok, d = pcall(ComputeDistance, mapID, x, y)
    if ok then return d end
    return nil
end

-- ---------------------------------------------------------------------------
-- Waypoint (C_Map user waypoint) - Ctrl+Left-click a marker to set it
-- ---------------------------------------------------------------------------
function MMM:SetWaypointToMarker(marker)
    if not HasWaypointAPI() or not marker.posX then return false end
    local id = self:GetMapIDForZone(marker.continent, marker.zoneName)
    if not id then return false end
    if type(C_Map.CanSetUserWaypointOnMap) == "function" then
        local okCan, can = pcall(C_Map.CanSetUserWaypointOnMap, id)
        if okCan and can == false then return false end
    end
    local okPt, pt = pcall(UiMapPoint.CreateFromCoordinates, id, marker.posX, marker.posY)
    if not okPt or not pt then return false end
    local ok, res = pcall(C_Map.SetUserWaypoint, pt)
    if ok and res ~= false then
        Msg(T("Waypoint set:") .. " " .. (marker.name or ""))
        return true
    end
    return false
end

function MMM:ClearWaypoint()
    if type(C_Map) == "table" and type(C_Map.ClearUserWaypoint) == "function" then
        pcall(C_Map.ClearUserWaypoint)
    end
end

-- Tooltip that refreshes twice a second while hovered (live distance)
local function HookTooltip(frame, showFn)
    frame:SetScript("OnEnter", function()
        local f = this
        f.tipElapsed = 0
        showFn(f)
        if type(C_Map) ~= "table" or not C_Map.GetPlayerMapPosition then return end
        f:SetScript("OnUpdate", function()
            if not MouseIsOver(this) then
                this:SetScript("OnUpdate", nil)
                return
            end
            this.tipElapsed = this.tipElapsed + arg1
            if this.tipElapsed >= 0.5 then
                this.tipElapsed = 0
                showFn(this)
            end
        end)
    end)
    frame:SetScript("OnLeave", function()
        this:SetScript("OnUpdate", nil)
        WorldMapTooltip:Hide()
    end)
end

function MMM:ShowPinTooltip(pin)
    WorldMapTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    WorldMapTooltip:AddLine(T("Waypoint"), 1, 0.82, 0)
    if type(C_Map.GetUserWaypoint) == "function" then
        local ok, point = pcall(C_Map.GetUserWaypoint)
        if ok and point then
            local x, y = VecXY(point.position)
            local d = self:GetDistanceYards(point.uiMapID, x, y)
            if d then
                WorldMapTooltip:AddLine("~" .. math.floor(d + 0.5) .. " " .. T("yd away"), 0.6, 0.9, 0.6)
            end
        end
    end
    WorldMapTooltip:AddLine(T("Right-Click: Clear Waypoint"), 0.5, 0.5, 0.5)
    WorldMapTooltip:Show()
end

function MMM:GetPin()
    if self.pin then return self.pin end
    local pin = CreateFrame("Button", "ModernMapMarkersWaypointPin", WorldMapButton)
    pin:SetWidth(26)
    pin:SetHeight(26)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 8)

    local tex = pin:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(pin)
    tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    tex:SetTexCoord(0.5, 0.75, 0.25, 0.5) -- the "Cross" raid icon
    pin.texture = tex

    pin:RegisterForClicks("RightButtonUp")
    pin:SetScript("OnClick", function() MMM:ClearWaypoint() end)
    HookTooltip(pin, function(f) MMM:ShowPinTooltip(f) end)

    pin:Hide()
    self.pin = pin
    return pin
end

-- Draw / hide the waypoint pin for the currently viewed map
function MMM:UpdateWaypointPin()
    if not HasWaypointAPI() or not WorldMapFrame:IsVisible() then
        if self.pin then self.pin:Hide() end
        return
    end

    local x, y
    local viewID = self:GetViewedMapID()
    local has = true
    if type(C_Map.HasUserWaypoint) == "function" then
        local okH, h = pcall(C_Map.HasUserWaypoint)
        has = okH and h
    end
    if viewID and has then
        local ok, p = pcall(C_Map.GetUserWaypointPositionForMap, viewID)
        if ok and p then x, y = VecXY(p) end
    end

    if not x or not y then
        if self.pin then self.pin:Hide() end
        return
    end

    local pin = self:GetPin()
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT",
        x * WorldMapDetailFrame:GetWidth(), -y * WorldMapDetailFrame:GetHeight())
    pin:Show()
end

-- ---------------------------------------------------------------------------
-- Instance lockouts (stock 1.12 API - no client mod needed)
--
-- The client only knows your saved instances once the server has answered RequestRaidInfo(), and the
-- UPDATE_INSTANCE_INFO event is not something to depend on alone. So the list is read again whenever it
-- can matter: when the map opens, when the event arrives, on a timer while the map is open (this also
-- notices a lockout expiring), after zoning and a few seconds after login.
-- ---------------------------------------------------------------------------
local lockouts = {}              -- normalised instance name -> { raw, reset (s), t (GetTime at first sight), name }
local lockoutSignature = ""
local LOCKOUT_REQUEST_EVERY = 30 -- seconds between RequestRaidInfo() calls
local LOCKOUT_RESCAN_EVERY  = 20 -- seconds between re-reads while the map is open

-- "The Deadmines" / "Deadmines" / "dire maul" -> one comparable key (keeps UTF-8 bytes of other locales)
local function NormName(name)
    local n = string.lower(name or "")
    n = string.gsub(n, "^the ", "")
    n = string.gsub(n, "[%s%p]", "")
    if n == "" then n = string.lower(name or "") end
    return n
end

-- other names the game may use for the same instance (keys and values are NormName results)
local LOCKOUT_ALIASES = {
    towerofkarazhan     = { "upperkarazhanhalls" },
    lowerkarazhanhalls  = { "karazhanlower" },
    stockade            = { "stormwindstockade" },
    ruinsofahnqiraj     = { "ahnqirajruins", "aq20" },
    templeofahnqiraj    = { "ahnqirajtemple", "aq40" },
    onyxiaslair         = { "onyxia" },
}

function MMM:ScanLockouts()
    if type(GetNumSavedInstances) ~= "function" or type(GetSavedInstanceInfo) ~= "function" then return false end
    local now = GetTime()
    local new = {}
    local keys = {}
    for i = 1, (GetNumSavedInstances() or 0) do
        local name, id, reset = GetSavedInstanceInfo(i)
        if name then
            local key = NormName(name)
            local raw = tonumber(reset) or 0
            local old = lockouts[key]
            -- some clients report a fixed number, others a live countdown: keep counting from the first sighting
            local t = now
            if old and old.raw == raw then t = old.t end
            if raw - (now - t) > 0 then
                new[key] = { raw = raw, reset = raw, t = t, name = name }
                table.insert(keys, key .. ":" .. math.floor((t + raw) / 10))
            end
        end
    end
    table.sort(keys)
    local sig = table.concat(keys, "|")
    lockouts = new
    local changed = (sig ~= lockoutSignature)
    lockoutSignature = sig
    return changed
end

-- Seconds until the lockout for this marker/instance name resets, or nil when not saved
function MMM:GetLockout(nameEN)
    local base = BaseName(nameEN)
    local rec = lockouts[NormName(L:GetLocalizedMarkerName(base))] or lockouts[NormName(base)]
    if not rec then
        local alts = LOCKOUT_ALIASES[NormName(base)]
        if alts then
            for i = 1, table.getn(alts) do
                rec = lockouts[alts[i]]
                if rec then break end
            end
        end
    end
    if not rec then return nil end
    local remaining = rec.reset - (GetTime() - rec.t)
    if remaining <= 0 then return nil end
    return remaining
end

-- ask the server for fresh data (throttled unless forced)
function MMM:RequestLockouts(force)
    if type(RequestRaidInfo) ~= "function" then return end
    local now = GetTime()
    if (not force) and self.lastRaidInfoRequest and (now - self.lastRaidInfoRequest) < LOCKOUT_REQUEST_EVERY then return end
    self.lastRaidInfoRequest = now
    RequestRaidInfo()
end

-- saved raids AND remembered dungeons: read/expire both, report whether anything changed
function MMM:ScanAll()
    local changed = self:ScanLockouts()
    if self.PruneDungeons and self:PruneDungeons() then changed = true end
    return changed
end

-- re-read and redraw when something changed (or when forced)
function MMM:UpdateLockouts(force)
    local changed = self:ScanAll()
    if changed or force then
        self:InvalidateCache()
        self:RefreshMarkers()
    end
    return changed
end

-- dimmed + desaturated icon for a saved instance (works on clients without desaturation too)
function MMM:ApplyLockoutVisual(tex, locked)
    if locked then
        tex:SetVertexColor(0.6, 0.6, 0.6)
        if tex.SetDesaturated then tex:SetDesaturated(1) end
    else
        tex:SetVertexColor(1, 1, 1)
        if tex.SetDesaturated then tex:SetDesaturated(nil) end
    end
end

-- while the world map is open: re-read every so often (new lockout, expiry), and stop when it closes
function MMM:StartLockoutTimer()
    self.lockoutElapsed = 0
    self:SetScript("OnUpdate", function()
        if not WorldMapFrame:IsVisible() then
            MMM.mapOpen = false
            this:SetScript("OnUpdate", nil)
            return
        end
        MMM.lockoutElapsed = (MMM.lockoutElapsed or 0) + arg1
        if MMM.lockoutElapsed >= LOCKOUT_RESCAN_EVERY then
            MMM.lockoutElapsed = 0
            MMM:RequestLockouts(false)
            MMM:UpdateLockouts(false)
        end
    end)
end

-- called from the world map update hook: when the map opens, and again on every later update (zone
-- change etc.), read the saved instances so a zone change or a re-open always shows current lockouts.
-- The read is a loop over a handful of entries.
function MMM:OnMapUpdate()
    if not WorldMapFrame:IsVisible() then return end
    local now = GetTime()
    if not self.mapOpen then
        self.mapOpen = true
        self:RequestLockouts(false)
        self.lastMapScan = now
        if self:ScanAll() then self:InvalidateCache() end
        self:StartLockoutTimer()
    elseif now ~= self.lastMapScan then   -- more than once per frame would be pointless
        self.lastMapScan = now
        if self:ScanAll() then self:InvalidateCache() end
    end
end

-- a few delayed asks after login / zoning, because the answer is not there yet at that moment
function MMM:ScheduleLockoutRequests()
    self.retryAt = { GetTime() + 6, GetTime() + 25 }
    if not self.retryFrame then self.retryFrame = CreateFrame("Frame") end
    self.retryFrame:SetScript("OnUpdate", function()
        local now = GetTime()
        local list = MMM.retryAt
        if not list or table.getn(list) == 0 then
            this:SetScript("OnUpdate", nil)
            return
        end
        if now >= list[1] then
            table.remove(list, 1)
            MMM:RequestLockouts(true)
        end
    end)
end


-- ---------------------------------------------------------------------------
-- Active dungeon instances
--
-- 5-man dungeons are not saved lockouts, so Raid Info never lists them. What a dungeon has is a live
-- instance you stay attached to until it is reset (ResetInstances(), the party leader, or the server).
-- This remembers the dungeons you have entered, greys their icons while they are active, and forgets
-- them when the game says "<name> has been reset." or after a manual reset. Remembered per character.
-- ---------------------------------------------------------------------------
local DUNGEON_IDLE_RESET = 3600  -- ASSUMPTION: an instance nobody is inside resets about an hour later
local RESET_WINDOW = 3           -- seconds after ResetInstances() in which the game's replies are collected

local function FormatToPattern(fmt)
    fmt = string.gsub(fmt, "%%s", "\1")
    fmt = string.gsub(fmt, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    fmt = string.gsub(fmt, "\1", "(.+)")
    return "^" .. fmt .. "$"
end
local RESET_OK_PATTERN   = FormatToPattern(INSTANCE_RESET_SUCCESS or "%s has been reset.")
-- the failure text continues after the name ("... There are players still inside the instance.")
local RESET_FAIL_PREFIX  = string.gsub(INSTANCE_RESET_FAILED or "Cannot reset %s.", "%%s.*$", "")

function MMM:DungeonTrackingEnabled()
    return not (ModernMapMarkersDB and ModernMapMarkersDB.trackDungeons == false)
end

function MMM:DungeonStore()
    -- on a first run the saved-variables table does not exist yet (it is normally created at logout)
    if not ModernMapMarkersDB then ModernMapMarkersDB = {} end
    ModernMapMarkersDB.instances = ModernMapMarkersDB.instances or {}
    local key = (UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "?")
    ModernMapMarkersDB.instances[key] = ModernMapMarkersDB.instances[key] or {}
    return ModernMapMarkersDB.instances[key]
end

-- normalised dungeon base names known from the marker data ("Dire Maul - East" -> "diremaul")
function MMM:DungeonBases()
    if self.dungeonBases then return self.dungeonBases end
    self:BuildData()
    local t, any = {}, false
    for _, d in pairs(self.Data or {}) do
        if d.type == "DUNGEON" then
            local b = BaseName(d.name)
            t[NormName(b)] = b
            t[NormName(L:GetLocalizedMarkerName(b))] = b
            any = true
        end
    end
    if any then self.dungeonBases = t end
    return t
end

-- which known dungeon does this zone/instance text name? (exact, then the longest known name it starts with)
function MMM:MatchDungeon(text)
    if not text or text == "" then return nil end
    local n = NormName(text)
    local bases = self:DungeonBases()
    if bases[n] then return bases[n] end
    local best, bestLen = nil, 0
    for key, b in pairs(bases) do
        local len = string.len(key)
        if len >= 5 and len > bestLen and string.sub(n, 1, len) == key then best, bestLen = b, len end
    end
    return best
end

local function ForgetExpired(store)
    local changed = false
    local now = time()
    for key, rec in pairs(store) do
        if rec.left and (now - rec.left) >= DUNGEON_IDLE_RESET then store[key] = nil; changed = true end
    end
    return changed
end

-- known dungeons whose name merely CONTAINS this text (an instance shared by several markers,
-- e.g. "Blackrock Spire" for the Lower and Upper halves)
function MMM:DungeonCandidates(text)
    local out = {}
    local n = NormName(text)
    if string.len(n) < 8 then return out end
    local seen = {}
    for key, b in pairs(self:DungeonBases()) do
        if string.find(key, n, 1, true) and not seen[b] then
            seen[b] = true
            table.insert(out, b)
        end
    end
    return out
end

-- zone/instance text (+ sub-zone as tiebreaker) -> the dungeon it names, or nil
function MMM:ResolveDungeon(text, sub)
    local base = self:MatchDungeon(text)
    local subBase = (sub and sub ~= "") and self:MatchDungeon(sub) or nil
    if base then
        -- the sub-zone names the exact wing when it extends the zone name
        if subBase and string.find(NormName(subBase), NormName(base), 1, true) then base = subBase end
        return base
    end
    local cands = self:DungeonCandidates(text)
    if table.getn(cands) == 1 then return cands[1] end
    if table.getn(cands) > 1 and subBase then
        for i = 1, table.getn(cands) do
            if cands[i] == subBase then return subBase end
        end
    end
    return nil
end

-- drop remembered dungeons that have been empty for the idle period; true when something was dropped
function MMM:PruneDungeons()
    if not self:DungeonTrackingEnabled() then return false end
    local store = self:DungeonStore()
    return (store and ForgetExpired(store)) and true or false
end

-- is the character inside a dungeon right now? (called after zoning)
function MMM:CheckInstanceZone()
    if not self:DungeonTrackingEnabled() then return end
    local store = self:DungeonStore()
    if not store then return end
    local base = nil
    local sub = (type(GetSubZoneText) == "function") and GetSubZoneText() or nil
    local certain = false
    if type(GetInstanceInfo) == "function" then
        -- ClassicAPI: "party" = 5-man dungeon, "none" = open world (so a sub-zone named like the dungeon is not enough)
        local name, itype = GetInstanceInfo()
        if itype == "party" then
            base = self:ResolveDungeon(name, sub); certain = true
        elseif itype == "none" or itype == "raid" or itype == "pvp" then
            certain = true
        end
    end
    if (not certain) and type(GetRealZoneText) == "function" then
        -- stock client: inside an instance GetRealZoneText() is the instance name, outside it is the world zone
        base = self:ResolveDungeon(GetRealZoneText(), sub)
    end
    local changed = false
    local prev = self.currentDungeon
    if base then
        local key = NormName(base)
        local rec = store[key]
        if not rec then
            store[key] = { name = base, entered = time() }
            changed = true
        elseif rec.left then
            rec.left = nil
            changed = true
        end
        if prev and prev ~= key and store[prev] and not store[prev].left then
            store[prev].left = time()   -- moved straight from one dungeon to another
            changed = true
        end
        self.currentDungeon = key
    else
        if prev and store[prev] and not store[prev].left then
            store[prev].left = time()
            changed = true
        end
        self.currentDungeon = nil
    end
    if ForgetExpired(store) then changed = true end
    if changed then self:InvalidateCache(); self:RefreshMarkers() end
end

-- the record for an active dungeon (nil when not active)
function MMM:GetActiveDungeon(nameEN)
    if not self:DungeonTrackingEnabled() then return nil end
    local store = self:DungeonStore()
    if not store then return nil end
    local rec = store[NormName(BaseName(nameEN))]
    if not rec then return nil end
    if rec.left and (time() - rec.left) >= DUNGEON_IDLE_RESET then return nil end
    return rec
end

function MMM:ForgetDungeon(key)
    local store = self:DungeonStore()
    if store and store[key] and key ~= self.currentDungeon then
        store[key] = nil
        return true
    end
    return false
end

-- "<name> has been reset." / "Cannot reset <name>. ..." from the game
function MMM:OnResetMessage(msg)
    if not msg then return end
    local _, _, okName = string.find(msg, RESET_OK_PATTERN)
    if okName then
        self.resetSuccesses = (self.resetSuccesses or 0) + 1
        local base = self:MatchDungeon(okName)
        if base and self:ForgetDungeon(NormName(base)) then
            self:InvalidateCache(); self:RefreshMarkers()
        end
        return
    end
    if RESET_FAIL_PREFIX ~= "" and string.sub(msg, 1, string.len(RESET_FAIL_PREFIX)) == RESET_FAIL_PREFIX then
        local rest = string.sub(msg, string.len(RESET_FAIL_PREFIX) + 1)
        local base = self:MatchDungeon(rest)
        if base then
            self.resetFailed = self.resetFailed or {}
            self.resetFailed[NormName(base)] = true
        end
    end
end

-- ResetInstances() was called: collect the replies for a moment, then clear every dungeon the game did
-- not refuse to reset (its names do not always match the map names, so the count of replies is what counts)
function MMM:OnResetInstances()
    self.resetSuccesses = 0
    self.resetFailed = {}
    if not self.resetFrame then self.resetFrame = CreateFrame("Frame") end
    local deadline = GetTime() + RESET_WINDOW
    self.resetFrame:SetScript("OnUpdate", function()
        if GetTime() < deadline then return end
        this:SetScript("OnUpdate", nil)
        local store = MMM:DungeonStore()
        local changed = false
        if store and (MMM.resetSuccesses or 0) > 0 then
            for key in pairs(store) do
                if key ~= MMM.currentDungeon and not (MMM.resetFailed and MMM.resetFailed[key]) then
                    store[key] = nil
                    changed = true
                end
            end
        end
        if changed then MMM:InvalidateCache(); MMM:RefreshMarkers() end
    end)
end

function MMM:HookResetInstances()
    if self.resetHooked or type(ResetInstances) ~= "function" then return end
    self.resetHooked = true
    local original = ResetInstances
    ResetInstances = function()
        MMM:OnResetInstances()
        return original()
    end
end

-- ---------------------------------------------------------------------------
-- "Find Marker" highlight: pulse the found marker for a few seconds
-- ---------------------------------------------------------------------------
function MMM:StartHighlight(baseName)
    self.highlightBase  = baseName
    self.highlightUntil = GetTime() + 8
    if not self.pulse then self.pulse = CreateFrame("Frame") end
    self.pulse:SetScript("OnUpdate", function()
        local now = GetTime()
        if not MMM.highlightBase or now >= MMM.highlightUntil then
            MMM.highlightBase = nil
            for i = 1, table.getn(MMM.markers) do
                MMM.markers[i].glow:Hide()
                MMM.markers[i].glowOn = false
            end
            this:SetScript("OnUpdate", nil)
            return
        end
        local a = 0.55 + 0.45 * math.sin(now * 7)
        for i = 1, table.getn(MMM.markers) do
            if MMM.markers[i].glowOn then MMM.markers[i].glow:SetAlpha(a) end
        end
    end)
end

-- Map multi-entrance dungeons to a single zone
local CANONICAL_ZONE = {
    ["Blackrock Depths"]      = "Burning Steppes",
    ["Lower Blackrock Spire"] = "Burning Steppes",
    ["Upper Blackrock Spire"] = "Burning Steppes",
    ["Blackwing Lair"]        = "Burning Steppes",
    ["Molten Core"]           = "Burning Steppes",
    ["Stormwind Vault"]       = "Stormwind City",
    ["Timbermaw Hold"]        = "Azshara",
}

-- Data Parsing
function MMM:BuildData()
    if self.dataBuilt then return end
    if not ModernMapMarkers_Points then return end

    MMM.Data = {}
    MMM.ZoneMarkers = {}

    local index = 1

    for contID, zones in pairs(ModernMapMarkers_Points) do
        MMM.ZoneMarkers[contID] = MMM.ZoneMarkers[contID] or {}

        for zoneName, markers in pairs(zones) do
            MMM.ZoneMarkers[contID][zoneName] = {}

            for _, m in ipairs(markers) do
                local typeUpper = string.upper(m.type or "UNKNOWN")
                if typeUpper == "ZEPP" then typeUpper = "ZEPPELIN" end

                local markerData = {
                    continent   = contID,
                    zoneName    = zoneName,
                    x           = m.x,
                    y           = m.y,
                    name        = m.name,
                    type        = typeUpper,
                    description = m.info,
                    id          = index
                }

                table.insert(MMM.Data, markerData)
                table.insert(MMM.ZoneMarkers[contID][zoneName], markerData)

                index = index + 1
            end
        end
    end
    self.dataBuilt = true
end

-- Get deduplicated data for dropdowns
function ModernMapMarkers_GetFlatData()
    MMM:BuildData()

    if MMM.FlatDropdownData then return MMM.FlatDropdownData end

    local filteredData = {}
    local seenNames = {}

    for _, data in ipairs(MMM.Data) do
        if data.type == "DUNGEON" or data.type == "RAID" or data.type == "WORLDBOSS" then
            local baseName = data.name or ""

            local dashIndex = string.find(baseName, " %- ")
            if dashIndex then
                baseName = string.sub(baseName, 1, dashIndex - 1)
            end

            local existingIndex = seenNames[baseName]
            if not existingIndex then
                local dropData = {}
                for k, v in pairs(data) do dropData[k] = v end
                dropData.name = baseName
                table.insert(filteredData, dropData)
                seenNames[baseName] = table.getn(filteredData)
            else
                local canon = CANONICAL_ZONE[baseName]
                if canon and data.zoneName == canon then
                    local dropData = {}
                    for k, v in pairs(data) do dropData[k] = v end
                    dropData.name = baseName
                    filteredData[existingIndex] = dropData
                end
            end
        end
    end

    MMM.FlatDropdownData = filteredData
    return filteredData
end

-- Drawing Logic
function MMM:RefreshMarkers()
    if not WorldMapFrame:IsVisible() then return end
    self:RefreshMarkersInner()
    self:UpdateWaypointPin()
end

function MMM:RefreshMarkersInner()
    if not WorldMapFrame:IsVisible() then return end

    self:BuildData()

    local currentContinent = GetCurrentMapContinent()
    local currentZone      = GetCurrentMapZone()

    -- Dirty-check: skip full redraw if zone hasn't changed and no force refresh
    if not forceRefresh
       and currentContinent == lastContinent
       and currentZone == lastZone then
        return
    end

    lastContinent = currentContinent
    lastZone      = currentZone
    forceRefresh  = false

    if currentContinent == 0 or currentZone == 0 then
        self:HideAllMarkers()
        return
    end

    local zoneNames      = ZONE_CACHE[currentContinent]
    local currentZoneName = zoneNames and zoneNames[currentZone]
    if not currentZoneName then
        self:HideAllMarkers()
        return
    end

    -- Translate localized zone name to English key used in MarkerData
    local englishZoneName = L:GetEnglishZoneName(currentZoneName)

    local zoneMarkers = MMM.ZoneMarkers[currentContinent] and MMM.ZoneMarkers[currentContinent][englishZoneName]

    local markerIndex = 0
    local now = GetTime()

    if zoneMarkers then
        for _, data in ipairs(zoneMarkers) do

            local showMarker = (MMM.filters[data.type] == true)

            -- Hide markers replaced by InstanceJournal
            if showMarker and MMM.ijInstalled then
                if data.type == "WORLDBOSS" then
                    showMarker = false
                elseif IJ_HIDDEN_MARKERS[data.name] then
                    showMarker = false
                end
            end

            -- Check faction filter
            if showMarker and (data.type == "BOAT" or data.type == "ZEPPELIN" or data.type == "TRAM") then
                if MMM.filters.FACTION ~= "ALL"
                   and data.description ~= "Neutral"
                   and data.description ~= MMM.filters.FACTION then
                    showMarker = false
                end
            end

            if showMarker then
                markerIndex = markerIndex + 1
                local marker = self:GetOrCreateMarker(markerIndex)

                -- Sizing
                if data.type == "DUNGEON" or data.type == "RAID" or data.type == "WORLDBOSS" then
                    marker:SetWidth(32)
                    marker:SetHeight(32)
                else
                    marker:SetWidth(24)
                    marker:SetHeight(24)
                end

                -- Position
                local width  = WorldMapDetailFrame:GetWidth()
                local height = WorldMapDetailFrame:GetHeight()
                marker:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", data.x * width, -data.y * height)

                -- Texture
                local tex = TEXTURE_MAP[data.type] or "Interface\\Minimap\\POIIcons"
                if marker.lastTexture ~= tex then
                    marker.texture:SetTexture(tex)
                    marker.lastTexture = tex
                end

                local hlTex = HIGHLIGHT_MAP[data.type]
                if marker.lastHighlight ~= hlTex then
                    if hlTex then
                        marker:SetHighlightTexture(hlTex)
                    elseif marker.lastHighlight then
                        marker:SetHighlightTexture("")
                    end
                    marker.lastHighlight = hlTex
                end

                -- Metadata
                marker.name        = L:GetLocalizedMarkerName(data.name)
                marker.nameEN      = data.name
                marker.description = data.description
                marker.markerType  = data.type
                marker.continent   = data.continent
                marker.zoneName    = data.zoneName
                marker.posX        = data.x
                marker.posY        = data.y

                -- Dim dungeons/raids this character is already saved to
                local locked = (data.type == "DUNGEON" or data.type == "RAID") and MMM:GetLockout(data.name)
                if (not locked) and data.type == "DUNGEON" and MMM:GetActiveDungeon(data.name) then locked = true end
                MMM:ApplyLockoutVisual(marker.texture, locked)

                -- "Find Marker" pulse
                if MMM.highlightBase and now < MMM.highlightUntil and BaseName(data.name) == MMM.highlightBase then
                    marker.glow:Show()
                    marker.glowOn = true
                else
                    marker.glow:Hide()
                    marker.glowOn = false
                end

                marker:Show()
            end
        end
    end

    -- Hide any excess markers from the previous zone
    self:HideMarkersFrom(markerIndex + 1)
end

-- Hide all markers in the pool
function MMM:HideAllMarkers()
    self:HideMarkersFrom(1)
end

-- Hide markers from startIndex onwards
function MMM:HideMarkersFrom(startIndex)
    for i = startIndex, table.getn(self.markers) do
        if self.markers[i] then
            self.markers[i]:Hide()
        end
    end
end

-- Invalidate dirty-check so next RefreshMarkers does a full redraw
function MMM:InvalidateCache()
    forceRefresh = true
end

-- Get IJ instance from MMM marker English name
function MMM:GetIJInstance(nameEN)
    if not MMM.ijInstalled or not nameEN then return nil end
    local mapping = MMM_TO_IJ[nameEN]
    if not mapping then return nil end
    local dbTable = (mapping.db == "R") and IJDB.R or IJDB.DG
    if not dbTable then return nil end
    return dbTable[mapping.key]
end

-- InstanceJournal Integration
function MMM:OnMarkerClick(marker, button)
    -- Ctrl+Left-click: drop a waypoint on this marker (needs ClassicAPI)
    if button == "LeftButton" and IsControlKeyDown() then
        if MMM:SetWaypointToMarker(marker) then return end
    end

    if not MMM.ijInstalled then return end

    local instance = MMM:GetIJInstance(marker.nameEN)
    if not instance then return end

    if button == "RightButton" then
        -- Right-click: open IJ journal page
        if not IJ_InstanceJournalFrame:IsShown() then
            IJ_InstanceJournalFrame:Show()
        end
        if instance.Type == IJLib.InstanceType.Raid then
            IJ_ShowRaids = true
            PanelTemplates_SetTab(IJ_InstanceJournalFrame, 2)
        else
            IJ_ShowRaids = false
            PanelTemplates_SetTab(IJ_InstanceJournalFrame, 1)
        end
        IJ_ShowEncounter(instance)
        WorldMapFrame:Hide()
    else
        -- Left-click: navigate to instance submap
        SetMapZoom(tonumber(instance.MapId), 1)
    end
end

function MMM:ShowMarkerTooltip(m)
    WorldMapTooltip:SetOwner(m, "ANCHOR_RIGHT")
    WorldMapTooltip:AddLine(m.name, 1, 0.82, 0)

    local isInstance = (m.markerType == "DUNGEON" or m.markerType == "RAID" or m.markerType == "WORLDBOSS")
    if m.description then
        if isInstance then
            WorldMapTooltip:AddLine(T("Level") .. ": " .. m.description, 1, 1, 1, 1)
        elseif m.description == "Alliance" then
            WorldMapTooltip:AddLine(T("Alliance"), 0.0, 0.47, 1.0, 1)
        elseif m.description == "Horde" then
            WorldMapTooltip:AddLine(T("Horde"), 1.0, 0.0, 0.0, 1)
        else
            WorldMapTooltip:AddLine(T(m.description), 1, 1, 1, 1)
        end
    end

    -- Saved-instance lockout
    if m.markerType == "DUNGEON" or m.markerType == "RAID" then
        local remain = MMM:GetLockout(m.nameEN)
        if remain then
            WorldMapTooltip:AddLine(T("Saved") .. ": " .. FormatDuration(remain), 1, 0.4, 0.4)
        end
    end

    if m.markerType == "DUNGEON" and MMM:GetActiveDungeon(m.nameEN) then
        WorldMapTooltip:AddLine(T("Active instance"), 1, 0.4, 0.4)
    end

    -- Live distance (needs ClassicAPI C_Map; silently skipped otherwise)
    local id = MMM:GetMapIDForZone(m.continent, m.zoneName)
    local d = id and MMM:GetDistanceYards(id, m.posX, m.posY)
    if d then
        WorldMapTooltip:AddLine("~" .. math.floor(d + 0.5) .. " " .. T("yd away"), 0.6, 0.9, 0.6)
    end

    if MMM.ijInstalled and MMM:GetIJInstance(m.nameEN) then
        WorldMapTooltip:AddLine(T("Left-Click: View Map"), 0.5, 0.5, 0.5)
        WorldMapTooltip:AddLine(T("Right-Click: Instance Journal"), 0.5, 0.5, 0.5)
    end
    if HasWaypointAPI() then
        WorldMapTooltip:AddLine(T("Ctrl+Click: Set Waypoint"), 0.5, 0.5, 0.5)
    end

    WorldMapTooltip:Show()
end

-- Marker Pool
function MMM:GetOrCreateMarker(index)
    if not self.markers[index] then
        local marker = CreateFrame("Button", "ModernMapMarkerIcon"..index, WorldMapButton)
        marker:SetWidth(24)
        marker:SetHeight(24)
        marker:SetFrameLevel(WorldMapButton:GetFrameLevel() + 5)

        local tex = marker:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(marker)
        marker.texture = tex

        -- Pulse ring used by "Find Marker"
        local glow = marker:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        glow:SetBlendMode("ADD")
        glow:SetWidth(52)
        glow:SetHeight(52)
        glow:SetPoint("CENTER", marker, "CENTER", 0, 0)
        glow:Hide()
        marker.glow = glow

        marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        marker:SetScript("OnClick", function() MMM:OnMarkerClick(this, arg1) end)

        HookTooltip(marker, function(f) MMM:ShowMarkerTooltip(f) end)

        self.markers[index] = marker
    end
    return self.markers[index]
end

-- Hooks & API
function ModernMapMarkers_SetFilter(key, state)
    if key == "ALL" then
        for _, t in ipairs(ALL_TYPES) do
            MMM.filters[t] = state
        end
    else
        MMM.filters[key] = state
    end
    MMM:InvalidateCache()
    MMM:RefreshMarkers()
end

function ModernMapMarkers_SetFactionFilter(factionStr)
    MMM.filters.FACTION = factionStr
    MMM:InvalidateCache()
    MMM:RefreshMarkers()
end

function MMM:GetZoneIndex(continentID, zoneName)
    local zones = ZONE_CACHE[continentID] or {}
    -- zoneName is English (from MarkerData), ZONE_CACHE has localized names
    local localizedName = L:GetLocalizedZoneName(zoneName)
    for i, name in ipairs(zones) do
        if name == localizedName then return i end
    end
    -- Fallback: try direct match (for enUS or untranslated zones)
    for i, name in ipairs(zones) do
        if name == zoneName then return i end
    end
    return 0
end

function ModernMapMarkers_FindMarker(dataIndex)
    MMM:BuildData()
    local data = MMM.Data[dataIndex]
    if not data then return end

    local zoneIndex = MMM:GetZoneIndex(data.continent, data.zoneName)
    if zoneIndex > 0 then
        SetMapZoom(data.continent, zoneIndex)
    end

    if not MMM.filters[data.type] then
        MMM.filters[data.type] = true
        if ModernMapMarkers_SyncFilterUI then
            ModernMapMarkers_SyncFilterUI(data.type, true)
        end
    end

    MMM:StartHighlight(BaseName(data.name))
    MMM:InvalidateCache()
    MMM:RefreshMarkers()
end

local original_WorldMapFrame_Update = WorldMapFrame_Update
function WorldMapFrame_Update()
    if original_WorldMapFrame_Update then
        original_WorldMapFrame_Update()
    end
    MMM:OnMapUpdate()
    MMM:RefreshMarkers()
end

MMM:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if ModernMapMarkersDB and ModernMapMarkersDB.filters then
            for k, v in pairs(ModernMapMarkersDB.filters) do
                MMM.filters[k] = v
            end
        else
            -- First load: auto-detect player faction for transport filter
            local faction = UnitFactionGroup("player")
            if faction == "Alliance" or faction == "Horde" then
                MMM.filters.FACTION = faction
            end
        end

        L:Initialize()
        MMM:CacheZones()
        MMM:BuildData()

        -- Detect InstanceJournal
        if IJDB and IJLib and IJ_ShowInstanceEntrancesIcon then
            MMM.ijInstalled = true

            -- Build POI submap zone lookup
            if IJDB.POI then
                for _, poi in pairs(IJDB.POI) do
                    if poi.MapContinentId and poi.MapZoneId then
                        local key = tostring(poi.MapContinentId) .. ":" .. tostring(poi.MapZoneId)
                        IJ_SUBMAP_ZONES[key] = true
                    end
                end
            end

            -- Also include instance entrance locations inside other instance maps
            -- (e.g., Molten Core entrance inside BRD submap)
            local instanceMapIds = {}
            local allInstances = {}
            for _, inst in pairs(IJDB.DG or {}) do
                if inst.MapId then instanceMapIds[tostring(inst.MapId)] = true end
                table.insert(allInstances, inst)
            end
            for _, inst in pairs(IJDB.R or {}) do
                if inst.MapId then instanceMapIds[tostring(inst.MapId)] = true end
                table.insert(allInstances, inst)
            end
            for _, inst in ipairs(allInstances) do
                if inst.Entrances then
                    for _, ent in pairs(inst.Entrances) do
                        if ent.MapContinentId and ent.MapZoneId
                           and instanceMapIds[tostring(ent.MapContinentId)] then
                            local key = tostring(ent.MapContinentId) .. ":" .. tostring(ent.MapZoneId)
                            IJ_SUBMAP_ZONES[key] = true
                        end
                    end
                end
            end

            -- Hook IJ entrance markers: hide on world zones, keep in POI submaps
            -- In submaps, reskin entrance pins with MMM dungeon/raid textures
            local original_ShowEntrance = IJ_ShowInstanceEntrancesIcon
            IJ_ShowInstanceEntrancesIcon = function(instance)
                local key = tostring(GetCurrentMapContinent()) .. ":" .. tostring(GetCurrentMapZone())
                if IJ_SUBMAP_ZONES[key] then
                    original_ShowEntrance(instance)

                    -- Determine marker type and apply MMM filter
                    local isRaid = instance.Type == IJLib.InstanceType.Raid
                    local filterKey = isRaid and "RAID" or "DUNGEON"
                    local mmmTex = isRaid and TEXTURE_MAP.RAID or TEXTURE_MAP.DUNGEON

                    local cleanName = string.gsub(instance.Name or "", "%s+", "")
                    local prefix = "IJ_EntrancePin_" .. cleanName

                    for _, pin in ipairs(IJ_CreatedMapInstanceEntrance) do
                        local pinName = pin:GetName() or ""
                        if string.find(pinName, prefix, 1, true) and pin:IsVisible() then
                            -- Hide pin if MMM filter is disabled for this type
                            if not MMM.filters[filterKey] then
                                pin:Hide()
                            end
                            pin.icon:SetTexture(mmmTex)
                            pin.mmmInstance = instance
                            MMM:ApplyLockoutVisual(pin.icon, MMM:GetLockout(instance.Name or "") or (instance.Type ~= IJLib.InstanceType.Raid and MMM:GetActiveDungeon(instance.Name or "")))

                            if not pin.mmmReskinned then
                                pin.mmmReskinned = true
                                pin.mmmTexture = mmmTex

                                local mmmHL = instance.Type == IJLib.InstanceType.Raid and HIGHLIGHT_MAP.RAID or HIGHLIGHT_MAP.DUNGEON
                                if mmmHL then
                                    pin:SetHighlightTexture(mmmHL)
                                end

                                local origOnEnter = pin:GetScript("OnEnter")
                                local origOnLeave = pin:GetScript("OnLeave")

                                pin:SetScript("OnEnter", function()
                                    if origOnEnter then origOnEnter() end
                                    this.icon:SetTexture(this.mmmTexture)

                                    -- MMM tooltip for IJ POI submap markers
                                    local inst = this.mmmInstance
                                    if inst then
                                        WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
                                        WorldMapTooltip:AddLine(inst.Name or "", 1, 0.82, 0)
                                        local minLvl = inst.MinLevel or 0
                                        local maxLvl = inst.MaxLevel or 0
                                        local lvlLabel = L:GetLocalizedMarkerName("Level") or "Level"
                                        WorldMapTooltip:AddLine(lvlLabel .. ": " .. minLvl .. "-" .. maxLvl, 1, 1, 1, 1)
                                        local ijLock = MMM:GetLockout(inst.Name or "")
                                        if ijLock then
                                            WorldMapTooltip:AddLine(T("Saved") .. ": " .. FormatDuration(ijLock), 1, 0.4, 0.4)
                                        elseif inst.Type ~= IJLib.InstanceType.Raid and MMM:GetActiveDungeon(inst.Name or "") then
                                            WorldMapTooltip:AddLine(T("Active instance"), 1, 0.4, 0.4)
                                        end
                                        WorldMapTooltip:AddLine(L:GetLocalizedMarkerName("Left-Click: View Map"), 0.5, 0.5, 0.5)
                                        WorldMapTooltip:AddLine(L:GetLocalizedMarkerName("Right-Click: Instance Journal"), 0.5, 0.5, 0.5)
                                        WorldMapTooltip:Show()
                                    end
                                end)

                                pin:SetScript("OnLeave", function()
                                    if origOnLeave then origOnLeave() end
                                    this.icon:SetTexture(this.mmmTexture)
                                    WorldMapTooltip:Hide()
                                end)

                                -- Right click for IJ journal
                                pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                                local origOnClick = pin:GetScript("OnClick")
                                pin:SetScript("OnClick", function()
                                    if arg1 == "RightButton" and this.mmmInstance then
                                        local inst = this.mmmInstance
                                        if not IJ_InstanceJournalFrame:IsShown() then
                                            IJ_InstanceJournalFrame:Show()
                                        end
                                        if inst.Type == IJLib.InstanceType.Raid then
                                            IJ_ShowRaids = true
                                            PanelTemplates_SetTab(IJ_InstanceJournalFrame, 2)
                                        else
                                            IJ_ShowRaids = false
                                            PanelTemplates_SetTab(IJ_InstanceJournalFrame, 1)
                                        end
                                        IJ_ShowEncounter(inst)
                                        WorldMapFrame:Hide()
                                    else
                                        if origOnClick then origOnClick() end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end

        MMM:ScanLockouts()
        MMM:RequestLockouts(true)

        MMM:InvalidateCache()
        MMM:RefreshMarkers()

    elseif event == "PLAYER_ENTERING_WORLD" then
        MMM:RequestLockouts(true)
        MMM:ScheduleLockoutRequests()
        MMM:HookResetInstances()
        MMM:CheckInstanceZone()

    elseif event == "UPDATE_INSTANCE_INFO" then
        MMM:UpdateLockouts(true)

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "RAID_INSTANCE_WELCOME" then
        MMM:RequestLockouts(event == "RAID_INSTANCE_WELCOME")
        MMM:CheckInstanceZone()

    elseif event == "CHAT_MSG_SYSTEM" then
        MMM:OnResetMessage(arg1)
        -- "You are now saved to this instance" / an instance was reset: ask again soon
        if arg1 and string.find(string.lower(arg1), "saved", 1, true) or (arg1 and string.find(string.lower(arg1), "reset", 1, true)) then
            MMM:ScheduleLockoutRequests()
        end

    elseif event == "USER_WAYPOINT_UPDATED" then
        MMM:UpdateWaypointPin()

    elseif event == "PLAYER_LOGOUT" then
        if not ModernMapMarkersDB then ModernMapMarkersDB = {} end
        ModernMapMarkersDB.filters = {}
        for k, v in pairs(MMM.filters) do
            ModernMapMarkersDB.filters[k] = v
        end
    end
end)
MMM:RegisterEvent("VARIABLES_LOADED")
MMM:RegisterEvent("PLAYER_LOGOUT")
MMM:RegisterEvent("UPDATE_INSTANCE_INFO")
MMM:RegisterEvent("PLAYER_ENTERING_WORLD")
MMM:RegisterEvent("ZONE_CHANGED_NEW_AREA")
MMM:RegisterEvent("RAID_INSTANCE_WELCOME")
MMM:RegisterEvent("CHAT_MSG_SYSTEM")
-- Only exists with ClassicAPI; registering an unknown event is harmless in 1.12
MMM:RegisterEvent("USER_WAYPOINT_UPDATED")

-- /mmmlock            : saved raids reported by the game, tracked dungeons, and which map icons are greyed
-- /mmmlock dungeons on|off : switch dungeon tracking
-- /mmmlock clear           : forget every tracked dungeon (if the addon ever gets it wrong)
SLASH_MMMLOCK1 = "/mmmlock"
SlashCmdList["MMMLOCK"] = function(msg)
    msg = string.lower(msg or "")
    local _, _, cmd, option = string.find(msg, "^%s*(%S*)%s*(%S*)")
    if cmd == "dungeons" then
        if ModernMapMarkersDB == nil then ModernMapMarkersDB = {} end
        if option == "off" then ModernMapMarkersDB.trackDungeons = false
        elseif option == "on" then ModernMapMarkersDB.trackDungeons = nil
        else Msg("usage: /mmmlock dungeons on | off   (now " .. (MMM:DungeonTrackingEnabled() and "on" or "off") .. ")") return end
        Msg("dungeon tracking is " .. (MMM:DungeonTrackingEnabled() and "on" or "off") .. ".")
        MMM:InvalidateCache(); MMM:RefreshMarkers()
        return
    elseif cmd == "clear" then
        local store = MMM:DungeonStore()
        if store then for key in pairs(store) do store[key] = nil end end
        MMM.currentDungeon = nil
        Msg("forgot all tracked dungeon instances.")
        MMM:InvalidateCache(); MMM:RefreshMarkers()
        return
    end
    MMM:RequestLockouts(true)
    MMM:UpdateLockouts(true)
    local n = 0
    if type(GetNumSavedInstances) == "function" then n = GetNumSavedInstances() or 0 end
    Msg("saved raids reported by the game: " .. n)
    for i = 1, n do
        local name, id, reset = GetSavedInstanceInfo(i)
        if name then
            local left = tonumber(reset) or 0
            DEFAULT_CHAT_FRAME:AddMessage("   " .. name .. "  (resets in " .. FormatDuration(left) .. ")")
        end
    end
    local store = MMM:DungeonStore()
    local count = 0
    if store then
        for key, rec in pairs(store) do
            count = count + 1
            local where = (key == MMM.currentDungeon) and "inside now" or ("left " .. FormatDuration(time() - (rec.left or time())) .. " ago")
            DEFAULT_CHAT_FRAME:AddMessage("   active dungeon instance: " .. (rec.name or key) .. "  (" .. where .. ")")
        end
    end
    Msg("tracked dungeon instances: " .. count .. " (dungeon tracking " .. (MMM:DungeonTrackingEnabled() and "on" or "off") .. "; cleared by Reset Instances)")
    local matched = 0
    for _, d in pairs(MMM.Data or {}) do
        if (d.type == "DUNGEON" or d.type == "RAID") and (MMM:GetLockout(d.name) or (d.type == "DUNGEON" and MMM:GetActiveDungeon(d.name))) then
            matched = matched + 1
            DEFAULT_CHAT_FRAME:AddMessage("   map icon greyed: " .. d.name)
        end
    end
    if n == 0 and count == 0 then
        Msg("nothing saved or active. If you ARE saved to a raid, the game has not sent the raid info; open the Raid Info panel once and run /mmmlock again.")
    elseif n > 0 and matched == 0 then
        Msg("saved raids found but none matches a map icon name; please report the names listed above.")
    end
end

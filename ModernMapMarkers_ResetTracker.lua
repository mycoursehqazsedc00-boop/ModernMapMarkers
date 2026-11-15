-- ModernMapMarkers_ResetTracker.lua
-- Tracks remaining hourly ResetInstances() / new-instance slots (persisted in WTF via ModernMapMarkersDB),
-- adds reset-count lines to dungeon map tooltips, and provides a movable [X/5 - CD] HUD frame.
-- Strictly Vanilla 1.12 / Lua 5.0 compatible.

local MMM = ModernMapMarkersCore
if not MMM then return end

local LIMIT_WINDOW = 3600
local UPDATE_INTERVAL = 0.5

local function FormatMMSS(sec)
    if not sec or sec <= 0 then return "Ready" end
    sec = math.floor(sec)
    local m = math.floor(sec / 60)
    local s = math.mod(sec, 60)
    return string.format("%02d:%02d", m, s)
end

local function EnsureResetTrackerDB()
    if not ModernMapMarkersDB then ModernMapMarkersDB = {} end
    if type(ModernMapMarkersDB.resetTracker) ~= "table" then
        ModernMapMarkersDB.resetTracker = {}
    end
    return ModernMapMarkersDB.resetTracker
end

function MMM:IsResetDebug()
    local db = EnsureResetTrackerDB()
    return db.debug == true
end

function MMM:ResetTrace(msg)
    if not self:IsResetDebug() then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7f[MMM ResetTrace]|r " .. tostring(msg))
end

-- Returns: remaining, limit, nextCD, fullCD
-- remaining : number of instance resets/entries still available (0..limit)
-- limit     : configured hourly cap (default 5)
-- nextCD    : seconds until +1 slot frees up (0 if none used)
-- fullCD    : seconds until all slots are restored to limit/limit (0 if none used)
function MMM:GetResetStatus()
    local limit = self:InstanceLimit()
    local log = self:InstanceLog()
    local now = time()
    local entries = (log and log.entries) or {}
    local used = table.getn(entries)

    local oldest = nil
    local newest = nil
    for i = 1, used do
        local ts = entries[i]
        if ts then
            if not oldest or ts < oldest then oldest = ts end
            if not newest or ts > newest then newest = ts end
        end
    end

    if log and log.limitAt then
        if used < limit then used = limit end
        if not oldest or log.limitAt < oldest then oldest = log.limitAt end
        if not newest or log.limitAt > newest then newest = log.limitAt end
    end

    local remaining = limit - used
    if remaining < 0 then remaining = 0 end

    local nextCD = 0
    if oldest then
        nextCD = oldest + LIMIT_WINDOW - now
        if nextCD < 0 then nextCD = 0 end
    end

    local fullCD = 0
    if newest then
        fullCD = newest + LIMIT_WINDOW - now
        if fullCD < 0 then fullCD = 0 end
    end

    return remaining, limit, nextCD, fullCD
end

-- Record extra resets (e.g. un-saved raid resets) that were not in the dungeon store
function MMM:OnExtraInstanceResets(count)
    if not self:DungeonTrackingEnabled() then return end
    if not count or count <= 0 then return end
    local log = self:InstanceLog()
    local limit = self:InstanceLimit()
    local now = time()
    local added = 0
    for i = 1, count do
        if table.getn(log.entries) < limit then
            table.insert(log.entries, now)
            added = added + 1
        end
    end
    self:ResetTrace("OnExtraInstanceResets count=" .. count .. " added=" .. added .. " used=" .. table.getn(log.entries) .. "/" .. limit)
    self:UpdateResetTrackerFrame()
end

-- Append reset availability & cooldown to dungeon tooltips on the World Map
function MMM:AddResetTooltipLines(tooltip)
    if not tooltip or not self:DungeonTrackingEnabled() then return end
    local remaining, limit, nextCD, fullCD = self:GetResetStatus()

    local r, g, b = 0.27, 1.0, 0.27
    if remaining == 0 then
        r, g, b = 1.0, 0.27, 0.27
    elseif remaining <= 2 then
        r, g, b = 1.0, 0.67, 0.13
    end

    local line = "Resets left: " .. remaining .. "/" .. limit
    if fullCD > 0 then
        if remaining == 0 and nextCD > 0 then
            line = line .. " (Next: " .. FormatMMSS(nextCD) .. ", Full: " .. FormatMMSS(fullCD) .. ")"
        else
            line = line .. " (Full CD: " .. FormatMMSS(fullCD) .. ")"
        end
    end
    tooltip:AddLine(line, r, g, b)
end

-- ---------------------------------------------------------------------------
-- Movable HUD Frame: [X/5 - CD]
-- ---------------------------------------------------------------------------
function MMM:IsResetFrameLocked()
    local db = EnsureResetTrackerDB()
    return db.locked == true
end

function MMM:SaveResetFramePosition()
    if not self.resetTrackerFrame then return end
    local point, _, relativePoint, x, y = self.resetTrackerFrame:GetPoint()
    if point then
        local db = EnsureResetTrackerDB()
        db.point = point
        db.relativePoint = relativePoint or point
        db.x = math.floor((x or 0) + 0.5)
        db.y = math.floor((y or 0) + 0.5)
        self:ResetTrace("Saved pos: " .. db.point .. " (" .. db.x .. ", " .. db.y .. ")")
    end
end

function MMM:RestoreResetFramePosition()
    if not self.resetTrackerFrame then return end
    local db = EnsureResetTrackerDB()
    self.resetTrackerFrame:ClearAllPoints()
    if db.point and db.x and db.y then
        self.resetTrackerFrame:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x, db.y)
    else
        self.resetTrackerFrame:SetPoint("TOP", UIParent, "TOP", 0, -40)
    end
    if db.hidden then
        self.resetTrackerFrame:Hide()
    else
        self.resetTrackerFrame:Show()
    end
end

function MMM:UpdateResetTrackerFrame()
    local f = self.resetTrackerFrame
    if not f or not f:IsShown() then return end

    local remaining, limit, nextCD, fullCD = self:GetResetStatus()
    if self.lastTraceRemaining ~= remaining or self.lastTraceLimit ~= limit then
        self.lastTraceRemaining = remaining
        self.lastTraceLimit = limit
        self:ResetTrace("Status changed: " .. remaining .. "/" .. limit .. " nextCD=" .. FormatMMSS(nextCD) .. " fullCD=" .. FormatMMSS(fullCD))
    end
    local color = "|cff44ff44"
    if remaining == 0 then
        color = "|cffff4444"
    elseif remaining <= 2 then
        color = "|cffffaa22"
    end

    local cdText = FormatMMSS(fullCD)
    f.text:SetText("[" .. color .. remaining .. "/" .. limit .. "|r - " .. cdText .. "]")

    local w = f.text:GetStringWidth()
    if w and w > 0 then
        local targetW = w + 18
        if targetW < 104 then targetW = 104 end
        f:SetWidth(targetW)
    end
end

function MMM:CreateResetTrackerFrame()
    if self.resetTrackerFrame then return self.resetTrackerFrame end

    local f = CreateFrame("Frame", "ModernMapMarkersResetFrame", UIParent)
    f:SetWidth(116)
    f:SetHeight(24)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.85)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 0)
    f.text = text

    f:SetScript("OnDragStart", function()
        if not MMM:IsResetFrameLocked() then
            this:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        MMM:SaveResetFramePosition()
    end)

    f:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Instance Resets (ResetInstances)", 1, 0.82, 0)
        local remaining, limit, nextCD, fullCD = MMM:GetResetStatus()
        GameTooltip:AddLine("Resets remaining: " .. remaining .. " / " .. limit, 1, 1, 1)
        if fullCD > 0 then
            if nextCD > 0 and remaining < limit then
                GameTooltip:AddLine("Next +1 slot in: " .. FormatMMSS(nextCD), 0.7, 0.9, 1)
            end
            GameTooltip:AddLine("Full reset (" .. limit .. "/" .. limit .. ") in: " .. FormatMMSS(fullCD), 1, 0.8, 0.4)
        else
            GameTooltip:AddLine("All resets available", 0.4, 1, 0.4)
        end
        if MMM:IsResetFrameLocked() then
            GameTooltip:AddLine("Frame locked (/mmmreset lock)", 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("Drag to move | /mmmreset to hide", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)

    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local elapsed = 0
    f:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed < UPDATE_INTERVAL then return end
        elapsed = 0
        MMM:UpdateResetTrackerFrame()
    end)

    self.resetTrackerFrame = f
    self:RestoreResetFramePosition()
    self:UpdateResetTrackerFrame()
    return f
end

-- Initialize on VARIABLES_LOADED / PLAYER_ENTERING_WORLD
local loader = CreateFrame("Frame")
loader:RegisterEvent("VARIABLES_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
    MMM:CreateResetTrackerFrame()
    MMM:RestoreResetFramePosition()
    MMM:UpdateResetTrackerFrame()
end)

-- Slash command: /mmmreset [show|hide|lock|resetpos|trace|status]
SLASH_MMMRESET1 = "/mmmreset"
SlashCmdList["MMMRESET"] = function(msg)
    msg = string.lower(msg or "")
    local _, _, cmd = string.find(msg, "^%s*(%S*)")
    local db = EnsureResetTrackerDB()
    local f = MMM:CreateResetTrackerFrame()

    if cmd == "trace" or cmd == "debug" then
        db.debug = not db.debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7fModernMapMarkers:|r reset trace " .. (db.debug and "ON." or "OFF."))
        if db.debug then
            local remaining, limit, nextCD, fullCD = MMM:GetResetStatus()
            MMM:ResetTrace("Enabled: " .. remaining .. "/" .. limit .. " nextCD=" .. FormatMMSS(nextCD) .. " fullCD=" .. FormatMMSS(fullCD))
        end
        return
    elseif cmd == "status" then
        local remaining, limit, nextCD, fullCD = MMM:GetResetStatus()
        DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7fModernMapMarkers Reset Status:|r " .. remaining .. "/" .. limit .. " left | Next: " .. FormatMMSS(nextCD) .. " | Full: " .. FormatMMSS(fullCD) .. " | Locked: " .. tostring(db.locked == true) .. " | Hidden: " .. tostring(db.hidden == true) .. " | Trace: " .. tostring(db.debug == true))
        return
    elseif cmd == "lock" then
        db.locked = not db.locked
        DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7fModernMapMarkers:|r reset tracker frame " .. (db.locked and "locked." or "unlocked."))
        return
    elseif cmd == "resetpos" then
        db.point = nil
        db.relativePoint = nil
        db.x = nil
        db.y = nil
        db.hidden = nil
        MMM:RestoreResetFramePosition()
        MMM:UpdateResetTrackerFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7fModernMapMarkers:|r reset tracker position reset.")
        return
    elseif cmd == "show" then
        db.hidden = nil
        f:Show()
        MMM:UpdateResetTrackerFrame()
        return
    elseif cmd == "hide" then
        db.hidden = true
        f:Hide()
        return
    end

    if f:IsShown() then
        db.hidden = true
        f:Hide()
    else
        db.hidden = nil
        f:Show()
        MMM:UpdateResetTrackerFrame()
    end
end

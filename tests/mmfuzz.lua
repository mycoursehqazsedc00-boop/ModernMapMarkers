-- usage: [MODE=event|silent|mixed] texlua mmfuzz.lua <addon_dir> <seed> [steps]
MM_DIR = arg[1]; local seed = tonumber(arg[2]); local steps = tonumber(arg[3] or 200)
dofile((arg[0]:match("^(.*)/[^/]*$") or ".") .. "/mmenv.lua")
math.randomseed(seed * 104729 + 7)
local mode = os.getenv("MODE") or "mixed"
W.raidInfoMode = (mode == "mixed") and ((seed % 2 == 0) and "event" or "silent") or mode
W.noDesaturate = (seed % 3 == 0)
LoadAddon(); FireEvent("VARIABLES_LOADED"); FireEvent("PLAYER_ENTERING_WORLD"); Tick(0.1, 2)
local DAY = 86400
-- saved name the client may report -> marker base name expected to grey, and where it can be seen
local CASES = {
  { "Molten Core", "Molten Core", "Eastern Kingdoms", "Burning Steppes" }, { "Blackwing Lair", "Blackwing Lair", "Eastern Kingdoms", "Burning Steppes" },
  { "Upper Blackrock Spire", "Upper Blackrock Spire", "Eastern Kingdoms", "Burning Steppes" }, { "Blackrock Depths", "Blackrock Depths", "Eastern Kingdoms", "Burning Steppes" },
  { "Deadmines", "The Deadmines", "Eastern Kingdoms", "Westfall" }, { "The Deadmines", "The Deadmines", "Eastern Kingdoms", "Westfall" },
  { "Scholomance", "Scholomance", "Eastern Kingdoms", "Western Plaguelands" }, { "Stratholme", "Stratholme", "Eastern Kingdoms", "Eastern Plaguelands" },
  { "Zul'Gurub", "Zul'Gurub", "Eastern Kingdoms", "Stranglethorn Vale" }, { "Onyxia's Lair", "Onyxia's Lair", "Kalimdor", "Dustwallow Marsh" },
  { "Ruins of Ahn'Qiraj", "Ruins of Ahn'Qiraj", "Kalimdor", "Silithus" }, { "Temple of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Kalimdor", "Silithus" },
}
local zones = {}
for _, c in ipairs(CASES) do zones[c[3] .. "|" .. c[4]] = { c[3], c[4] } end
local zoneList = {}; for _, z in pairs(zones) do zoneList[#zoneList + 1] = z end; table.sort(zoneList, function(a, b) return a[1] .. a[2] < b[1] .. b[2] end)
local function base(n) return (n:gsub(" %- .*$", "")) end
local function expectGrey(markerName)
  local b = base(markerName)
  for _, s in ipairs(W.saved) do
    if s.expire - CLOCK > 0 then
      for _, c in ipairs(CASES) do if c[1] == s.name and c[2] == b then return true end end
    end
  end
  return false
end
local seq, lastChange, lastSettle, mapOpenedAt, violations, checks = 0, 0, 0, nil, 0, 0
local changeClock = -1
local curZone
local function change() seq = seq + 1; lastChange = seq; changeClock = CLOCK end
local function settle() seq = seq + 1; lastSettle = seq end
for step = 1, steps do
  Tick(0.02, 1)   -- every step is at least one frame
  local r = math.random(1, 100); local what
  if r <= 14 then
    local c = CASES[math.random(#CASES)]; for i = #W.saved, 1, -1 do if W.saved[i].name == c[1] then table.remove(W.saved, i) end end
    AddSaved(c[1], math.random(30, 4 * DAY)); change(); what = "save"
  elseif r <= 22 then
    if #W.saved > 0 then table.remove(W.saved, math.random(#W.saved)); change() end; what = "unsave"
  elseif r <= 36 then
    local z = zoneList[math.random(#zoneList)]; OpenMap(z[1], z[2]); curZone = z; if not mapOpenedAt then mapOpenedAt = CLOCK end; settle(); what = "open"
  elseif r <= 44 then
    CloseMap(); mapOpenedAt = nil; curZone = nil; Tick(0.05, 2); what = "close"
  elseif r <= 54 then
    FireEvent("UPDATE_INSTANCE_INFO"); settle(); what = "event"
  elseif r <= 60 then
    local ev = ({ "ZONE_CHANGED_NEW_AREA", "RAID_INSTANCE_WELCOME", "PLAYER_ENTERING_WORLD" })[math.random(3)]; FireEvent(ev); what = ev
  elseif r <= 64 then
    FireEvent("CHAT_MSG_SYSTEM", ({ "You are now saved to this instance.", "Instance reset.", "hello" })[math.random(3)]); what = "chat"
  elseif r <= 72 then
    if mapOpenedAt then local ms = Markers(); if #ms > 0 then local m = ms[math.random(#ms)]; Hover(m); Unhover(m) end end; what = "hover"
  else
    local dt = ({ 0.05, 1, 5, 25, 60, 600 })[math.random(6)]; Tick(dt, 1); what = "tick"
    -- an expiry is a change in the data too
    for _, s in ipairs(W.saved) do local left = s.expire - CLOCK; if left <= 0 and left > -dt - 1 then change() end end
  end
  -- invariant: once the addon has had its chance to refresh, the icons match the saved list
  if mapOpenedAt and WorldMapFrame:IsVisible() then
    local settled = (lastSettle > lastChange) or (mapOpenedAt <= changeClock and CLOCK - changeClock >= 21)
    if settled then
      for _, m in ipairs(Markers()) do
        if (m.markerType == "DUNGEON" or m.markerType == "RAID") then
          checks = checks + 1
          if IsGrey(m) ~= expectGrey(m.name) then violations = violations + 1; if os.getenv("VERBOSE") then print(string.format("  step %d (%s): %s grey=%s expected=%s", step, what, m.name, tostring(IsGrey(m)), tostring(expectGrey(m.name)))) end end
        end
      end
    end
  end
end
-- timers must not leak once the map is closed
CloseMap(); Tick(1, 3); local core = ModernMapMarkersCore
local leaked = core and core._scripts.OnUpdate ~= nil
print(string.format("SEED %d mode=%s errs=%d checks=%d violations=%d leakedTimer=%s", seed, W.raidInfoMode, #ERRORS, checks, violations, tostring(leaked)))
if #ERRORS > 0 then print("ERR " .. ERRORS[1].where .. " " .. ERRORS[1].msg:sub(1, 200):gsub("\n", " ")) end

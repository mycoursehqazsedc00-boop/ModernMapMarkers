-- usage: texlua mmfuzz2.lua <addon_dir> <seed> [steps]   model-based fuzz of dungeon tracking
MM_DIR = arg[1]; local seed = tonumber(arg[2]); local steps = tonumber(arg[3] or 250)
dofile((arg[0]:match("^(.*)/[^/]*$") or ".") .. "/mmenv.lua")
math.randomseed(seed * 7907 + 3)
UseClassicInstanceAPI(seed % 2 == 0)
LoadAddon(); FireEvent("VARIABLES_LOADED"); FireEvent("PLAYER_ENTERING_WORLD"); Tick(0.1, 2)
-- dungeon key = marker base name; how to "walk in", names the game may use in reset messages, and where the icons are
local D = {
  { key = "Dire Maul", zone = "Dire Maul", sub = "Gordok Commons", names = { "DireMaul", "Dire Maul" }, map = { "Kalimdor", "Feralas" }, world = "Feralas" },
  { key = "Scholomance", zone = "Scholomance", names = { "Scholomance" }, map = { "Eastern Kingdoms", "Western Plaguelands" }, world = "Western Plaguelands" },
  { key = "Stratholme", zone = "Stratholme", names = { "Stratholme" }, map = { "Eastern Kingdoms", "Eastern Plaguelands" }, world = "Eastern Plaguelands" },
  { key = "The Deadmines", zone = "Deadmines", names = { "Deadmines", "The Deadmines" }, map = { "Eastern Kingdoms", "Westfall" }, world = "Westfall" },
  { key = "Blackrock Depths", zone = "Blackrock Depths", names = { "BlackrockDepths" }, map = { "Eastern Kingdoms", "Burning Steppes" }, world = "Burning Steppes" },
  { key = "Upper Blackrock Spire", zone = "Blackrock Spire", sub = "Upper Blackrock Spire", names = { "Upper Blackrock Spire" }, map = { "Eastern Kingdoms", "Burning Steppes" }, world = "Burning Steppes" },
  { key = "Lower Blackrock Spire", zone = "Blackrock Spire", sub = "Lower Blackrock Spire", names = { "Lower Blackrock Spire" }, map = { "Eastern Kingdoms", "Burning Steppes" }, world = "Burning Steppes" },
}
local IDLE = 3600
local function now() return 1700000000 + math.floor(CLOCK) end
local active, current = {}, nil        -- model: active[key] = { left = time or nil }
local pending = nil                     -- model of the ResetInstances window
local mapOpen, mapDungeons = false, nil
local violations, checks = 0, 0
local entries, limitAt, LIMIT = {}, nil, 5          -- model of the hourly instance counter
local function limitRemaining()
  local t = now(); local kept = {}
  for _, e in ipairs(entries) do if t - e < 3600 then kept[#kept + 1] = e end end; entries = kept
  if limitAt and t - limitAt >= 3600 then limitAt = nil end
  local n = #entries
  if n >= LIMIT then local r = entries[n - LIMIT + 1] + 3600 - t; if r > 0 then return r, false end end
  if limitAt then local r = limitAt + 3600 - t; if r > 0 then return r, true end end
  return nil
end
local function alive(rec) return rec and not (rec.left and now() - rec.left >= IDLE) end
local function byKey(k) for _, d in ipairs(D) do if d.key == k then return d end end end
local function markerBase(n) return (n:gsub(" %- .*$", "")) end
local function applyPending()
  if pending and CLOCK >= pending.deadline then
    if pending.successes > 0 then
      for k in pairs(active) do if k ~= current and not pending.failed[k] then active[k] = nil end end
    end
    pending = nil
  end
end
for step = 1, steps do
  Tick(0.02, 1); applyPending()
  local r = math.random(1, 100); local what
  if r <= 16 then
    local d = D[math.random(#D)]
    local wasAlive = alive(active[d.key])
    if current and current ~= d.key then active[current].left = now(); current = nil end
    EnterDungeon(d.zone, d.sub, "party"); active[d.key] = { left = nil }; current = d.key; what = "enter " .. d.key
    if not wasAlive then entries[#entries + 1] = now(); limitAt = nil end
  elseif r <= 30 then
    if current then local d = byKey(current); active[current].left = now(); current = nil; LeaveDungeon(d.world) end; what = "leave"
  elseif r <= 42 then
    local d = D[math.random(#D)]; local nm = d.names[math.random(#d.names)]
    FireEvent("CHAT_MSG_SYSTEM", nm .. " has been reset" .. ({ ".", "", ". " })[math.random(3)])
    if pending then pending.successes = pending.successes + 1 end
    if d.key ~= current then active[d.key] = nil end; what = "reset msg " .. nm
  elseif r <= 48 then
    FireEvent("CHAT_MSG_SYSTEM", "Mystery Place has been reset."); if pending then pending.successes = pending.successes + 1 end; what = "reset msg (unknown name)"
  elseif r <= 56 then
    local d = D[math.random(#D)]; FireEvent("CHAT_MSG_SYSTEM", "Cannot reset " .. d.names[1] .. ".  There are players still inside the instance.")
    if pending then pending.failed[d.key] = true end; what = "refused " .. d.key
  elseif r <= 66 then
    ResetInstances(); pending = { deadline = CLOCK + 3, successes = 0, failed = {} }; what = "ResetInstances()"
  elseif r <= 72 then
    local msg = ({ "You are now saved to this instance.", "hello", "Instance reset.", "You have entered too many instances recently." })[math.random(4)]
    FireEvent("CHAT_MSG_SYSTEM", msg); what = "chat"
    if msg:find("too many instances", 1, true) then limitAt = now() end
  elseif r <= 82 then
    local d = D[math.random(#D)]; OpenMap(d.map[1], d.map[2]); mapOpen = true; mapDungeons = d.map[2]; what = "open map"
  elseif r <= 86 then
    CloseMap(); mapOpen = false; what = "close map"
  else
    local dt = ({ 0.5, 4, 30, 700, 1900, 3700 })[math.random(6)]; Tick(dt, 1); what = "tick " .. dt
  end
  applyPending()
  -- the hourly-limit tooltip line must agree with the model
  if mapOpen and WorldMapFrame:IsVisible() and math.random() < 0.35 then
    local cand = {}
    for _, m in ipairs(Markers()) do if m.markerType == "DUNGEON" and not alive(active[markerBase(m.name)]) then cand[#cand + 1] = m end end
    if #cand > 0 then
      local m = cand[math.random(#cand)]; Hover(m)
      local line; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then line = l end end; Unhover(m)
      local rem, upper = limitRemaining(); checks = checks + 1
      local bad = false
      if rem then bad = (not line) or (upper and not line:find("<=", 1, true)) or ((not upper) and line:find("<=", 1, true) ~= nil) else bad = (line ~= nil) end
      if bad then violations = violations + 1; if os.getenv("VERBOSE") then print(string.format("  step %d (%s): limit tooltip=%s expected=%s%s", step, what, tostring(line), tostring(rem), upper and " (upper bound)" or "")) end end
    end
  end
  -- the icons must agree with the model (after the reset window has closed)
  if mapOpen and WorldMapFrame:IsVisible() and not pending then
    for _, m in ipairs(Markers()) do
      if m.markerType == "DUNGEON" then
        checks = checks + 1
        local expect = alive(active[markerBase(m.name)])
        if IsGrey(m) ~= (expect and true or false) then
          violations = violations + 1
          if os.getenv("VERBOSE") then print(string.format("  step %d (%s): %s grey=%s expected=%s", step, what, m.name, tostring(IsGrey(m)), tostring(expect and true or false))) end
        end
      end
    end
  end
end
print(string.format("SEED %d classic=%s errs=%d checks=%d violations=%d", seed, tostring(seed % 2 == 0), #ERRORS, checks, violations))
if #ERRORS > 0 then print("ERR " .. ERRORS[1].where .. " " .. ERRORS[1].msg:sub(1, 200):gsub("\n", " ")) end

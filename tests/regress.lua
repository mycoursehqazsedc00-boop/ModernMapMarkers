-- usage: texlua regress.lua <addon_dir> <config>   prints one signature line per map
MM_DIR = arg[1]; local cfg = arg[2] or "default"
dofile((arg[0]:match("^(.*)/[^/]*$") or ".") .. "/mmenv.lua")
if cfg == "horde" then W.faction = "Horde" end
LoadAddon()
local types = { "dungeon", "raid", "worldboss", "boat", "zeppelin", "tram" }
local off = cfg:match("^off_(%a+)$")
if off then ModernMapMarkersDB = { filters = { DUNGEON = true, RAID = true, WORLDBOSS = true, BOAT = true, ZEPPELIN = true, TRAM = true, FACTION = "ALL" } }; ModernMapMarkersDB.filters[string.upper(off)] = false end
if cfg == "alliance_only" then ModernMapMarkersDB = { filters = { DUNGEON = true, RAID = true, WORLDBOSS = true, BOAT = true, ZEPPELIN = true, TRAM = true, FACTION = "Alliance" } } end
FireEvent("VARIABLES_LOADED"); FireEvent("PLAYER_ENTERING_WORLD"); Tick(0.1, 2)
local function sig()
  local out = {}
  for _, m in ipairs(Markers()) do
    local p = m._points[#m._points] or {}
    out[#out + 1] = string.format("%s|%s|%s|%dx%d|%s,%s,%s|%s|%s", m.name, m.markerType, tostring(m.texture._tex), m._w, m._h,
      tostring(p[4] and string.format("%.2f", p[4])), tostring(p[5] and string.format("%.2f", p[5])), tostring(m.zoneName), tostring(m.texture._vertex[1]) .. tostring(m.texture._vertex[2]), tostring(m.texture._desat))
  end
  table.sort(out); return table.concat(out, ";")
end
local function zoneList(c) return { GetMapZones(c) } end
for c = 1, 2 do
  W.cont, W.zone = c, 0; WorldMapFrame:Show(); WorldMapFrame_Update()
  print(string.format("C%d continent: %s", c, sig()))
  for z, name in ipairs(zoneList(c)) do
    W.cont, W.zone = c, z; WorldMapFrame_Update()
    print(string.format("C%dZ%d %s: %s", c, z, name, sig()))
  end
end
print("errors: " .. #ERRORS)

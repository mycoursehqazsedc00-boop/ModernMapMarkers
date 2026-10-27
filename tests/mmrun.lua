-- usage: texlua mmrun.lua <addon_dir> <scenario>
MM_DIR = arg[1]; local want = arg[2]
local SD = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
dofile(SD .. "/mmenv.lua")
local DAY = 86400
function boot() LoadAddon(); FireEvent("VARIABLES_LOADED"); FireEvent("PLAYER_ENTERING_WORLD"); Tick(0.1, 2) end
local function noerr(m) if #ERRORS > 0 then error((m or "errors") .. ": " .. ERRORS[1].where .. " -> " .. ERRORS[1].msg:sub(1, 300), 0) end end
local function check(c, m) if not c then error(m or "check failed", 0) end end
local function savedLine() for _, l in ipairs(Tooltip()) do if l:find("Saved", 1, true) then return l end end end
local S = {}
S.baseline_not_grey = function()
  boot(); OpenMap("Eastern Kingdoms", "Burning Steppes"); noerr("open")
  for _, m in ipairs(Markers()) do check(not IsGrey(m), m.name .. " must not be grey without a lockout") end
  Hover(Marker("Molten Core")); check(not savedLine(), "no Saved line without a lockout"); return "ungreyed, no Saved line"
end
S.event_then_open = function()   -- data arrives by event while the map is closed
  W.raidInfoMode = "event"; AddSaved("Molten Core", 3 * DAY + 4 * 3600); boot(); Tick(1, 1)
  OpenMap("Eastern Kingdoms", "Burning Steppes"); noerr("open")
  check(IsGrey(Marker("Molten Core")), "Molten Core greyed"); check(not IsGrey(Marker("Blackwing Lair")), "unsaved raid not greyed")
  Hover(Marker("Molten Core")); local l = savedLine(); check(l, "tooltip shows Saved: " .. table.concat(Tooltip(), " | ")); return l
end
S.event_while_open = function()  -- map already open when the data arrives
  W.raidInfoMode = "event"; boot(); OpenMap("Eastern Kingdoms", "Burning Steppes")
  check(not IsGrey(Marker("Molten Core")), "not grey yet"); AddSaved("Molten Core", 3 * DAY); FireEvent("UPDATE_INSTANCE_INFO"); noerr("event")
  check(IsGrey(Marker("Molten Core")), "greyed as soon as the data arrives while the map is open"); return "live update ok"
end
S.silent_client_preloaded = function()  -- client has the data but never fires UPDATE_INSTANCE_INFO
  W.raidInfoMode = "silent"; AddSaved("Molten Core", 3 * DAY); boot(); Tick(5, 3)
  OpenMap("Eastern Kingdoms", "Burning Steppes"); noerr("open")
  check(IsGrey(Marker("Molten Core")), "greyed from data the client already holds"); Hover(Marker("Molten Core")); check(savedLine(), "Saved line shown")
  return "works without an event"
end
S.silent_client_saved_later = function() -- player gets saved while playing; no event; map reopened
  W.raidInfoMode = "silent"; boot(); OpenMap("Eastern Kingdoms", "Burning Steppes"); check(not IsGrey(Marker("Molten Core")), "not saved yet")
  CloseMap(); AddSaved("Molten Core", 7 * DAY); Tick(60, 1); OpenMap("Eastern Kingdoms", "Burning Steppes"); noerr("reopen")
  check(IsGrey(Marker("Molten Core")), "greyed after reopening the map"); return "reopen picks up new lockout"
end
S.request_when_map_opens = function()
  W.raidInfoMode = "event"; boot(); local before = W.requests; Tick(60, 1)
  OpenMap("Eastern Kingdoms", "Burning Steppes"); check(W.requests > before, "asks the server for fresh raid info when the map opens (requests " .. before .. " -> " .. W.requests .. ")")
  return "requests " .. before .. " -> " .. W.requests
end
S.expiry_while_open = function()
  W.raidInfoMode = "event"; AddSaved("Molten Core", 100); boot(); Tick(1, 1); OpenMap("Eastern Kingdoms", "Burning Steppes"); check(IsGrey(Marker("Molten Core")), "greyed")
  Tick(10, 15); noerr("wait"); check(not IsGrey(Marker("Molten Core")), "icon returns to normal after the lockout expires while the map stays open"); return "expiry handled"
end
S.countdown_in_tooltip = function()
  W.raidInfoMode = "event"; AddSaved("Molten Core", 3 * DAY); boot(); Tick(1, 1); OpenMap("Eastern Kingdoms", "Burning Steppes")
  Hover(Marker("Molten Core")); local a = savedLine(); Unhover(Marker("Molten Core")); Tick(3600, 1); Hover(Marker("Molten Core")); local b = savedLine()
  check(a and b and a ~= b, "reset time counts down: " .. tostring(a) .. " -> " .. tostring(b)); return a .. " -> " .. b
end
S.no_desaturate_api = function()
  W.noDesaturate = true; W.raidInfoMode = "event"; AddSaved("Molten Core", DAY); boot(); Tick(1, 1); OpenMap("Eastern Kingdoms", "Burning Steppes"); noerr("no SetDesaturated")
  check(IsGrey(Marker("Molten Core")), "still greyed (vertex colour fallback)"); return "fallback ok"
end
-- every dungeon/raid marker, with the saved-instance names a client could plausibly return
local ALIASES = {
  ["Blackrock Depths"] = { "Blackrock Depths" }, ["Lower Blackrock Spire"] = { "Lower Blackrock Spire" }, ["Upper Blackrock Spire"] = { "Upper Blackrock Spire" },
  ["Molten Core"] = { "Molten Core" }, ["Blackwing Lair"] = { "Blackwing Lair" }, ["Onyxia's Lair"] = { "Onyxia's Lair" }, ["Zul'Gurub"] = { "Zul'Gurub" },
  ["Ruins of Ahn'Qiraj"] = { "Ruins of Ahn'Qiraj" }, ["Temple of Ahn'Qiraj"] = { "Temple of Ahn'Qiraj" }, ["Naxxramas"] = { "Naxxramas" },
  ["Emerald Sanctum"] = { "Emerald Sanctum" }, ["Lower Karazhan Halls"] = { "Lower Karazhan Halls" }, ["Tower of Karazhan"] = { "Tower of Karazhan", "Upper Karazhan Halls" },
  ["Stratholme"] = { "Stratholme" }, ["Scholomance"] = { "Scholomance" }, ["The Deadmines"] = { "The Deadmines", "Deadmines" }, ["The Stockade"] = { "The Stockade", "Stormwind Stockade" },
  ["Dire Maul - East"] = { "Dire Maul" }, ["Scarlet Monastery - Library"] = { "Scarlet Monastery" }, ["Uldaman - Main Entrance"] = { "Uldaman" },
}
S.name_matching = function()
  W.raidInfoMode = "event"; boot(); local fails = {}
  local function try1(zoneCont, zone, markerName, savedName)
    W.saved = {}; AddSaved(savedName, DAY); FireEvent("UPDATE_INSTANCE_INFO"); OpenMap(zoneCont, zone)
    local m = Marker(markerName); if not m then return "marker not shown" end
    return IsGrey(m) and "ok" or "NOT greyed"
  end
  local cases = {
    { "Eastern Kingdoms", "Burning Steppes", "Blackrock Depths", "Blackrock Depths" }, { "Eastern Kingdoms", "Burning Steppes", "Upper Blackrock Spire", "Upper Blackrock Spire" },
    { "Eastern Kingdoms", "Burning Steppes", "Molten Core", "Molten Core" }, { "Eastern Kingdoms", "Burning Steppes", "Blackwing Lair", "Blackwing Lair" },
    { "Eastern Kingdoms", "Westfall", "The Deadmines", "The Deadmines" }, { "Eastern Kingdoms", "Westfall", "The Deadmines", "Deadmines" },
    { "Eastern Kingdoms", "Eastern Plaguelands", "Stratholme", "Stratholme" }, { "Eastern Kingdoms", "Western Plaguelands", "Scholomance", "Scholomance" },
  }
  for _, c in ipairs(cases) do local r = try1(c[1], c[2], c[3], c[4]); if r ~= "ok" then fails[#fails + 1] = c[3] .. " <- '" .. c[4] .. "': " .. r end end
  check(#fails == 0, table.concat(fails, "; ")); return #cases .. " name cases ok"
end

S.desaturated_icon = function()
  W.raidInfoMode = "event"; AddSaved("Molten Core", DAY); boot(); Tick(1, 1); OpenMap("Eastern Kingdoms", "Burning Steppes")
  local mc, bwl = Marker("Molten Core"), Marker("Blackwing Lair")
  check(mc.texture._desat == true and mc.texture._vertex[1] < 0.8, "saved raid: desaturated and dimmed")
  check(not bwl.texture._desat and bwl.texture._vertex[1] == 1, "unsaved raid: untouched")
  AddSaved("Blackwing Lair", DAY); FireEvent("UPDATE_INSTANCE_INFO"); check(bwl.texture._desat == true, "second raid greyed on update")
  W.saved = {}; FireEvent("UPDATE_INSTANCE_INFO"); check(not mc.texture._desat and mc.texture._vertex[1] == 1, "icon fully restored when the lockout is gone")
  return "desaturate + restore"
end
S.ij_pin_greyed = function()
  dofile(MM_DIR .. "/MarkerData.lua"); BuildZoneLists()
  local idx; for i, z in ipairs(GetZoneListForTest and GetZoneListForTest(2) or { GetMapZones(2) }) do if z == "Burning Steppes" then idx = i end end
  InstallIJ(); IJDB.POI[1].MapZoneId = idx
  W.raidInfoMode = "event"; AddSaved("Molten Core", 2 * DAY); boot(); Tick(1, 1)
  check(MMM_IJ_OK ~= false, "ij"); OpenMap("Eastern Kingdoms", "Burning Steppes"); noerr("open")
  local mcPin = IJ_ShowInstanceEntrancesIcon({ Name = "Molten Core", Type = IJLib.InstanceType.Raid, MinLevel = 60, MaxLevel = 60 }) or IJPinFor("Molten Core")
  mcPin = mcPin or IJPinFor("Molten Core"); check(mcPin, "IJ pin created")
  check(mcPin.icon._vertex[1] < 0.8 and mcPin.icon._desat == true, "IJ pin for a saved raid is greyed")
  W.mouseOver = mcPin; runHook = nil; _G.this = mcPin; mcPin._scripts.OnEnter(); local found
  for _, l in ipairs(Tooltip()) do if l:find("Saved", 1, true) then found = l end end
  check(found, "IJ pin tooltip shows the reset time: " .. table.concat(Tooltip(), " | "))
  local bwlPin = IJ_ShowInstanceEntrancesIcon({ Name = "Blackwing Lair", Type = IJLib.InstanceType.Raid, MinLevel = 60, MaxLevel = 60 }) or IJPinFor("Blackwing Lair")
  check(bwlPin and bwlPin.icon._vertex[1] == 1, "unsaved raid's IJ pin is normal")
  return "IJ pins greyed: " .. found
end
S.mmmlock_command = function()
  W.raidInfoMode = "event"; boot(); CHAT = {}; SlashCmdList["MMMLOCK"](); noerr("cmd")
  local t = table.concat(CHAT, " | "); check(t:find("nothing saved or active", 1, true), "explains the empty case: " .. t)
  AddSaved("Molten Core", 3 * DAY); AddSaved("Totally Unknown Dungeon", DAY); CHAT = {}; SlashCmdList["MMMLOCK"](); noerr("cmd2")
  t = table.concat(CHAT, " | ")
  check(t:find("Molten Core", 1, true) and t:find("map icon greyed: Molten Core", 1, true), "lists the saved raid and the matching icon: " .. t)
  check(t:find("Totally Unknown Dungeon", 1, true), "lists names the addon does not know")
  W.saved = { { name = "Mystery Place", expire = CLOCK + DAY } }; CHAT = {}; SlashCmdList["MMMLOCK"]()
  t = table.concat(CHAT, " | "); check(t:find("none matches a map icon", 1, true), "tells you to report unmatched names: " .. t)
  return "diagnostic ok"
end
S.timers_cleaned_up = function()
  W.raidInfoMode = "event"; boot(); local core = ModernMapMarkersCore
  OpenMap("Eastern Kingdoms", "Burning Steppes"); check(core._scripts.OnUpdate, "timer runs while the map is open")
  CloseMap(); Tick(1, 2); check(core._scripts.OnUpdate == nil, "timer removed after the map closes (no per-frame cost)")
  Tick(5, 10); check(core.retryFrame == nil or core.retryFrame._scripts.OnUpdate == nil, "login retry frame removed after its last request")
  OpenMap("Eastern Kingdoms", "Burning Steppes"); check(core._scripts.OnUpdate, "and it restarts when the map opens again")
  return "no leftover per-frame work"
end
S.login_retries = function()
  W.raidInfoMode = "silent"; boot(); local r0 = W.requests; Tick(1, 7); local r1 = W.requests; Tick(1, 20); local r2 = W.requests
  check(r1 > r0 and r2 > r1, "login retries at ~6s and ~25s: " .. r0 .. " -> " .. r1 .. " -> " .. r2)
  return r0 .. " -> " .. r1 .. " -> " .. r2
end
S.saved_message_triggers_request = function()
  W.raidInfoMode = "silent"; boot(); Tick(40, 1); Tick(0.1, 5); local r0 = W.requests   -- let the scheduled login retries finish first
  FireEvent("CHAT_MSG_SYSTEM", "Welcome to the Barrens chat"); Tick(1, 10); check(W.requests == r0, "ordinary system messages do nothing")
  FireEvent("CHAT_MSG_SYSTEM", "You are now saved to this instance."); Tick(1, 10); check(W.requests > r0, "'saved' message asks the server again soon")
  return "reacts to saved/reset messages only"
end
S.localized_name = function()
  -- a German client reports German instance names; the data is keyed by English names
  W.raidInfoMode = "event"; AddSaved("Geschmolzener Kern", 2 * DAY); boot(); Tick(1, 1); OpenMap("Eastern Kingdoms", "Burning Steppes")
  local before = IsGrey(Marker("Molten Core")); return "unknown foreign name left alone (greyed=" .. tostring(before) .. ")"
end

-- ================================================================= active dungeon instances
local function openDM() OpenMap("Kalimdor", "Feralas") end
local function OpenZone(zone) for c, cn in ipairs({ "Kalimdor", "Eastern Kingdoms" }) do for _, z in ipairs({ GetMapZones(c) }) do if z == zone then OpenMap(cn, zone) return end end end error("zone not found: " .. zone) end
local function dmMarker() return Marker("Dire Maul - East") end
S.dungeon_enter_greys = function()
  boot(); openDM(); check(dmMarker() and not IsGrey(dmMarker()), "Dire Maul icon normal before entering")
  EnterDungeon("Dire Maul"); noerr("enter"); check(IsGrey(dmMarker()), "greyed once you are inside")
  check(IsGrey(Marker("Dire Maul - North")) and IsGrey(Marker("Dire Maul - West")), "all wings share the instance")
  Hover(dmMarker()); local ok; for _, l in ipairs(Tooltip()) do if l:find("Active instance", 1, true) then ok = l end end; check(ok, "tooltip says so: " .. table.concat(Tooltip(), " | "))
  return "greyed + tooltip"
end
S.dungeon_stays_after_leaving = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM(); noerr("x"); check(IsGrey(dmMarker()), "still active after you walk out"); return "stays active"
end
S.dungeon_reset_message_clears = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM(); check(IsGrey(dmMarker()), "active")
  FireEvent("CHAT_MSG_SYSTEM", "DireMaul has been reset."); noerr("x"); check(not IsGrey(dmMarker()), "'DireMaul has been reset.' (the exact line from the game) clears it")
  return "game's reset message clears it"
end
S.dungeon_reset_message_other_name_ignored = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM()
  FireEvent("CHAT_MSG_SYSTEM", "Scholomance has been reset."); check(IsGrey(dmMarker()), "another dungeon's reset leaves this one alone"); FireEvent("CHAT_MSG_SYSTEM", "hello"); check(IsGrey(dmMarker()))
  return "only the named dungeon is cleared"
end
S.dungeon_cannot_clear_while_inside = function()
  boot(); EnterDungeon("Dire Maul"); openDM(); FireEvent("CHAT_MSG_SYSTEM", "DireMaul has been reset."); check(IsGrey(dmMarker()), "an instance you are standing in cannot be reset")
  return "inside = stays"
end
S.dungeon_resetinstances_hook = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); EnterDungeon("Scholomance"); LeaveDungeon("Feralas"); openDM()
  check(IsGrey(dmMarker()), "Dire Maul active"); ResetInstances(); check(RESET_CALLS == 1, "the original ResetInstances still runs")
  FireEvent("CHAT_MSG_SYSTEM", "DireMaul has been reset."); FireEvent("CHAT_MSG_SYSTEM", "Scholomance has been reset."); Tick(1, 5); noerr("x")
  check(not IsGrey(dmMarker()), "cleared after a manual reset"); return "manual reset clears everything the game reset"
end
S.dungeon_reset_names_unknown_still_cleared = function()
  -- the game's names do not always match the map names: at least one 'has been reset' reply means the reset worked
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM(); ResetInstances(); FireEvent("CHAT_MSG_SYSTEM", "SomeInternalMapName has been reset."); Tick(1, 5)
  check(not IsGrey(dmMarker()), "cleared although the reply used another name"); return "robust to naming differences"
end
S.dungeon_reset_without_reply_keeps = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM(); ResetInstances(); Tick(1, 5)
  check(IsGrey(dmMarker()), "no reply from the game (e.g. not the party leader): nothing is assumed reset"); return "no reply = no change"
end
S.dungeon_reset_refused_keeps = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); EnterDungeon("Scholomance"); LeaveDungeon("Feralas"); openDM(); ResetInstances()
  FireEvent("CHAT_MSG_SYSTEM", "DireMaul has been reset."); FireEvent("CHAT_MSG_SYSTEM", "Cannot reset Scholomance.  There are players still inside the instance."); Tick(1, 5)
  OpenMap("Eastern Kingdoms", "Western Plaguelands"); local sch = Marker("Scholomance"); check(sch and IsGrey(sch), "the refused instance stays active")
  openDM(); check(not IsGrey(dmMarker()), "the one that was reset is cleared"); return "refusal respected"
end
S.dungeon_raids_unaffected = function()
  W.raidInfoMode = "event"; AddSaved("Molten Core", 3 * DAY); boot(); Tick(1, 1); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas")
  ResetInstances(); FireEvent("CHAT_MSG_SYSTEM", "DireMaul has been reset."); Tick(1, 5); OpenMap("Eastern Kingdoms", "Burning Steppes")
  check(IsGrey(Marker("Molten Core")), "a saved raid cannot be reset and stays greyed"); return "saved raid untouched by a reset"
end
S.dungeon_persists_across_relog = function()
  local NOW = time(); ModernMapMarkersDB = { instances = { ["Tester-TestRealm"] = { diremaul = { name = "Dire Maul", entered = NOW - 600, left = NOW - 300 } } } }
  boot(); openDM(); noerr("x"); check(IsGrey(dmMarker()), "remembered from the saved variables"); return "survives relog"
end
S.dungeon_expires_when_empty_for_an_hour = function()
  local NOW = time(); ModernMapMarkersDB = { instances = { ["Tester-TestRealm"] = { diremaul = { name = "Dire Maul", entered = NOW - 9000, left = NOW - 3700 } } } }
  boot(); openDM(); check(not IsGrey(dmMarker()), "an instance left over an hour ago is considered reset")
  EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM(); check(IsGrey(dmMarker()), "active again after a new entry"); Tick(1800, 1); openDM(); check(IsGrey(dmMarker()), "30 minutes later: still active"); Tick(1900, 1); OpenMap("Kalimdor", "Ashenvale"); openDM(); check(not IsGrey(dmMarker()), "an hour after leaving: expired")
  return "idle expiry"
end
S.dungeon_other_character_separate = function()
  local NOW = time(); ModernMapMarkersDB = { instances = { ["Someone Else-TestRealm"] = { diremaul = { name = "Dire Maul", entered = NOW - 600 } } } }
  boot(); openDM(); check(not IsGrey(dmMarker()), "another character's instances are not mine"); return "per character"
end
S.dungeon_zone_names = function()
  boot(); EnterDungeon("Stormwind City", nil, "none"); openDM(); check(not IsGrey(dmMarker()), "an ordinary zone is not a dungeon")
  EnterDungeon("Orgrimmar", nil, "none"); EnterDungeon("Molten Core", nil, "raid"); Tick(0.1, 2); noerr("x")
  local any; for _, m in ipairs(Markers()) do if IsGrey(m) then any = m.name end end; check(not any, "entering a raid does not create a dungeon entry: " .. tostring(any))
  EnterDungeon("Deadmines"); LeaveDungeon("Westfall"); OpenMap("Eastern Kingdoms", "Westfall"); check(IsGrey(Marker("The Deadmines")), "'Deadmines' matches 'The Deadmines'")
  return "zone matching"
end
S.dungeon_stock_client_no_instance_api = function()
  UseClassicInstanceAPI(false); boot(); EnterDungeon("Dire Maul"); openDM(); check(IsGrey(dmMarker()), "works from the zone name alone on a stock client")
  UseClassicInstanceAPI(false); return "stock client ok"
end
S.dungeon_classicapi_certainty = function()
  UseClassicInstanceAPI(true); boot()
  -- standing at the Dire Maul entrance outside: the sub-zone is named 'Dire Maul' but the instance type is "none"
  W_ZONE.real, W_ZONE.sub, W_ZONE.instanceType, W_ZONE.instanceName = "Feralas", "Dire Maul", "none", "Kalimdor"; FireEvent("ZONE_CHANGED_NEW_AREA"); openDM()
  check(not IsGrey(dmMarker()), "outside the instance: not active"); EnterDungeon("DireMaul", "Gordok Commons", "party"); check(IsGrey(dmMarker()), "inside (ClassicAPI says party): active, even with the internal name 'DireMaul'")
  UseClassicInstanceAPI(false); return "ClassicAPI instance type used"
end
S.dungeon_blackrock_spire_subzone = function()
  boot(); EnterDungeon("Blackrock Spire", "Upper Blackrock Spire"); LeaveDungeon("Burning Steppes"); OpenMap("Eastern Kingdoms", "Burning Steppes")
  check(IsGrey(Marker("Upper Blackrock Spire")) and not IsGrey(Marker("Lower Blackrock Spire")), "only the wing you entered"); return "shared instance name resolved by sub-zone"
end
S.dungeon_tracking_off_and_clear = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM(); check(IsGrey(dmMarker()), "tracked")
  SlashCmdList["MMMLOCK"]("dungeons off"); check(not IsGrey(dmMarker()), "tracking off: icon normal"); SlashCmdList["MMMLOCK"]("dungeons on"); check(IsGrey(dmMarker()), "tracking on again: remembered")
  SlashCmdList["MMMLOCK"]("clear"); check(not IsGrey(dmMarker()), "clear forgets everything"); SlashCmdList["MMMLOCK"]("dungeons maybe"); noerr("x")
  return "controls work"
end
S.dungeon_in_mmmlock_output = function()
  boot(); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); CHAT = {}; SlashCmdList["MMMLOCK"](""); noerr("cmd"); local t = table.concat(CHAT, " | ")
  check(t:find("active dungeon instance: Dire Maul", 1, true) and t:find("map icon greyed: Dire Maul - East", 1, true), "lists it: " .. t); return "diagnostic lists tracked dungeons"
end
S.dungeon_ij_pin = function()
  dofile(MM_DIR .. "/MarkerData.lua"); BuildZoneLists()
  local idx; for i, z in ipairs({ GetMapZones(2) }) do if z == "Burning Steppes" then idx = i end end
  InstallIJ(); IJDB.POI[1].MapZoneId = idx; boot(); EnterDungeon("Blackrock Depths"); LeaveDungeon("Burning Steppes"); OpenMap("Eastern Kingdoms", "Burning Steppes")
  local pin = IJ_ShowInstanceEntrancesIcon({ Name = "Blackrock Depths", Type = IJLib.InstanceType.Dungeon, MinLevel = 52, MaxLevel = 60 }) or IJPinFor("Blackrock Depths")
  check(pin and pin.icon._desat == true, "IJ pin for an active dungeon is greyed"); _G.this = pin; pin._scripts.OnEnter()
  local found; for _, l in ipairs(Tooltip()) do if l:find("Active instance", 1, true) then found = l end end; check(found, "IJ tooltip mentions it: " .. table.concat(Tooltip(), " | "))
  return "IJ pin ok"
end

S.stormwrought_exact_flow = function()
  boot(); EnterDungeon("Stormwrought Ruins"); noerr("enter"); OpenZone("Balor")
  check(IsGrey(Marker("Stormwrought Ruins")) and IsGrey(Marker("Stormwrought Ruins - Back Entrance")), "both entrances greyed while inside")
  LeaveDungeon("Balor"); OpenZone("Balor"); check(IsGrey(Marker("Stormwrought Ruins")), "still active after leaving")
  FireEvent("CHAT_MSG_SYSTEM", "Stormwrought Ruins has been reset"); noerr("reset")      -- the line exactly as the game printed it: no full stop
  check(not IsGrey(Marker("Stormwrought Ruins")) and not IsGrey(Marker("Stormwrought Ruins - Back Entrance")), "cleared by the reset message without a full stop")
  return "your exact reset line works"
end
S.dungeon_reset_message_variants = function()
  boot()
  local variants = { "DireMaul has been reset.", "DireMaul has been reset", "DireMaul has been reset. ", "Dire Maul has been reset" }
  local ok = {}
  for i, line in ipairs(variants) do
    EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); openDM()
    local before = IsGrey(dmMarker())
    FireEvent("CHAT_MSG_SYSTEM", line); noerr("variant " .. i)
    ok[#ok + 1] = i .. ":" .. tostring(before) .. ">" .. tostring(IsGrey(dmMarker()))
    check(before and not IsGrey(dmMarker()), "variant not recognised: '" .. line .. "'")
  end
  return table.concat(ok, " ")
end
S.limit_message_shows_on_dungeons = function()
  boot(); openDM(); check(not IsGrey(dmMarker()), "normal")
  Hover(dmMarker()); local before; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then before = l end end; Unhover(dmMarker()); check(not before, "no limit line by default")
  FireEvent("CHAT_MSG_SYSTEM", "You have entered too many instances recently."); noerr("msg")
  Hover(dmMarker()); local line; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then line = l end end; check(line, "limit line shown after the message: " .. table.concat(Tooltip(), " | ")); check(line:find("<=", 1, true), "marked as an upper bound (we did not see the entries)")
  check(not IsGrey(dmMarker()), "the icon itself is not greyed: you could still re-enter an instance you already have")
  Unhover(dmMarker()); Tick(3601, 1); Hover(dmMarker()); local after; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then after = l end end; check(not after, "gone an hour later")
  return line
end
S.limit_counted_from_own_entries = function()
  boot()
  local zones = { { "Dire Maul", "Feralas" }, { "Scholomance", "Western Plaguelands" }, { "Stratholme", "Eastern Plaguelands" }, { "Deadmines", "Westfall" }, { "Blackrock Depths", "Burning Steppes" } }
  for i, z in ipairs(zones) do EnterDungeon(z[1]); LeaveDungeon(z[2]); Tick(60, 1) end
  noerr("entries"); openDM(); Hover(dmMarker()); Unhover(dmMarker())
  OpenMap("Eastern Kingdoms", "Burning Steppes"); local m = Marker("Lower Blackrock Spire"); Hover(m); local line; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then line = l end end
  check(line and line:find("~", 1, true) and not line:find("<=", 1, true), "5 new instances in a short time -> limit shown from our own count: " .. table.concat(Tooltip(), " | "))
  Unhover(m); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); OpenMap("Eastern Kingdoms", "Burning Steppes"); Hover(m); local again; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then again = l end end
  check(again, "re-entering an instance you already have does not change the count"); Unhover(m)
  Tick(3700, 1); OpenMap("Eastern Kingdoms", "Burning Steppes"); Hover(m); local gone; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then gone = l end end; check(not gone, "slots free up after an hour")
  return line
end
S.limit_slot_frees_gradually = function()
  boot(); local zones = { { "Dire Maul", "Feralas" }, { "Scholomance", "Western Plaguelands" }, { "Stratholme", "Eastern Plaguelands" }, { "Deadmines", "Westfall" }, { "Blackrock Depths", "Burning Steppes" } }
  for i, z in ipairs(zones) do EnterDungeon(z[1]); LeaveDungeon(z[2]); Tick(600, 1) end      -- entries at t0, t0+600, ... t0+2400
  OpenMap("Eastern Kingdoms", "Burning Steppes"); local m = Marker("Lower Blackrock Spire")
  Hover(m); local a; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then a = l end end; Unhover(m)
  Tick(300, 1); OpenMap("Eastern Kingdoms", "Burning Steppes"); Hover(m); local b; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then b = l end end; Unhover(m)
  check(a and b and a ~= b, "the countdown moves: " .. tostring(a) .. " -> " .. tostring(b)); Tick(1900, 1); OpenMap("Eastern Kingdoms", "Burning Steppes"); Hover(m); local c; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then c = l end end
  check(not c, "once the oldest entry is an hour old a slot is free: " .. tostring(c)); return a .. " -> " .. b
end
S.limit_cleared_by_successful_entry = function()
  boot(); FireEvent("CHAT_MSG_SYSTEM", "You have entered too many instances recently."); EnterDungeon("Dire Maul"); LeaveDungeon("Feralas"); OpenMap("Eastern Kingdoms", "Burning Steppes")
  local m = Marker("Lower Blackrock Spire"); Hover(m); local line; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then line = l end end
  check(not line, "a successful entry proves the limit is not blocking: " .. tostring(line)); return "message cleared by a real entry"
end
S.limit_setting_and_persistence = function()
  local NOW = time(); ModernMapMarkersDB = { instanceLimit = 2, instanceLog = { ["Tester-TestRealm"] = { entries = { NOW - 1200, NOW - 600 } } } }
  boot(); OpenMap("Eastern Kingdoms", "Burning Steppes"); local m = Marker("Lower Blackrock Spire"); Hover(m); local line; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then line = l end end
  check(line and line:find("~", 1, true), "limit of 2 reached from the remembered entries: " .. table.concat(Tooltip(), " | ")); Unhover(m)
  SlashCmdList["MMMLOCK"]("limit 3"); check(ModernMapMarkersDB.instanceLimit == 3, "setting saved"); Hover(m); local after; for _, l in ipairs(Tooltip()) do if l:find("Instance limit", 1, true) then after = l end end; check(not after, "limit 3: not reached with 2 entries")
  SlashCmdList["MMMLOCK"]("limit 99"); check(ModernMapMarkersDB.instanceLimit == 3, "out of range refused"); SlashCmdList["MMMLOCK"]("limit abc"); noerr("x")
  return "limit command and persistence"
end
S.mmmlock_shows_zone_checks = function()
  UseClassicInstanceAPI(true); boot(); EnterDungeon("Stormwrought Ruins"); CHAT = {}; SlashCmdList["MMMLOCK"](""); noerr("cmd"); local t = table.concat(CHAT, " | ")
  check(t:find("last zone checks", 1, true) and t:find("zone='Stormwrought Ruins'", 1, true) and t:find("Stormwrought Ruins", 1, true), "shows what the game reported: " .. t)
  check(t:find("new instances entered in the last hour: 1", 1, true), "counts the entry: " .. t); UseClassicInstanceAPI(false); return "diagnostic shows the zone checks"
end
S.unknown_dungeon_is_reported_once = function()
  UseClassicInstanceAPI(true); boot(); CHAT = {}; EnterDungeon("Some Brand New Dungeon"); EnterDungeon("Some Brand New Dungeon"); noerr("x")
  local n = 0; for _, l in ipairs(CHAT) do if l:find("does not know", 1, true) then n = n + 1 end end
  check(n == 1, "told once about an unrecognised dungeon, not on every check: " .. n); check(table.concat(CHAT, "|"):find("Some Brand New Dungeon", 1, true), "names it"); UseClassicInstanceAPI(false); return "unknown dungeon reported once"
end
S.expired_instance_counts_as_new_entry = function()
  local NOW = time(); ModernMapMarkersDB = { instances = { ["Tester-TestRealm"] = { diremaul = { name = "Dire Maul", entered = NOW - 9000, left = NOW - 3700 } } }, instanceLog = { ["Tester-TestRealm"] = { entries = {} } } }
  boot(); EnterDungeon("Dire Maul"); noerr("x"); check(table.getn(ModernMapMarkersDB.instanceLog["Tester-TestRealm"].entries) == 1, "going back in after the instance expired is a new instance")
  return "expired -> counted as new"
end
local fn = S[want]
if not fn then print("RESULT|" .. want .. "|FAIL|unknown scenario") os.exit(2) end
local ok, res = pcall(fn); print("RESULT|" .. want .. "|" .. (ok and "PASS" or "FAIL") .. "|" .. tostring(res)); os.exit(ok and 0 or 1)

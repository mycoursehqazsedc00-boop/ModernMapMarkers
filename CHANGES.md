# ModernMapMarkers 2.6 – changes

## Fixed: saved-instance lockouts did not show (greyed icon, reset time)
The 2.5 feature read the saved-instance list in only two places: once at login, before the server had answered, and when the `UPDATE_INSTANCE_INFO` event arrived. If that event did not arrive when expected, the list stayed empty and reopening the map changed nothing.

- The list is now re-read when the map opens, on every later map update (zone change), every 20 s while the map is open (this also removes the grey when a lockout expires), after zoning, on `RAID_INSTANCE_WELCOME`, on "saved"/"reset" system messages, and when the event arrives.
- The addon asks the server (`RequestRaidInfo`) when the map opens (at most every 30 s), at login, and again 6 s and 25 s after login.
- The icon is now desaturated as well as dimmed (the dim alone was easy to miss); it falls back to dimming on clients without desaturation, and is fully restored when the lockout ends.
- InstanceJournal's entrance pins are greyed and show the reset time too.
- Instance names are matched ignoring case, punctuation and a leading "The" ("Deadmines" now matches "The Deadmines"), plus a few alternative names.
- A fixed countdown reported by the client keeps counting down instead of being reset on every re-read.
- New `/mmmlock` command: lists what the game reports as saved and which map icons matched.
- Timers only run while the map is open (or briefly after login); nothing runs per frame otherwise.

## Verification
- 17 scenarios pass (shipped 2.5 passes 7 of them).
- 300 random sessions (83,000 icon checks, event-driven and silent clients): 2.5 showed a wrong icon state 5,505 times in every session; 2.6 never.
- With nothing saved, all 369 map views (every zone of both continents, 9 filter/faction configurations) are identical to 2.5.

# ModernMapMarkers 2.5 – changes

All new features are optional and feature-detected; without the client mods the addon behaves exactly like 2.4.

## New
- **Live distance** in marker tooltips (yards, refreshes 2x/sec) – ClassicAPI `C_Map.GetPlayerMapPosition` + `GetMapWorldSize`. Shown when you are inside the marker's zone.
- **Ctrl+Left-click a marker -> map waypoint** (ClassicAPI `C_Map.SetUserWaypoint`). A cross pin is drawn on the world map with live distance; right-click the pin to clear it. Syncs with `USER_WAYPOINT_UPDATED`.
- **Saved-instance lockouts**: dungeons/raids you are saved to are greyed out and the tooltip shows the reset timer (stock 1.12 API).
- **Find Marker pulse**: choosing a marker in the Find list now pulses a ring on it for 8 seconds.
- Localized strings for the new UI (deDE, esES, ptBR, zhCN).

## Internal
- Tooltip logic moved to `MMM:ShowMarkerTooltip`; locale-safe uiMapID lookup by zone name (`MMM:GetMapIDForZone`).
- Lua 5.0-safe code throughout; all C_Map calls wrapped in `pcall`.
- TOC: version 2.5, `ClassicAPI` added to OptionalDeps.

## Audit fixes (second pass)
- Live-refresh timer only starts when ClassicAPI is present.
- uiMapID lookup is retried if the map list was empty on first call.
- Verified every ClassicAPI call against the ClassicAPI docs; scanned added code for Lua 5.0 hazards (no `#`, `%`, varargs).

## Not tested in-game
Written without a WoW client. Please test: Ctrl+click waypoint, distance line, lockout dimming, Find pulse. If a zone's waypoint fails, name matching between `GetMapZones()` and `C_Map.GetMapChildrenInfo` names is the first place to look.

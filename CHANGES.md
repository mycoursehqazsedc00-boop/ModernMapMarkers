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

# ModernMapMarkers for TurtleWoW

Places markers on the world map to show the locations of dungeons, raids, world bosses, boats, zeppelins and trams. Supports enUS, esES, deDE, ptBR and zhCN clients.

## Client mods

Only one client mod is used, and it is optional.

| Client mod | Used for | Without it |
|---|---|---|
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) (v1.12.7+) | `C_Map` (`GetMapChildrenInfo`, `GetFallbackWorldMapID`, `GetPlayerMapPosition`, `GetMapWorldSize`, `SetUserWaypoint`, `GetUserWaypoint`, `HasUserWaypoint`, `ClearUserWaypoint`, `GetUserWaypointPositionForMap`, `CanSetUserWaypointOnMap`), `UiMapPoint`, `GetInstanceInfo`, and the `USER_WAYPOINT_UPDATED` event | Live distance and waypoints are unavailable; zone and raid detection falls back to `GetRealZoneText()` and `RAID_INSTANCE_WELCOME`. Everything else works. |

Lockouts, reset tracking, Find highlight and all original features use only the stock 1.12 API.

## What was added / improved

### Version 2.9
- **Remaining `ResetInstances()` counter on dungeon tooltips** – hovering any dungeon marker on the world map (including `InstanceJournal` POI submap pins) shows `Resets left: X/5` along with the cooldown until the next slot (`Next: MM:SS`) and full reset (`Full CD: MM:SS`).
- **Full dungeon & un-saved raid reset tracking** –
  - Tracks 5-man dungeon entries via zone/instance checks and tracks un-saved raid entries (`CheckRaidEntry`), while ignoring raids you are already saved to (`GetLockout` / `GetSavedInstanceInfo`).
  - Counts manual `ResetInstances()` calls and chat-announced auto/leader resets (`"<name> has been reset."`) without double-counting already-tracked instances.
  - Detects **silent server auto-resets** on group transitions (`PARTY_MEMBERS_CHANGED` / `RAID_ROSTER_UPDATE` when joining a new party/raid or leaving a group to go solo), clearing un-saved active dungeon/raid state so the next entry is counted accurately even when no system chat line appears.
- **WTF persistence** – all reset timestamps, active un-saved instance state, and tracker UI settings are stored in `ModernMapMarkersDB` (`WTF\Account\<Account>\SavedVariables\ModernMapMarkers.lua`), surviving `WDB` auto-deletion on client launch.
- **Movable `[X/5 - CD]` HUD frame (`ModernMapMarkersResetFrame`)** – displays remaining resets (`X/5`) and the cooldown until all slots are restored to full (`Ready` or `MM:SS`), color-coded by availability, with a detailed hover tooltip. Drag with left-click to reposition.
- **Debug tracing & `/mmmreset` commands** – `/mmmreset` (toggle), `/mmmreset show|hide`, `/mmmreset lock`, `/mmmreset resetpos`, `/mmmreset status`, and `/mmmreset trace` (live chat tracing for state changes, raid/dungeon entries, silent group-change resets, and position saves).

### Version 2.8
- Recognises the game's reset message with or without a trailing period, displays hourly instance limit timers on dungeons, and adds `/mmmlock` diagnostics.

### Version 2.7
- Greys out active dungeon instances you are attached to until reset or 1-hour idle expiry.

### Version 2.6
- Fixed saved-raid lockouts (greyed icons and reset timers stay updated on map open, zone change, and server replies).

### Version 2.5
- Added live distance tooltips (`~N yd away`), `Ctrl+Left-click` map waypoints, and an 8-second Find Marker pulse highlight.

## Features

- **Dungeon, Raid and World Boss markers** – every instance entrance and world boss on the world map (42 dungeon, 14 raid and 12 world boss entries).
- **Transport markers** – boats, zeppelins and the Deeprun Tram.
- **Find Marker** – dropdown on the world map to jump to any dungeon, raid or world boss.
- **Marker filters** – toggle each marker type, plus a transport faction filter (All / Alliance / Horde), saved per account.
- **pfUI / pfQuest integration** – dropdowns are skinned when pfUI is present and repositioned when pfQuest is present.
- **InstanceJournal integration** – markers covered by InstanceJournal are hidden; left-click opens the instance map and right-click opens its journal page.
- **Localization** – zone and marker names translated for deDE, esES, ptBR and zhCN.
- **Performance** – dirty-checked map redraw, reusable marker pool, and throttled `OnUpdate` timers (0.5s on the reset HUD and hovered tooltips).

## Usage
| Action / Command | Result |
|---|---|
| Hover a marker | Name, level or faction, lockout timer, remaining resets & CD, distance |
| Left-click a marker | View instance map (InstanceJournal installed) |
| Right-click a marker | Open InstanceJournal page |
| Ctrl+Left-click a marker | Set a map waypoint (ClassicAPI) |
| Right-click the waypoint pin | Clear the waypoint |
| Drag `[5/5 - Ready]` frame | Move the reset tracker HUD (saved in WTF) |
| `/mmm` | Toggle world map dropdown menus |
| `/mmmreset` | Show/hide the movable `[X/5 - CD]` reset tracker frame |
| `/mmmreset lock` | Lock/unlock dragging on the reset tracker frame |
| `/mmmreset resetpos` | Reset the reset tracker frame to its default top-center position |
| `/mmmreset status` | Print current resets remaining, next/full CD, lock/hide/trace state |
| `/mmmreset trace` | Toggle live debug tracing in chat |
| `/mmmlock` | Show saved raids, tracked dungeons, hourly entries, and recent zone checks |
| `/mmmlock limit <1-50>` | Set hourly instance limit (default 5) |
| `/mmmlock dungeons on\|off` | Toggle dungeon-instance tracking (on by default) |
| `/mmmlock clear` | Forget all tracked dungeon instances and reset entries |

## Known limitations
- Distance and waypoints rely on matching zone names between `GetMapZones()` and ClassicAPI's map list.
- With InstanceJournal installed, markers that IJ covers are hidden, so the Find pulse cannot show on them.
- In Vanilla 1.12, 5-man dungeons do not expose a client-side `dungeonID` (`GetSavedInstanceInfo()` only reports saved raids). Dungeon tracking and silent group-change resets are inferred from zone/instance events, group state transitions, and server reset messages. The 1-hour idle expiry and 5-per-hour limit are defaults (`/mmmlock limit <n>` adjusts the cap; `/mmmlock clear` clears wrong entries).
- Inside Blackrock Spire the zone name is shared by Lower and Upper halves; the sub-zone decides which one is marked.

## Credits
Authors: tilr & Heallios<br>
InstanceJournal: [Walter Bennet](https://github.com/Arthur-Helias)<br>
2.5 changes: see `CHANGES.md`.

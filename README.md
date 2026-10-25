# ModernMapMarkers for TurtleWoW

Places markers on the world map to show the locations of dungeons, raids, world bosses, boats, zeppelins and trams. Supports enUS, esES, deDE, ptBR and zhCN clients.

**Version 2.7** – dungeon instances you are attached to are now greyed until reset; 2.6 fixed saved-raid lockouts (greyed icons and reset timers now appear and stay up to date); 2.5 added live distance, map waypoints and a Find-marker highlight. The new features that rely on a client mod switch themselves off if it is missing, so the addon still works on a stock 1.12 client.

## Features

### Original features
- **Dungeon, Raid and World Boss markers** – every instance entrance and world boss on the world map (42 dungeon, 14 raid and 12 world boss entries).
- **Transport markers** – boats, zeppelins and the Deeprun Tram.
- **Find Marker** – dropdown on the world map to jump to any dungeon, raid or world boss.
- **Marker filters** – toggle each marker type, plus a transport faction filter (All / Alliance / Horde). The faction defaults to your own on first load. Settings are saved per account.
- **`/mmm`** – shows or hides the dropdown menus. `/mmmzones` is a debug command that lists zones.
- **pfUI / pfQuest integration** – dropdowns are skinned when pfUI is present and repositioned when pfQuest is present.
- **InstanceJournal integration** – with InstanceJournal installed, markers it already covers are hidden, left-click opens the instance map and right-click opens its journal page.
- **Localization** – zone and marker names translated for deDE, esES, ptBR and zhCN.
- **Performance** – dirty-checked redraw (markers are rebuilt only when the viewed zone changes) and a reusable marker pool.

### New in 2.5
- **Live distance** – marker tooltips show `~N yd away`, refreshed twice a second while hovered. Shown only when you are in the marker's zone.
- **Map waypoint** – **Ctrl+Left-click** a marker to set a waypoint. A cross pin is drawn on the world map with its own live distance tooltip; **right-click the pin** to clear it.
- **Saved-instance lockouts** – dungeons and raids you are saved to are greyed out (desaturated and dimmed) and the tooltip shows the time until reset. Works on InstanceJournal's entrance pins too. In 2.6 the saved list is re-read when the map opens, on every zone change, every 20 seconds while the map is open, after zoning, and when the server answers, and it asks the server again whenever the map opens.
- **Active dungeon instances (2.7)** – five-man dungeons are not saved lockouts and never appear in Raid Info, so they are tracked separately: when you enter a dungeon its icon is greyed and the tooltip says "Active instance", and it stays that way after you leave until the instance is reset. Resetting clears it: the game's "<name> has been reset." message clears that dungeon, and a manual `ResetInstances()` clears every dungeon the game did not refuse to reset (saved raids cannot be reset and stay greyed). Remembered per character across relogs; an instance left for an hour is considered reset by the server.
- **Find Marker highlight** – the marker you picked pulses for 8 seconds.
- **New translated strings** for all supported locales.

## Client mods

Only one client mod is used, and it is optional.

| Client mod | Used for | Without it |
|---|---|---|
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) (v1.12.7) | `C_Map` (`GetMapChildrenInfo`, `GetFallbackWorldMapID`, `GetPlayerMapPosition`, `GetMapWorldSize`, `SetUserWaypoint`, `GetUserWaypoint`, `HasUserWaypoint`, `ClearUserWaypoint`, `GetUserWaypointPositionForMap`, `CanSetUserWaypointOnMap`), `UiMapPoint`, and the `USER_WAYPOINT_UPDATED` event | Live distance and waypoints are unavailable. Everything else works. |

Lockouts, Find highlight and all original features use only the stock 1.12 API. SuperWoW, Nampower, UnitXP_SP3, VanillaHelpers and WeirdUtils are **not** required.

## Installation
1. Download or clone this repository.
2. Put the `ModernMapMarkers` folder in `Interface\AddOns\`.
3. If you update an existing install, keep the existing `Textures` folder (see below).

The folder must contain a `Textures` directory with `dungeon.tga`, `raid.tga`, `worldboss.tga`, `boat.tga`, `zepp.tga`, `tram.tga`, `dungeon-highlight.tga` and `raid-highlight.tga`.

## Usage
| Action | Result |
|---|---|
| Hover a marker | Name, level or faction, lockout timer, distance |
| Left-click a marker | View instance map (InstanceJournal installed) |
| Right-click a marker | Open InstanceJournal page |
| Ctrl+Left-click a marker | Set a map waypoint (ClassicAPI) |
| Right-click the waypoint pin | Clear the waypoint |
| `/mmm` | Toggle dropdown menus |
| `/mmmlock` | Show the saved raids the game reports, the dungeon instances being tracked, and which map icons are greyed (use it if an icon does not grey out) |
| `/mmmlock dungeons on\|off` | Switch dungeon-instance tracking (on by default) |
| `/mmmlock clear` | Forget all tracked dungeon instances |

## Known limitations
- Distance and waypoints rely on matching zone names between `GetMapZones()` and ClassicAPI's map list. A custom zone ClassicAPI does not list simply gets no waypoint or distance.
- With InstanceJournal installed, markers that IJ covers are hidden, so the Find pulse cannot show on them.
- Lockout matching uses the instance name before " - " (for example "Dire Maul"), ignores case, punctuation and a leading "The", and knows a few alternative names. If an instance still does not grey out, run `/mmmlock` and report the names it lists.
- 2.5, 2.6 and 2.7 were tested on a mock client only, not in the real game; please report issues.
- Dungeon tracking is inferred from where you are (the zone name, plus ClassicAPI's instance type when available) and from the game's reset messages. The game exposes no list of dungeon instance IDs, and no data for the hourly "entered too many instances" limit, so neither is shown. The one-hour idle expiry is an assumption about the server; `/mmmlock clear` removes a wrong entry.
- Inside Blackrock Spire the zone name is shared by the Lower and Upper halves; the sub-zone decides which one is marked.

## Credits
Authors: tilr & Heallios<br>
InstanceJournal: [Walter Bennet](https://github.com/Arthur-Helias)<br>
2.5 changes: see `CHANGES.md`.

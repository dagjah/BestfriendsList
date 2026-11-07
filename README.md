# BestfriendsList

WoW Forever player watchlists and group notes (interface 16001).

## Installation and saved data

Exit WoW, then extract **BestfriendsList-install.zip** into `_forever_/Interface/AddOns/`, replacing included files. The ZIP contains the BestfriendsList addon plus small legacy data loaders in the previous folder names. Enable BestfriendsList and the legacy loaders for the first login. They load your previous saved variables without running the old addon code.

BestfriendsList uses **BestfriendsListDB**, falling back to previous databases when necessary. Player records, labels, faction filters and settings are preserved. Verify your lists, then log out once to save the new database before removing the legacy folders. Do not run unmodified older copies alongside this version. Party members need the updated addon to use its renamed sync prefix.

## Window and lists

Open `/bfl` or `/bestfriendslist`. `/kos` remains an alias for existing macros.

- **Ex-friend** is your opposing-faction watchlist. Its name is customizable in **Options**. It includes explicit personal targets and opposing-faction BFF players whose labels you selected in Filter.
- **Party List** groups your view and synced party members' targets under expandable member headers. Use individual toggles or **Expand all / Collapse all**. Search reveals matching names inside collapsed groups, then restores your saved toggles when cleared.
- **BFF List** shows tracked players of your character's faction and warns when they are in your party or raid.
- **Recent** shows the ten most recent unique people you grouped with, so you can add them after they leave.

Use **Add player** to enter a full **Firstname Surname** and choose Alliance / Horde / Unknown. The default faction is your own for BFF and the opposing faction for your watchlist. **Add target** captures your selected player’s readable details and automatically chooses BFF for the same faction or your watchlist for the opposing faction, regardless of the open tab. Names use WoW class colors, show level inline, and provide full details on hover. Matching ignores case and repeated spaces.

An X removes your personal entry. A checkmark copies another member's target or a dynamically included BFF target into your personal watchlist. Removing an explicit copy does not remove another member's entry or disable a BFF-label filter that still includes that name. BFF rows keep the order **X → label → name (level)**.

Your lists and settings are account-wide across characters on this installation. They save on logout/reload.

## Options and custom list name

Open **Options**, enter a new personal-list name and save. The tab, player-count heading, add/remove tooltips, and nearby warnings use that name. Saved custom names are preserved; hover the tab to read a name that is wider than the tab, or shorten it in Options.

The name must fit the tab and cannot be blank or contain line breaks or formatting codes. Your custom name is shared by your characters.

Options also contains **Edit BFF labels**. The custom name applies when you save options. Label editing has its own Save labels button.

## Alert wording

For a BFF group member with the label Ninja:

```
Ninja: King Arthur joined the party
```

Without a label:

```
King Arthur joined the party
```

Raids use “joined the raid.” These notices also appear when you join an existing group, reload while grouped, or add a player already in your group. Repeated roster updates do not repeat the notice; leaving and rejoining permits a fresh one.

For nearby watchlist targets, the warning uses your custom list name:

```
Ex-friend: King Arthur - Ninja
Ex-friend: King Arthur
```

Chat and screen alerts use the same wording, without an extra BFF or addon-name prefix. Tooltips still show **Label: Ninja**. Sound is optional. Nearby repeats have a 30-second per-player cooldown across all sources.

## Personal BFF labels

Each account has four customizable labels, independent of other addon users’ choices. The defaults are **Avoid, Ninja, Rude, Tank**. Open **Options → Edit BFF labels** or `/bfl bff labels`. Names must be distinct and 1–24 characters long. Click a BFF row's label button to cycle through the four labels and No label. Each entry has at most one label.

Renaming a label updates existing assignments and preserves selected filters. Labels appear in group notices, nearby warnings when relevant, and tooltips.

```
/bfl bff label 1 Firstname Surname
/bfl bff label 0 Firstname Surname
```

Use 1–4 to assign a label, or 0 to clear it.

## Faction and label filters

**Filter**, to the left of your personal list's player count, chooses which opposing-faction BFF labels to include in your watchlist. Filter is also available on the BFF tab and through `/bfl filter`. Selections are saved separately for Alliance and Horde, shared by characters of the same faction.

Example: add a Horde player to BFF while playing Horde and label them Ninja. On Alliance, select Ninja in Filter. The same saved player appears in your watchlist and can trigger nearby warnings. They remain a same-faction BFF when playing Horde. No record is moved, deleted or duplicated by the filter.

Normal mode shows your faction in BFF and the opposing faction in personal/party watchlists. Faction is learned from readable target/nameplate/group data or chosen during manual entry. Older entries with unknown faction remain saved but are hidden by default. Use **Include entries whose faction is still unknown** to review them; `[?]` marks these entries. Add a name again with the correct faction, target the player, or use:

```
/bfl faction Horde Firstname Surname
/bfl faction Alliance Firstname Surname
```

Unknown-faction BFF players are never automatically treated as opposing-faction label matches. Watchlist detection always uses opposing-faction rules. BFF last-grouped history stays separate from opposing-faction sightings.

## Party synchronization

Everyone needs the updated addon. Joining/reloading in a party and changing your explicit personal list starts automatic sync. A periodic refresh recovers missed updates; **Resync** or `/bfl sync` requests it immediately.

Only currently eligible explicit personal names, class, level and faction are transmitted. BFF records, labels, filter choices, local sightings and custom list names stay private. Dynamically included BFF targets are not shared unless you explicitly copy them into your watchlist. Received lists are not forwarded.

Each sync updates the sender's list, including removals. Received party lists are temporary: leaving, removing a member or converting to a raid clears the affected data. Raid/guild/whisper channels are not used for sync. The list view reports how many members' lists have arrived, including empty lists. Each member can share up to 1,000 entries.

Sync exchanges lists, not live sightings. A nearby warning requires your client to detect the player.

## Commands

- `/bfl`: open the window.
- `/bfl options`: rename your Ex-friend list and edit BFF labels.
- `/bfl recent`: open the last ten recorded group members.
- `/bfl add target` (or `/bfl add`): add your current player target to BFF when same faction, or your watchlist when opposing faction.
- `/bfl add Firstname Surname`: add a typed name to your personal watchlist.
- `/bfl remove Firstname Surname`: remove an explicit personal entry.
- `/bfl bff`: open BFF List.
- `/bfl bff add` or `/bfl bff add Firstname Surname`: add to BFF.
- `/bfl bff remove Firstname Surname`: remove from BFF.
- `/bfl bff labels`: edit four personal labels.
- `/bfl bff label 1 Firstname Surname`: assign a label (0 clears).
- `/bfl filter`: configure label/faction filters.
- `/bfl faction Horde Firstname Surname`: correct a saved faction; Alliance is also supported.
- `/bfl sync`: request party snapshots.
- `/bfl scan`: check exposed units and group membership.
- `/bfl help`: command help and a class-color legend.

For one action-bar macro that works for either faction, use `/bfl add target`. `/bfl add` is shorthand; `/bfl bff add` explicitly adds to BFF. Existing `/kos` macros continue to work.

## Detection

The addon checks exposed nameplates, target and mouseover on events and every two seconds. Enable the appropriate nameplates for nearby detection. Hidden/stealthed players, units outside exposed visibility, and restricted unit data cannot reliably be detected. Unknown class/level information preserves known values. BFF membership checks include party and raid rosters regardless of distance. No targeting, attacking or public-chat accusations are automated.

After an update, restart WoW if addon files or manifests changed.

## Recent group members

The **Recent** tab records party and raid members automatically while the addon is running, excluding your own character. It keeps up to ten unique full names, most recently encountered/rejoined first. Repeated roster updates do not reorder existing members or displace older history. Class, level, faction and last-grouped time/zone update when readable. The stored zone is your zone at that check, not the other player’s exact location. History is saved account-wide across reloads and character changes.

Click a recent player's checkmark to add them to **BFF List** if they share your current character's faction, or to **Ex-friend** (your custom watchlist name) if they are opposing faction. Their saved details are copied, so targeting them again is unnecessary. If their faction is unknown, a prefilled dialog asks you to choose it. Existing personal entries show X instead; it removes your personal entry without erasing the recent-history row. Recently added BFF entries also expose their label button for immediate categorization.

Recent is searchable, includes both factions, and does not need anyone else to have the addon installed. History itself triggers no alerts and is not transmitted to the party. Normal BFF/nearby alerts apply only after you choose to add someone to a list. The addon starts recording when this update runs and cannot reconstruct older groups it never observed. Current members can be recorded when you log in/reload in a group; players first observed together have no reliably known relative join order.

## Right-click player menus

Right-click a player's name or row in **BFF List** or **Recent** to open WoW's normal player menu.

WoW controls which actions are shown/enabled for that character. Saved Recent entries can open the menu after a player leaves, but some actions require the player to be online, nearby or currently in your group. Clicking X, a checkmark or a label keeps its existing left-click behavior. No action is performed automatically by opening the menu.

## License

BestfriendsList is distributed under the [MIT License](LICENSE).

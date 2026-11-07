# BestfriendsList

Keep track of players you want to remember in WoW Forever, with personal notes, group alerts and faction-aware watchlists.

## Features

- **Ex-friend:** an opposing-faction watchlist with nearby alerts and a customizable list name.
- **BFF List:** same-faction player notes, with alerts when a listed player is in your party or raid.
- **Custom labels:** four editable labels, initially Avoid, Ninja, Rude and Tank. Labels appear in relevant alerts.
- **Party List:** automatically share personal watchlists with party members using the addon. Expand or collapse each member's list, search names, and copy entries into your own list.
- **Recent:** remembers your last ten unique party/raid companions so you can add someone after they leave.
- **Account-wide storage:** keep the same saved records across your characters, with views based on your current faction.
- **Quick controls:** class-colored names, levels, tooltips, compact rows, and native right-click menus in BFF and Recent.

## Getting started

Open the window with `/bfl`.

Target a player and use **Add target**, or make a macro:

```
/bfl add target
```

Same-faction players go to BFF; opposing-faction players go to your watchlist. Use **Add player** to enter a full first name and surname manually.

Use **Options** to rename Ex-friend or edit your labels. Click a BFF player's label to change it. **Filter** can include opposing-faction BFF records with selected labels in your watchlist when playing another faction.

Party sharing works automatically when party members have the addon. It does not sync raid lists or share your private BFF labels or recent history.

## Detection and compatibility

Designed for **WoW Forever, Interface 16001**. Nearby alerts depend on players exposed through your nameplates, target or mouseover; the addon cannot reliably detect hidden or out-of-range players. BFF group alerts use the party/raid roster. The addon does not automatically target or attack players.

Recent history begins when the addon observes your group. Right-click menu actions depend on the player's status and the client's available functionality.

Use `/bfl help` for commands and the class-color legend.

[Source and full usage guide](https://github.com/dagjah/BestfriendsList) · [Report an issue](https://github.com/dagjah/BestfriendsList/issues)

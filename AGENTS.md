# Development guide

## Project

BestfriendsList is a WoW Forever addon (Interface 16001). Keep README.md focused on installation, features, commands and user-facing behavior. Put development guidance here and regression-check details in tests/README.md.

## Files and load order

The addon loads Lists.lua, Factions.lua, PartySync.lua, then BestfriendsList.lua. Modules share the private BFL namespace supplied through addon varargs. Lists.lua owns saved data and list operations; Factions.lua owns faction eligibility and filters; PartySync.lua owns party transport; BestfriendsList.lua owns UI, commands, detection and alerts.

The active development workspace is /home/dagjah/Projects/BestfriendsList. The WoW AddOns copy is a separate installed copy and is not updated automatically. BestfriendsList.toc is the canonical manifest. KillList.toc supports installations using the original folder name. Keep both runtime file lists and versions consistent. Do not write outside the authorized workspace.

## Behavior to preserve

- Forever names are first name plus surname. The second UnitName return is a surname, not a realm. Preserve full names and normalize matching through BFL.Name.
- Data is account-wide in BestfriendsListDB. Preserve migration fallbacks from KillOnSightDB, KillOnSiteDB and KillListDB, including custom settings and labels.
- The default personal watchlist title is Ex-friend. Default labels are Avoid, Ninja, Rude and Tank; never overwrite customized labels.
- Same-faction target additions go to BFF; opposite-faction additions go to the personal watchlist, regardless of the current tab. Unknown factions require explicit handling rather than guesses.
- BFF displays same-faction entries and alerts for party/raid membership. The watchlist displays opposing-faction entries and selected opposing-faction BFF label matches. Label filters are saved per viewer faction.
- Party sync is party-only, never raid/guild/whisper. Share only eligible explicit personal names, class, level and faction. Keep BFF records, labels, filters, GUIDs, recent history and sightings private. Do not forward received lists.
- Recent stores at most ten unique group members, excluding self. Polling must not reorder present members or continually reinsert evicted current members.
- Native right-click menus belong to BFF and Recent rows. Preserve the full name, use DEFAULT_CHAT_FRAME for chat actions, and never reuse stale unit tokens. Respect unreadable/secret API values.
- Preserve the shared EditBox placeholder callback; consumers use onTextChanged rather than replacing its OnTextChanged script.
- No demo parties, same-faction detection overrides, preview alerts or self-test commands in the shipped addon.

## Verification

Run `lua tests/run.lua` with Lua 5.1+ when a runtime is available. The suite covers data/faction behavior, the actual shared field helper and the native menu helper. Do not claim tests ran when only static checks were possible.

For relevant changes, check behavior in WoW: full-name identity, faction switching, labels and alert wording, group joins/leaves, duplicate suppression, party delivery with a second client, right-click menus, and persistence after reload. UI mocks cannot verify the live native menu or font measurements.

## Packaging

BestfriendsList-install.zip is the installable artifact. Rebuild it after changes to shipped files. Include exactly:

- BestfriendsList/Lists.lua
- BestfriendsList/Factions.lua
- BestfriendsList/PartySync.lua
- BestfriendsList/BestfriendsList.lua
- BestfriendsList/BestfriendsList.toc
- BestfriendsList/README.md
- BestfriendsList/LICENSE
- KillOnSight/KillOnSight.toc
- KillOnSite/KillOnSite.toc
- KillList/KillList.toc

The three legacy ZIP manifests are data-only loaders declaring their respective old saved-variable globals, with no Lua files. Do not copy the checkout's runtime KillList.toc into the legacy ZIP folder. scripts/package.py generates these loader manifests from source metadata; never depend on an existing ZIP to build a release.

Exclude AGENTS.md, tests, development tools and repository metadata from the install ZIP and runtime manifests. Verify archive integrity and that packaged runtime files match the checkout. README.md must not include these developer instructions or a copy of AGENTS.md.

## CI and publishing

GitHub Actions checks syntax and regressions on Lua 5.1/5.4 and tests the Python package builder. Release tags must match both manifests; CI gates GitHub releases and configured CurseForge uploads. See docs/RELEASING.md for setup, credentials, license selection and release steps. Keep secrets out of source and logs. Do not claim live publication or client validation unless performed.

The GitHub repository is https://github.com/dagjah/BestfriendsList. The manual CurseForge configuration-check workflow only reads supported game versions; it must never upload or require RELEASE_TAG. API credentials belong in the curseforge environment secret CF_API_TOKEN.

The project uses MIT (LICENSE), copyright 2026 dagjah. Include LICENSE in every release ZIP. The CurseForge project is https://legacy.curseforge.com/wow/addons/bestfriendslist; its project ID is 1788392, supplied by the author. Workflow uploads default to that ID; CF_PROJECT_ID can override it.

The author reports the manually uploaded 2.4.0 package works in-game (2026-11-07) and chose the sole Forever version option. Do not claim detailed test coverage or approval status. The release workflow skips CurseForge uploads for v2.4.0 to avoid duplicating that file. scripts/connect-github.sh is the normal-terminal first-push helper; it never force-pushes or tags releases.

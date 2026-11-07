# GitHub and CurseForge releases

## Repository setup

The repository is [dagjah/BestfriendsList](https://github.com/dagjah/BestfriendsList). This workspace's Git metadata is read-only and the session cannot resolve github.com, so no remote connection or push has been completed here.

For the first upload, run this in your normal WSL terminal (not the restricted Codex shell). It checks the remote, commits project files and pushes main. It never force-pushes or creates release tags:

```sh
bash ~/Projects/BestfriendsList/scripts/connect-github.sh
```

The equivalent manual steps for an empty repository are:

```sh
cd ~/Projects/BestfriendsList
git init -b main
git remote add origin https://github.com/dagjah/BestfriendsList.git
git add .github .gitattributes .gitignore AGENTS.md BestfriendsList.lua BestfriendsList.toc KillList.toc Lists.lua Factions.lua PartySync.lua README.md CHANGELOG.md LICENSE assets docs scripts tests
git diff --cached --stat
git commit -m "Prepare BestfriendsList and release automation"
git push -u origin main
```

If origin already exists, check `git remote -v` before changing it. If Git requests your identity, configure your preferred Git author name and email locally and retry the commit. Authenticate using your usual GitHub credentials/credential manager, never by embedding a token in the remote URL. If the remote already has commits, stop and integrate its history rather than force-pushing.

After uploading, open [Actions](https://github.com/dagjah/BestfriendsList/actions) and confirm Checks passes. Enable Actions if prompted and protect the default branch with the Checks workflow. Generated ZIPs, local agent settings and credentials are ignored. Keep README.md user-facing.

The project uses **MIT**, selected by the author, with copyright 2026 dagjah. LICENSE is included in each install ZIP. The CurseForge project is https://legacy.curseforge.com/wow/addons/bestfriendslist and also uses MIT. Its project ID is **1788392**, supplied by the author and configured as the workflow default. Supported game-version IDs still need verification. Add screenshots as needed; the logo is assets/branding/bestfriendslist-logo.png.

## Checks and local builds

Run:

```sh
lua5.1 tests/run.lua
lua5.4 tests/run.lua
python3 -m unittest discover -s tests -p 'test_*.py'
python3 scripts/package.py
```

CI checks Lua syntax, executes regressions on Lua 5.1 and 5.4, tests packaging, and uploads the verified ZIP as a workflow artifact. Packages use a fixed file allowlist and include the three data-only migration loaders. They exclude AGENTS.md, tests and development tooling. The package is reproducible from the same source; no old ZIP is needed.

The author reports testing the uploaded 2.4.0 package successfully in WoW Forever on 2026-11-07 and selecting the sole Forever game-version option. Exact client build, CurseForge version ID, individual test coverage and moderation status have not been independently verified. Repeat relevant in-game checks for future changes. Automated checks cannot verify live Forever APIs, party transport or native player menus.

## CurseForge setup

1. Open the existing [BestfriendsList project](https://legacy.curseforge.com/wow/addons/bestfriendslist) in the Author Portal. Its Project ID is **1788392**. Complete its required project details; docs/CURSEFORGE_DESCRIPTION.md provides draft description text. Set the source URL to https://github.com/dagjah/BestfriendsList and issues URL to https://github.com/dagjah/BestfriendsList/issues. The code targets Forever Interface 16001; confirm CurseForge offers the correct game version and accepts the project. Do not select an unrelated Retail/Classic version to bypass this requirement. GitHub ZIP releases remain available independently.
2. Set repository Actions variable `CF_GAME_VERSION_IDS` (comma-separated numeric IDs from the WoW Upload API's `/api/game/versions` endpoint). These are CurseForge IDs, not the TOC interface number. The workflow defaults to project **1788392**; optional repository variable `CF_PROJECT_ID` can override it. Keep `CF_GAME_VERSION_IDS` at repository scope so the job condition can see it.
3. Create the GitHub Actions environment `curseforge`. Store an author upload token there as secret `CF_API_TOKEN`; generate it through CurseForge's author API-token page. This is the Upload API token, not a general third-party API key. Environment protection/reviewers are optional.

Before creating a release tag, run **CurseForge configuration check** from the repository's Actions page. With only the token configured, it lists available game-version IDs without uploading anything. After setting the game-version repository variable, run it again to verify those IDs exist. Inspect the returned version names to confirm actual Forever compatibility; the lookup cannot verify project ownership, upload permissions or in-game compatibility. The release upload also checks the selected IDs before sending the ZIP.

The upload uses the [official CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-api), including its game-version IDs and multipart upload fields. CurseForge's own approval process still applies. If the game-version variable is absent, the workflow skips CurseForge and publishes only on GitHub. If configured but the token is missing or upload fails, the CurseForge job fails visibly.

## Publish a version

Version **2.4.0 has already been uploaded manually to CurseForge**. Its GitHub tag can create the matching GitHub release, but the workflow deliberately skips CurseForge for that tag. Start automatic CurseForge uploads with a later version to avoid submitting 2.4.0 twice. Do not replace or reupload the submitted file merely to enable automation.

1. Update Version in both BestfriendsList.toc and KillList.toc, and replace CHANGELOG.md with notes for that release.
2. Run checks and validate in-game, then commit and push.
3. Create and push a tag matching the manifest exactly, such as `v2.4.0`:

```sh
git tag -a v2.4.0 -m 'BestfriendsList 2.4.0'
git push origin v2.4.0
```

A tag runs checks first, builds the install ZIP, creates a GitHub release with CHANGELOG.md notes, then uploads the same reproducible package to CurseForge when configured. Only stable tags matching `v` plus the exact manifest version are supported. Do not move published tags; use a new version for corrections.

If CurseForge fails after GitHub succeeds, inspect the project files for an accepted upload before retrying. Re-run only the failed job after fixing configuration; re-running the successful GitHub job would attempt to create the same release again. Uploads are not automatically retried because a timeout could follow a successful server-side upload.

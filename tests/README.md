# Developer regression checks

From the addon root, run `lua tests/run.lua` using Lua 5.1 or newer.

The data checks load the real model and faction modules. The field checks execute the real shared EditBox helper against a small UI mock, covering search callbacks, rename callbacks, typing, clearing, and programmatic text population. The menu checks exercise the actual native-menu helper with mocked client APIs. These checks do not verify font rendering or the live WoW client.

These files are excluded from the release manifest and installation ZIP. No test/demo commands or runtime are loaded by the addon.

Run `python3 -m unittest discover -s tests -p 'test_*.py'` for reproducible packaging, migration loader boundaries, release-tag validation and mocked CurseForge upload requests. Upload tests never contact CurseForge. GitHub Actions runs these checks and Lua regressions automatically.

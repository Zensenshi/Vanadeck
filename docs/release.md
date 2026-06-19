# Release Checklist

Before publishing builds:

- Replace the default Android application ID with an identifier you control before distributing builds.
- Configure private release signing outside the repository; do not commit keystores, provisioning profiles, passwords, or signing property files.
- Re-run `flutter analyze`, `flutter test`, and an Android debug or release build before tagging a release.
- Syntax-check the addon with LuaJIT when available, for example `luajit -e 'assert(loadfile("vanadeck/vanadeck.lua"))'`.
- Confirm the repository does not include local resource folders, game files, screenshots with private character/account details, generated build outputs, Ashita runtime files, or third-party addon files.


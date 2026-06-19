# Release Checklist

Before publishing builds:

- Replace the default Android application ID with an identifier you control before distributing builds.
- Configure private release signing outside the repository; do not commit keystores, provisioning profiles, passwords, or signing property files.
- Re-run `flutter analyze`, `flutter test`, and an Android debug or release build before tagging a release.
- Syntax-check the addon with LuaJIT when available, for example `luajit -e 'assert(loadfile("vanadeck/vanadeck.lua"))'`.
- Confirm the repository does not include local resource folders, game files, screenshots with private character/account details, generated build outputs, Ashita runtime files, or third-party addon files.

## GitHub Release Build

The repository includes a manual Android release workflow at `.github/workflows/android-release.yml`.

To publish the first GitHub release build:

1. Open the repository on GitHub.
2. Go to Actions -> Android release build -> Run workflow.
3. Keep the defaults for the first build:
   - `tag`: `v0.1.0`
   - `build_name`: `0.1.0`
   - `build_number`: `1`
   - `publish_release`: enabled
4. Download the APK from the workflow artifact or from the generated GitHub Release.

Pushing a `v*` tag also runs the same workflow and publishes the APK to a release for that tag.

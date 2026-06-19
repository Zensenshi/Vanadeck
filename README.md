# VanaDeck

VanaDeck is an unofficial Android companion app for FFXI running in Winlator and pairs with the included Ashita v4 addon to show live party status, chat, macros, maps, and app customization tools in a companion interface.

This project includes the original VanaDeck addon source, but does not include FFXI game files, Ashita source or binaries, map packs, DAT files, icon packs, or other third-party game resources. Users should provide their own local resources through the app settings where supported.

## Features

- Live player and party status from the included Ashita v4 addon.
- Buff and debuff display with optional local status icon resources.
- Mini-map display using user-selected Mappy map folders.
- Macro slot display with companion controls for in-game macro pages.
- Chat composer and chat log view.
- Theme color, OLED black mode, background image, and chat typography settings.

## Requirements

- Ashita v4 setup in your Winlator container.
- The included VanaDeck Ashita addon.
- The VanaDeck Android app.

## Getting Started

### Android app

Download and install the latest VanaDeck APK from the GitHub Releases page when builds are published.

### Ashita v4 addon

Copy the root `vanadeck/` folder from this repository into your Ashita v4 `addons/` folder. The copied folder should contain `vanadeck.lua`.

Launch Ashita v4, then load the addon in game:

```txt
/addon load vanadeck
```

To load VanaDeck automatically, add the same command to your Ashita startup script or profile.

The current bridge uses `127.0.0.1:8080` and expects newline-delimited JSON status updates from the addon. That means the app and addon must be running in the same local environment unless you change the bridge configuration in source.

## Optional Resources

VanaDeck does not bundle maps, status icons, DAT files, or extracted game assets. You can point the app at local resources you provide:

- Mappy maps can be loaded from a folder containing `map.ini` and map images. The maps used while developing VanaDeck came from [KenshiDRK's Mappy version](https://github.com/KenshiDRK/mappy--Kenshi-Version).
- Status icons can be loaded from a user-selected resource folder. Name icon PNGs by status ID, for example `33.png` or `40.png`. The icons used while developing VanaDeck came from [KenshiDRK's XiView project](https://github.com/KenshiDRK/XiView).
- Background images can be selected through the app settings.

Follow each resource project's license and installation instructions. Do not commit game files, DAT files, map packs, icon packs, third-party binaries, or private local resource folders to this repository.

## Building from Source

VanaDeck is built with Flutter. You only need Flutter if you want to build or modify the Android app yourself.

```sh
flutter pub get
flutter test
flutter build apk
```

Release APKs can also be built from GitHub Actions with the manual
`Android release build` workflow. See [docs/release.md](docs/release.md) for
the release checklist and first-build steps.

## Responsible Use

This project is intended as a companion display and convenience interface for user-driven play. It should not be used for unattended gameplay, automation, or behavior that violates FINAL FANTASY XI rules or community standards. Review Square Enix's current user agreement and prohibited activities before using or modifying addon-driven game input features.

## Credits

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for acknowledgements and licensing notes.

Built with assistance from Codex.

## Disclaimer

This is an unofficial fan project. It is not affiliated with, sponsored by, or endorsed by Square Enix, Ashita, Windower, or the FINAL FANTASY XI team.

FINAL FANTASY XI and related names are trademarks or registered trademarks of Square Enix Holdings Co., Ltd. or its affiliates.

## License

The original source code in this repository is released under the MIT License. See [LICENSE](LICENSE).

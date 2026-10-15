# LockWidgets

Widgets for the macOS lock screen: clock, weather, calendar, now playing, live lyrics and battery.

LockWidgets lives in the menu bar. When you lock your Mac, it draws your widgets above the lock screen using [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow).

## Install

1. Download `LockWidgets-<version>.dmg` from [Releases](../../releases).
2. Open it and drag **LockWidgets** into **Applications**.
3. Open LockWidgets. Settings open on first launch; afterwards use the grid icon in the menu bar.

Requires macOS 15 or later.

## Widgets

| Widget | Source |
| --- | --- |
| Clock | System time, 12 or 24 hour |
| Weather | [Open-Meteo](https://open-meteo.com), from your location or a city you choose |
| Up Next | Your calendars, via EventKit |
| Now Playing | Apple Music and Spotify |
| Live Lyrics | Time-synced lyrics from [LRCLIB](https://lrclib.net) |
| Battery | Charge and time remaining |

Each widget can be shown or hidden and reordered. Position, size, spacing, card style and corner radius are set in **Settings → Layout** and **Appearance**.

## Permissions

- **Calendar**: for Up Next.
- **Location**: for local weather. Not needed if you set a city.
- **Automation**: to read the current song from Music or Spotify. LockWidgets only talks to a player that is already open.

## Development

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open LockWidgets.xcodeproj
```

Run `xcodegen generate` again after adding files outside Xcode.

### Releasing

```sh
scripts/release.sh            # signed DMG in dist/
scripts/release.sh --publish  # also create or update the GitHub release
```

The script notarizes the DMG when a keychain profile named `lockwidgets-notary` exists:

```sh
xcrun notarytool store-credentials lockwidgets-notary --apple-id <apple-id> --team-id 4T4AXT6P7X
```

The app icon is drawn by `scripts/make-icon.swift`.

# LockWidgets

Widgets for the macOS lock screen: clock, weather, calendar, now playing, live lyrics and battery.

LockWidgets lives in the menu bar. When you lock your Mac, it draws your widgets above the lock screen using [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow).

## Install

1. Download `LockWidgets-<version>.dmg` from [Releases](../../releases).
2. Open it and drag **LockWidgets** into **Applications**.
3. Open LockWidgets. The Setup Guide runs on first launch. Afterwards, open the app again or use its menu bar icon.

Requires macOS 15 or later.

## Widgets

| Widget | Styles | Source |
| --- | --- | --- |
| Weather | Current, Hourly, Five Day | [Open-Meteo](https://open-meteo.com) |
| Earth | Globe with live day and night | Apple Maps satellite imagery |
| News | Headlines | Any RSS or Atom feed |
| Stock Ticker | Watchlist, Spotlight | Yahoo Finance |
| Now Playing | Player, Artwork | Apple Music and Spotify |
| Photos | Photo, Framed | Photos library or a folder |
| Live Lyrics | Lyrics | [LRCLIB](https://lrclib.net) |
| Calendar | Date, Monthly, Up Next | Your calendars |
| Clock | Digital, Analog, World Clock | System time |
| Countdown | Days, Flip | Your date |
| Pomodoro | Ring | Built in |
| Stopwatch | Digits | Built in |
| Reminders | List | Your reminders |
| Battery | Ring, Bar | System |
| System | Gauges, Monitor | CPU, memory, network, disk |
| Daily Brief | Brief | Weather, calendar, reminders, news |
| Sticky Note | Paper, Glass | Your text |

Widgets come in Small, Medium, Wide, Ultra Wide and Large sizes. Drag them anywhere in **Layout Studio**, start from a design in **Layout Gallery**, and set the card style in **Appearance**.

## Permissions

- **Calendar**: for Up Next.
- **Location**: for local weather. Not needed if you set a city.
- **Reminders**: for the Reminders widget.
- **Photos**: for the Photos widget, unless you pick a folder.
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

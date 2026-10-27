# Race Day Ready — Open Me First

A packing list, outfit planner and pre-trip to-do list for race weekends, shared between everyone on the trip through iCloud. **Pro** (a one-time purchase) adds trend-based content ideas and a daily shot list you can export to Calendar.

## Run it in the simulator

1. Use **Xcode 16.4** (the version that runs on your 2019 MacBook Pro with macOS Sequoia).
2. Double-click **`RaceDayReady.xcodeproj`**.
3. Click the blue **RaceDayReady** project icon → **RaceDayReady** target → **Signing & Capabilities** → choose your **Team** (the same one you use for Settle It). Xcode needs it because the app uses iCloud.
4. Pick an iPhone simulator in the toolbar and press **⌘R**.

That's it for a first look. In the simulator:
- Pro can be "bought" with fake money. The Run scheme uses `RaceDayReady/Resources/Products.storekit`.
- iCloud sync and sharing only work on a real device signed into iCloud, after the one-time setup in **SETUP-GUIDE.md**. Without it the app still works, saving on that device only.

## Bring in your web lists

The file `race-day-ready-export.json` (sent with this project) holds your Wine & Dine, Marathon Weekend and Princess lists from the web version. On the phone: **Settings → Import lists from a file**, then pick it (AirDrop it to your phone or save it to Files first).

## What's where

| Folder | What it holds |
|---|---|
| `RaceDayReady/App` | App entry point |
| `RaceDayReady/Data` | Core Data model (built in code), iCloud stores, race calendar types, starter lists |
| `RaceDayReady/Services` | In-app purchase, calendar (.ics) export, iCloud sharing, importer |
| `RaceDayReady/Views` | Every screen |
| `RaceDayReady/Resources` | Bundled trend feed (`feed.json`) and the StoreKit test file |
| `feed/feed.json` | The hosted trend feed (see "Updating trends" below) |
| `tools/` | Scripts that rebuild the feed, the Xcode project and the app icon |

## Updating trends (the Pro content feed)

The app downloads `feed.json` from `https://electricsoup.github.io/race-day-ready-feed/feed.json` and falls back to the copy built into the app. To publish a new feed:

1. Edit `tools/build_feed.py` (or `feed/feed.json` directly) and run `python3 tools/build_feed.py`.
2. Copy `feed/feed.json` to the public `race-day-ready-feed` repo with GitHub Pages turned on (one-time setup in SETUP-GUIDE.md).

The feed also holds the season's race calendar and the costume ideas for each race theme, so next season's weekends can be added without an app update.

## Adding a Swift file

Run `python3 tools/make_xcodeproj.py` after adding or removing files. It regenerates `RaceDayReady.xcodeproj` from the folders. (`project.yml` is a backup for XcodeGen.)

## Builds

Every push to `main` is compiled on a GitHub Mac (`.github/workflows/ci.yml`). The latest result is saved on the `ci-results` branch in `result.txt`.

## Before you ship

| Replace | Where |
|---|---|
| Bundle ID `com.electricsoup.racedayready` | Xcode target → Signing & Capabilities, and App Store Connect |
| iCloud container `iCloud.com.electricsoup.racedayready` | `RaceDayReady.entitlements` and `Data/Persistence.swift` |
| Pro product ID `com.electricsoup.racedayready.pro` | `Services/StoreManager.swift` and App Store Connect |
| Feed address | `Data/Catalog.swift` (`FeedStore.remoteURL`) |

See **SETUP-GUIDE.md** for the step-by-step.

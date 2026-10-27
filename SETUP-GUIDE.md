# Race Day Ready — Setup Guide

Everything between "it runs in the simulator" and "it's on the App Store." Do these in order.

## 1. Signing and capabilities (Xcode, ~10 minutes)

1. Open `RaceDayReady.xcodeproj`, select the **RaceDayReady** target → **Signing & Capabilities**.
2. **Team:** pick your Apple Developer team. Leave "Automatically manage signing" on.
3. **Bundle Identifier:** `com.electricsoup.racedayready` (change it if you prefer; then change it everywhere in the README table).
4. Check that these capabilities are listed (the entitlements file already asks for them):
   - **iCloud** with **CloudKit** ticked and the container `iCloud.com.electricsoup.racedayready`. If the container shows red, click **+** under Containers and add exactly that name.
   - **Push Notifications** (CloudKit uses silent pushes to sync).
   - **Background Modes → Remote notifications** (already in `Info.plist`).
5. Run on your own iPhone once. The first launch creates the CloudKit schema in the Development environment.

## 2. iCloud sharing check (two Apple IDs)

1. On your iPhone, create a trip and tap the **person + plus** button in the trip's top bar.
2. Send the invite to Andrew. When he opens the link on his iPhone (with the app installed from Xcode or TestFlight), the trip appears in his list.
3. Both of you add an item. It should show up on the other phone within a few seconds (pull down or reopen the trip if not).

> CloudKit sharing only works with real Apple IDs on real devices, not the simulator.

## 3. Publish the CloudKit schema (before TestFlight or the App Store)

1. Go to [icloud.developer.apple.com](https://icloud.developer.apple.com) → CloudKit Console → your container.
2. **Schema → Deploy Schema Changes** to copy the Development schema to Production.
3. Do this again any time you add a new field to the data model.

## 4. In-app purchase (App Store Connect)

1. In App Store Connect, create the app (name **Race Day Ready**, bundle ID from step 1).
2. **Monetization → In-App Purchases → +**:
   - Type: **Non-Consumable**
   - Reference name: Race Day Ready Pro
   - Product ID: `com.electricsoup.racedayready.pro` (must match exactly)
   - Price: your choice (the test file uses $4.99)
   - **Family Sharing: On** (the app tells people one purchase covers their family)
   - Display name and description, plus a screenshot of the Content tab for review.
3. Fill in **Agreements, Tax, and Banking** if you haven't for Settle It. Purchases won't load until it's done.

## 5. Host the trend feed (GitHub Pages, ~5 minutes)

1. Create a **public** repo named `race-day-ready-feed`.
2. Add `feed.json` from this project's `feed/` folder to its root.
3. Repo **Settings → Pages → Deploy from a branch → main / (root)**.
4. After a minute, `https://electricsoup.github.io/race-day-ready-feed/feed.json` should open in a browser. The app checks it on launch and when you pull to refresh Ideas.

To refresh trends later, edit and re-run `tools/build_feed.py`, then replace `feed.json` in that repo. (Ask Claude to research current trends and update the feed. That can also be set up as a weekly scheduled task.)

## 6. App Store review notes

- **Trademarks:** Apple rejects apps that use other companies' names or characters in the app name, icon, screenshots or keywords (guideline 5.2). Keep race organizer and theme-park names, logos and character art out of the listing and screenshots. The app's own text is neutral, and race and character names come from the feed as information about each event. If review pushes back, the feed can describe races generically without changing the app.
- **Privacy:** the app collects nothing. Data stays in your iCloud and is shared only with people you invite. In App Store Connect choose **Data Not Collected**. A simple privacy page on your site is still required. Reuse the Settle It one, adjusted.
- **Review notes for Apple:** mention that sharing needs two iCloud accounts, and that Pro can be tested with the sandbox purchase.

## 7. TestFlight

1. In Xcode: **Product → Archive**, then **Distribute App → App Store Connect**.
2. In App Store Connect → TestFlight, add Andrew as an internal tester.
3. Once you've both used it for a race weekend, submit for review.

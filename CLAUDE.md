# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Tribuneros is an iOS/SwiftUI app showing public cycling results and calendars, scraped from
third-party sites, as three tabs: Today Races (`HomeRaces`, from procyclingstats.com), CX Zone
(`CXRaces`, cyclocross, from cyclocross24.com), and Paddock (`Paddock`: a feed of transfers, top
riders' race-program changes and birthdays from the PCS homepage, under a strip of cycling-news
sites listed in Firebase Remote Config). Road racing is scraped on the device; the CX lists are
scraped server-side by a Firebase Cloud Function and read from Firestore (see "Data sources" below).

## Build, test, and run

### iOS app

- Open in Xcode: `open Tribuneros.xcodeproj` — scheme `Tribuneros`, iOS 18+ simulator.
- CLI build: `xcodebuild -project Tribuneros.xcodeproj -scheme Tribuneros -destination 'generic/platform=iOS Simulator' build`
- Run tests: `xcodebuild -project Tribuneros.xcodeproj -scheme Tribuneros -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Run a single test: add `-only-testing:TribunerosTests/<TestClass>/<testMethod>` to the `test` invocation above.
- Test plan (`Tribuneros/Tribuneros.xctestplan`) skips the placeholder `TribunerosTests.testExample`.
- If Swift Package resolution breaks: Xcode → File → Packages → Reset Package Caches, then clear DerivedData.
- Debug-only launch env flags: `MOCK_SCENARIO=live|later|one|empty|stale|history|previews|pending` (or a `mockScenario` launch argument, which is what the Maestro flows pass) is the one switch for all mock data: fixed Today Races data instead of the PCS fetch, the race info stubs, the race result pages it opens (a mock top 10), the Course du Jour schedule, the Paddock feed, press list and rider pages, and the CX Zone documents and detail pages (no PCS, cyclocross24, Firestore, `cxDetail` or YouTube request), see `HomeRaces.MockScenario.swift`; unset or unknown means real data. `CT_COURSEDUJOUR_NATIVE` (or `ctCoursedujourNative`) only overrides the Remote Config flag `isCourseDuJourNativeEnabled`, it never turns on mocks. `DEBUG_BACKGROUND=1` (highlights view backgrounds via `.debugBackground()`) and `FIREBASE_EMULATOR=1` (Firestore and `cxDetail` on the local emulators, see `Service.useFirebaseEmulatorIfEnabled()`; seed `cx/*` by calling `runCxScrape` with `FIRESTORE_EMULATOR_HOST` set). From the CLI: `SIMCTL_CHILD_FIREBASE_EMULATOR=1 xcrun simctl launch <device> com.pskmoons.Tribuneros`.
- Onboarding (`Tribuneros/Onboarding/`): four full-screen pages (welcome, spoiler-safe results, CX Zone, Paddock), each with a hand-authored shape-only Lottie (`onboarding_*.json`, made by a script outside the repo; all text is SwiftUI). `OnboardingHost` (between `LaunchSplashHost` and `MaintenanceHost`, content built once) decides once per cold launch, after `Onboarding.splashDelay` (the splash's time on screen): `Onboarding.Schedule` shows it on the first launch, once more at least 7 days after that first showing, never a third time (`UserSettings.onboardingFirstShown` / `onboardingShownCount`, recorded when it shows, so Skip and "Let's ride" both count). Debug: a mock scenario skips it unless `ONBOARDING=1` (or an `onboarding` launch argument) turns it on, and `ONBOARDING_SECOND_SHOWING=1` (or `onboardingSecondShowing`) makes a fresh install act as if the first showing was a week ago. `RESET_ONBOARDING=1` (or `resetOnboarding`) clears both stored values at launch, so that launch is a first run again (it works even when a mock scenario skips the onboarding). Release follows the schedule only. Maestro: `.maestro/onboarding.yaml`.
- Preferences reset (`Helpers/PreferencesReset.swift`): `PreferencesReset.runAtLaunch()` is the first line of `TribunerosApp.init()` (before Crashlytics and any `UserSettings` read). If the stored `preferencesResetVersion` is missing or lower than `UserSettings.currentPreferencesResetVersion`, it removes every `UserPreferencesKey` (`CaseIterable`; add new `@UserDefault` keys to that enum) except the marker, then stores the constant. Bump the constant to reset everyone once more. It never touches other `UserDefaults` keys (Firebase, Remote Config), SwiftData or caches. Debug: `SIMULATE_APP_UPDATE=1` (or `simulateAppUpdate`) forgets the marker first. Maestro: `.maestro/preferences-reset.yaml`.

### Tests

- `RequesterHomeParsingTests` parses the saved PCS homepage fixture `TribunerosTests/pcs_real.html`,
  so a PCS markup change fails loudly instead of silently producing empty sections. When PCS
  redesigns, re-capture the fixture (with `URLSession`, not curl — see below) and update the parsers
  and assertions together.
- `HomeTodayRacesTests` covers what Today Races derives from "Next to finish": stage titles, finish
  times (including a finish after midnight), ordering, the LIVE join with LiveStats, and the view
  model mapping. Its dates are built with `Calendar.current`, so it doesn't depend on the time zone.
- UI flows are Maestro files in `.maestro/` (`maestro test --include-tags home .maestro`, against a
  Debug build installed on the booted simulator). Every flow passes a `mockScenario`, so none
  needs the network. The folder is ignored by the global
  gitignore on this machine, so the flows stay local unless force-added.
- Two tests hit the live network and are slow/flaky by nature, not a sign your change broke
  something: `RequesterHomeParsingTests.testGetLatestResultsParsesRealWebsite` (PCS) and
  `RequesterCxTests` (cyclocross24.com + YouTube, retries for up to 10s).
- Lottie (`lottie-spm`) is linked into the app target only, for the same reason. The spoiler hint callout plays `Tribuneros/spoiler_long_press.json` (hand-authored shapes, ~3.8 s loop: a hand presses and holds a result card for 1.5 s, the spoiler painting fades out over 0.75 s, the hand lifts, the painting snaps back); with Reduce Motion it shows one still frame. The JSON loads via `LottieAnimation.named`, so check it in the running app, not in tests.
- The `TribunerosTests` target links `Alfy` and `SwiftSoup` explicitly. **Don't link
  `FirebaseFirestore` into it**: sharing the Firestore package between the app and test targets
  fails at link time (missing gRPC/abseil symbols). If a test needs Firestore, call app-target code
  that wraps it.

### Firebase backend (`functions/`)

TypeScript Cloud Functions for Firebase project `tribunerus-4a0ee` (`.firebaserc`), region
`europe-west1`, Node 22 runtime (`functions/package.json` → `engines`). Run these from the repo
root with Node 22 on PATH — the Homebrew `node@22` install is first on PATH in this machine's shell.

- Build: `npm --prefix functions run build`
- Test: `npm --prefix functions test` (Node's built-in runner; parser tests read real cyclocross24
  pages saved in `functions/test/fixtures/`; re-capture them when the site changes).
- Local emulators (Functions + Firestore + UI on :4000): `firebase emulators:start`. Always run
  Firestore in the emulator when testing locally — the functions emulator alone writes to the
  **production** database.
- Deploy: `firebase deploy --only functions,firestore:rules` — the user deploys; it changes the
  live project and isn't something to run on your own.
- Logs: `firebase functions:log --only scrapeCx`

## Architecture

### Feature module pattern (MVI-ish)

Every tab follows the same shape, split across `<Feature>.swift` (namespace enum, `Action` /
`ViewState` / `Representable`), `<Feature>.Interactor.swift` (`Domain` struct + `UseCase` enum +
`InteractorImpl`), and `<Feature>.ViewModel.swift`:

- `InteractorImpl` (in `HomeRacesInteractor.swift` / `CXRaces.Interactor.swift` /
  `Paddock.Interactor.swift`) owns a
  `CurrentValueSubject<Domain, Never>`, runs network calls in a cancellable `Task`, and exposes
  `useCase(_:)` as its only mutation entry point.
- `ViewModel<Interactor: InteractorProtocol>` (generic over the shared `InteractorProtocol`,
  defined in `HomeRacesInteractor.swift`) subscribes to the interactor's publisher, maps `Domain`
  → `ViewState`, and exposes `action(_:)` for the view to call. It also owns a `Router`.
- Views only see `Representable`/`ViewState`/`Action` — never `Domain` — and call
  `viewModel.action(...)`.
- Navigation: each tab has its own `Router` (`Router.swift`, `ObservableObject` wrapping a
  `NavigationPath`), created once in `TabBarView.init()` and threaded into that tab's
  `NavigationStack`. `Router.Destination` is a single enum shared across tabs (`detail`,
  `cxZone`, `nextToFinishRace`, `todayRaces`, `yesterdayResults`, and `web(URL)`, which opens any link
  in `Helpers/SafariView.swift`).

When adding a new tab or reworking one of these, match this Domain/UseCase/Interactor/ViewModel
split rather than putting networking or state directly in a View.

### Data sources

Both sites are scraped with hand-written CSS selectors (no JSON API). `DTO.swift` holds the parsed
wire models; interactors map `DTO` → per-feature `Domain`, and view models map `Domain` →
`Representable`. Don't reuse `DTO` types directly in views. All networking lives on the `Service`
struct: `Service.swift` (PCS), `Service+Paddock.swift` (the Paddock feed's PCS sections),
`Service+RemoteConfig.swift` (the press list) and the `extension Service` in `Requester+Cx.swift`
(CX) — that filename predates the `Requester` → `Service` rename, which freed the name for Alfy's
`Requester`.

**ProCyclingStats stays on the device — don't move it server-side.** PCS sits behind a Cloudflare
bot challenge: Node/curl requests get HTTP 403 with a "Just a moment..." page, while iOS's
`URLSession` passes. A Cloud Function version won't work, and working around the challenge
(headless browser, TLS-fingerprint spoofing) was deliberately ruled out. Consequences:

- Test PCS fetches with `URLSession` (e.g. a `swift` script), never curl — a curl 403 is not what
  the app sees.
- `getHomepageDocument()`, shared by `getLatestResults()` and `getPaddock()`, goes through Alfy's
  `Requester` builder (60s TTL cache, ignoring server cache headers), so opening Paddock right after
  Today Races is a cache hit. It doesn't validate HTTP status, and parsers return `[]` rather than
  throwing, so if Cloudflare ever does challenge the app, the symptom is empty sections, not an error.
- Offline is kept out of Crashlytics by matching both URLSession's `-1009` and Alfy's
  `Requester.ErrorReason.noInternetConnection`.
- `HomeRacesInteractorImpl` uses Alfy's `RequestThrottleController` (60s minimum interval, 2 extra
  attempts after a failure) so tab reselects don't hammer PCS.
- The homepage parsers anchor on section heading text (`h4`), not table classes: the
  "Next to finish" and "Races tomorrow" tables share the same class. The "Results today" `<ul>` is
  left unclosed by PCS when empty, so only its direct `<li class="race">` children count.
- Paddock reads three more homepage sections: "Latest transfers", "Recent top riders program
  updates" and "Birthdays". Program-update times are relative ("16h") and transfer dates have no
  year ("20/09"); `Paddock.InteractorImpl` resolves both against the fetch time, and the feed
  groups by calendar day. An empty program-updates list is normal — PCS often has none.
- Transfer and program cards open `Paddock.RiderDetailView` (route `paddockRider(Paddock.RiderContext)`):
  the card's data (new team / added and dropped races) plus the rider's PCS page, fetched on
  demand by `Service.getPCSRiderPage` (10 min TTL). `parsePCSRiderPage` is best-effort (the `h1`
  name, the first rider photo, a `team/` link in the title block, and "Label:" elements in `b`,
  `strong` or `.bold` followed by their value) and covered only by synthetic HTML in
  `PaddockTests`; capture a real rider page with `URLSession` to tighten it. Birthday rows still
  open the PCS page in Safari.

**The Today Races screen** (`HomeRaces.MainView`) is one scroll: a header (bicycle, "Races", the
date; the navigation bar is hidden on this root and `StatusBarScrim` fades content under the status
bar), then four sections:

- **Today** (`TodayHeroCard`): the first "Next to finish" race as a hero card, or a resting night
  scene (`TodayEmptyCard`) when the list is empty. "See all", only with more than one race, pushes
  `TodayRacesListView`. `HomeRaces.TodayRaces.build` turns the DTOs into `RaceNext` values:
  ordered by finish time (the ETA, today; an ETA hours in the past that PCS still counts hours to go
  for rolls over to tomorrow), ties keep the page order, WorldTour no longer goes first. A race is
  `isLive` (red LIVE tag, otherwise the grey TODAY one) when LiveStats lists it as live: its `/live`
  path is the race path plus `/live`, or the titles match. LiveStats is empty on most days (the
  fixture's list is), so TODAY is the common tag; the old LiveStats cards are gone. A " - S2"
  suffix on the name is the stage (`title` / `stageLabel`); without one it reads "One-day race". The
  "in 2h 14m" text is computed from the ETA and refreshed by `TimelineView(.everyMinute)`.
- **Results today** and **Yesterday**: the title, then highlight cards / one card of rows.
  Results start hidden: each card or row shows the `SpoilerArt` painting over redacted stand-in
  data (no real names or images reach the view), and a long press (1.5 s to reveal, 0.8 s to hide; `SpoilerHold`) reveals or hides that one race: nothing animates while the finger is down; on completion (success haptic on reveal, soft impact on hide) a reveal fades the painting from opacity 1 to 0 over 1.5 s (`SpoilerHold.revealDuration`) while the winner photo fades in, and hiding is instant, with no animation (`SpoilerCrossfade.animation(for:)` animates only when the new state is shown, Reduce Motion included)
  (`Domain.revealedRaces`, keyed by `raceURL` or name, in memory only, so every launch starts
  hidden). A one-time `SpoilerHint` callout explains the long press (a plain tap on a shown result opens it at once). An empty Results today shows
  the `EmptyPodiumArt` card with "First finish expected HH:MM"; an empty Yesterday says "No
  results yesterday". Yesterday previews 3 rows; its "See all" pushes `YesterdayResultsListView`,
  with the same per-race reveal. Cards and rows open the race's PCS results page in Safari
  (`DTO.TodayResult.raceURL`). Both results parsers split the title (`<b>`) from the route and
  distance (`<span>`).
- **History**: a placeholder banner (`HistoryBanner`) with an inert "See all" until there is data.

"Races tomorrow" is no longer drawn (it is still parsed). The generic paintings (`RaceArtView`, the
vector assets `RaceArtDay`, `RaceArtNight` and `RaceArtBanner`) stand in wherever PCS has no
image: a winner photo that is missing or fails to load falls back to the day painting
(`WinnerPhoto`, i.e. `CachedImageView(presentation: .racePhoto)`). PCS answers 403 to image requests without a Referer and a
browser User-Agent, so `CachedImageView` adds both for PCS URLs (`Service.addPCSImageHeaders`).

**The Paddock press list comes from Firebase Remote Config**, key `press_urls`: a JSON array whose
entries are either a URL string or a `{"Name": "url"}` object (the console currently uses the
object form). Non-http(s) entries are dropped. The in-app default (the six original sites) covers
first launch and offline; DEBUG builds fetch with a 0s minimum interval, release keeps the 12h
default. Paddock shows the press panel without waiting for the fetch: `requestPress()` first
publishes `Service.cachedPressLinks()` (the last activated value, or the default), then refreshes
it. Until any list is known (`Domain.press == nil`, `ViewState.press == .loading`) the panel shows
redacted placeholder cards; an empty list hides it. The feed does the same while it loads (`Feed.loading` draws
`Section.placeholders` redacted, under the still-usable filter chips).

**CX lists come from Firestore.** The `scrapeCx` scheduled function (`functions/src/index.ts`,
daily at 23:00 Europe/Madrid) scrapes cyclocross24.com with cheerio (`functions/src/cx.ts`, a port of the old
Swift parsers) and writes three documents: `cx/homepage`, `cx/calendar`, `cx/standings`, each with
an `updatedAt` timestamp. `Service.getCxEvents()` / `getCxAllCalendarEvents()` / `getCxStandings()`
just read and decode those documents, so the TypeScript field names must stay identical to the
Swift DTOs (all `Decodable`). Server-side behaviour to preserve:

- A failed or empty scrape keeps the previous document instead of overwriting it with nothing.
- cyclocross24 answers bursts with HTTP 429, so all requests are spaced 750 ms apart with
  `Retry-After`-aware retries. A full run takes ~25s against a 120s timeout.
- The calendar season is derived from the date (from July onward, the next season), not hardcoded.
- Firestore rules (`firestore.rules`): `cx/*` is publicly readable and never client-writable. Only
  the function writes, through the Admin SDK, which bypasses rules.
- Every function module imports `functions/src/options.ts` first: `setGlobalOptions` (region
  `europe-west1`) only applies to functions defined after it runs.

**CX detail pages come from `cxDetail`** (HTTP, on demand):
`GET …/cxDetail?kind=rider|race|results&id=<slug or results id>` serves `cxRiders/{slug}` (fresh for
24h), `cxRaces/{slug}` (7 days) or `cxResults/{id}` (forever once non-empty), scraping and storing on
a miss or stale entry, and falling back to the stale copy if the scrape fails. Ids are validated as
plain slugs so it can't be pointed at other URLs; a page cyclocross24 doesn't have (404/410, or one that
parses to nothing) is remembered for an hour in `cxMissing/{collection}_{id}` (function-only, no client
access) so made-up names can't force a scrape per call, and other failures (429, 503) aren't remembered; `maxInstances: 2` keeps the per-instance 750 ms
spacing meaningful. Same rules as `cx/*`. On the app side, `Service.getCxDetail` reads the Firestore
document (cache first), calls the function on a miss, and on a stale copy returns it while a
background call refreshes it; `Service.CxDetailKind` mirrors the id rules and freshness windows, so
change both sides together. The parsers live only in `functions/src/cx.ts`; the rider, race
(calendar and latest-results) and results screens all read through this cache. Only the YouTube
lookup (`getYoutubeRaceURL`: race page, then YouTube search) still scrapes on the device.

The "All races" calendar has a search bar (`CXRaces.calendarEvent(_:matches:)`: every word must
appear, case- and accent-insensitively, in the race name, country, winner, UCI class or series)
and series filter chips (`CXRaces.RaceSeries`, inferred from the race name and UCI class since
cyclocross24 has no series field); the two combine, and chip counts follow the search. A row opens
`CXEventDetailView`.
`Service.getCxEventDetail` fills it on demand: the race page's Men Elite history of winners
(`cxRaces`), plus the Men Elite results (`cxResults`) and video once the race day has come. Its "Winner" row opens `CXWinnerDetailView` (built from `CXRaces.Winner`); each "Past
winners" row opens `CXRiderDetailView` with `RiderContext.win` (a Victory panel whose race card
opens that edition; its time/age tiles and the team come from that edition's results page,
`RiderContext.winResultsURL`, loaded with the rider page through `Service.getCxWinnerDetail`). `CXWinnerDetailView` shows race facts and the winner's results row (time, team, age, fetched
from that edition's results page when not already loaded) plus their rider page via
`Service.getCxWinnerDetail` (`cxRiders`). The winner screen's "Victory" card
pops back when that edition is the race it was opened from (the route carries it:
`winnerDetail(_:from:)`), otherwise it opens the winning edition (`CXRaces.Winner.raceEvent`; for a past winner, the race with that
year, winner and results link) and a recent-results row (on any rider screen) resolves its race via `CXRaces.calendarEvent(for:in:)`: this season's calendar entry
when one matches, else a minimal event built from the row (the detail then takes its winner from
the loaded results). A win (position 1) opens `CXWinnerDetailView` for that race instead
(`Winner(riderResult:rider:raceEvent:)`, route `winnerDetail(_, from: nil)`); anything else opens
`CXEventDetailView`.

The Standings list has a search bar too (`CXRaces.standings(_:matching:)`: words match the
ranking title, category title or rider name; a matching ranking/category keeps all its riders,
otherwise only matching riders stay and emptied categories/rankings are dropped). It only searches
what the standings document holds: the top five of each category.

Standings list rows, and the leader rows on the CX Zone standings summary card (the rest of that
card still opens the list), open `CXRiderDetailView` with `CXRaces.RiderContext.standing`
(`RiderStanding`: ranking, category, position, points). Latest-results podium rows (home card and
full list; the rest of each card still opens the list / the race) open it with `.podium`
(`RiderPodium`: position, time, category and the race, whose card opens `RaceDetailView`). Result
rows in `RaceDetailView` and in the calendar detail's Men Elite top 10 open it with `.result`
(`RiderResult`); `CategoryResult.riderURL` (parsed from the results table's rider link, defaulted
to `nil` so existing initializers compile) feeds its rider page, and the winner screen's rider link
when the calendar has none. It shows
the same rider-page sections as the winner screen; those sections
(`CXRiderAvatar`, `CXRiderFactsPanel`, `CXRiderRecentResultsPanel`, `CXStatTile`) live in
`Details/CXRiderSections.swift`.

### `Alfy`: sibling shared package

`Alfy` (SPM dependency, `https://github.com/vilapuigvila/Alfy.git`, same author, checked out
locally at `../Alfy`) supplies cross-project infra: `Requester` (networking over the
`CachedURLSession` actor), `RequestThrottleController`, `EquatableError`, `NetworkStatusMonitor`,
the `UserDefault` property-wrapper pattern used in `UserPreferences.swift`, and other helpers. If a
type used in this repo can't be found under `Tribuneros/`, look in `Alfy` rather than assuming it's
missing — and if it needs a behavior change, that change likely belongs in the `Alfy` repo.

Alfy's `Requester` notes:

- Every method is `static`; to hold it as a value, use `Requester.self` (a bare `Requester`
  doesn't compile, and an instance can't call anything).
- It always adds `Content-Type: application/json`, even to GETs. Harmless for PCS (tested).
- Caching is per URL, but the TTL is only per-request through the builder:
  `Requester.makeRequest(url).ttl(…).send()`. The plain `Requester.request(url)` falls back to
  `URLRequest`'s default 60s timeout as the TTL, since `CachedURLSession` reuses `timeoutInterval`
  as the cache duration.

### Styling conventions (enforced, see `agent-doc/ux_style.md`)

- Display text is localized: `L10n.tr("English key")` (see "Localization"), never a bare literal.
- Never use `Text(...)`/`Text(verbatim:)` in views — always `TribuneruText(content:style:color:lineLimit:)`
  (`Styling/TribuneruText.swift`). Adding a new text style means adding a case to
  `TribuneruText.Style` (and its `size`/`weight`/`fontName` switch arms), not inlining a font call.
- Never use raw colors (`.red`, `Color(...)`, hex literals) in views — always
  `Color.tribuneru(.somecase)` (`Styling/Colors.swift`), which itself is the only place hex values
  (`Color(hex:opacity:)`) belong.
- Remote images go through `CachedImageView(imageUrl:cornerRadius:)`
  (`Tabs/HomeRaces/Components/RaceFinishedCardRow.swift`, wraps Kingfisher's `KFImage`), not
  `AsyncImage` — `AsyncImageView.swift` is an older hand-rolled loader kept only where already used.
- Calls with more than one argument are formatted multiline (one arg per line).
- Screens that wait for network data show redacted placeholders at once, not a spinner: stand-in
  data shaped like real content (`static let placeholders`, see `Paddock.Section.placeholders`,
  `CXRaces.Representable.placeholders`), drawn with the screen's own section components, then
  `.redacted(reason: .placeholder)`, `.disabled(true)` and an accessibility label ("Loading the
  rider"). No delay, no minimum display, no `ProgressView`. Parts already known when the screen
  opens keep their real data; error states are unchanged.

### Settings tab

A fourth tab (`Tabs/Settings/`, `Tab.settings`, last in `CustomTabBar`, own `Router`) with two rows.
"Show onboarding again" calls the `replayOnboarding` environment closure that `OnboardingHost` sets
(`Presenter.replay()`): it bypasses `isEnabled` (so mocked launches show it), never saves, leaves the
two-showing schedule alone and opens on the "Welcome back" page. "Language" pushes
`Router.Destination.settingsLanguage`, a list of `Settings.Domain.supportedLanguages` ("System
default", then English and Català, each named in itself) stored in `UserSettings.appLanguage`
(default `system`). Picking one applies it at once (see "Localization" below).

### Localization (English + Catalan)

- One String Catalog, `Tribuneros/Localizable.xcstrings`, generated from
  `scripts/l10n/fragments/*.json` by `python3 scripts/l10n/build_catalog.py`. **Never edit the
  catalog by hand** (its entries are `extractionState: manual`): add the key to a fragment and rebuild.
  Keys are the English text; plurals use catalog plural variations (`%lld` with an `Int`).
- Every display string goes through `L10n.tr("English key", args…)` (`Localization/L10n.swift`) with a
  literal key; `TribuneruText.content` stays verbatim, so scraped names are never looked up. View
  models and enums build strings with `L10n.tr` too. Display dates use `L10n.dateFormatter(template:)` /
  `L10n.relativeFormatter()` / `L10n.locale` (also for `uppercased(with:)`); parsers stay on `en_US_POSIX`.
  English literals that match scraped text or serve as ids stay English, with a separate display value.
- The language is the app's own choice, not the device's: `AppLanguage.resolve` maps `system` to the
  device's preferred languages (falling back to English). `AppLocalization.applyAtLaunch()` runs right
  after `PreferencesReset` in `TribunerosApp.init()`; a change in Settings calls
  `AppLocalization.shared.apply`, and `LocalizedRoot` rebuilds `TabBarView` (`.id` on the language) so
  every view model re-maps its strings. The selected tab survives; navigation stacks return to root and
  in-memory spoiler reveals reset. System UI (search "Cancel", share sheets, Safari) follows the device.
- Check: `python3 scripts/l10n/check_localization.py` (also a CI job) fails on a key used in Swift but
  missing from the fragments, a missing or untranslated Catalan value, mismatched format specifiers, a
  straight apostrophe in Catalan (use ’), the catalog being out of date, `ca` missing from
  `knownRegions`/`CFBundleLocalizations`, and hardcoded English in display positions (mark a deliberate
  one with `// l10n:ignore`; brand words go in `scripts/l10n/allowlist.json`). XCTests:
  `LocalizationTests.swift` (+ per-tab `Localization*Tests`). Tests that switch to Catalan set it back
  to English in `tearDown`. Maestro: `.maestro/settings-language.yaml`.
- Adding a language: a code in `AppLanguage.localizations` + `endonym`, `knownRegions` in the pbxproj,
  `CFBundleLocalizations` in `Info.plist`, `TARGET_LANGUAGES` in `scripts/l10n/common.py`, and a value
  for every fragment entry.

### "Vapor" design system

The dark, blue-grey "Vapor" look now covers all three tabs and the tab bar. Its tokens are the
`vapor*` cases in `Color.Palette` and `TribuneruText.Style` (Space Grotesk / Space Mono fonts,
bundled under `Tribuneros/Fonts/` and listed in `Info.plist`). `agent-doc/home_redesign_spec.md` is
its source-of-truth spec — palette, type ramp, geometry, and the rule that a section panel is
always darker than the cards on it. Use the `vapor*` tokens for new UI; the older green palette
cases remain only for code that hasn't been migrated. The Today Races tab no longer uses the panel
layout (see "The Today Races screen" above): it is built from the same tokens, with the extra
`vaporLiveRed` / `vaporTagNeutral*` tag colors and the `vaporHeading`..`vaporBannerSubtitle` text
styles; the panel spec still describes CX Zone and Paddock.

### Crash reporting instead of throwing

`Helpers/CrashlyticsManager.swift` centralizes non-fatal error reporting. Use the free function
`nonFatalCrashlytics(condition, message, domain:)` (assert-like: reports when `condition` is
false) at call sites instead of adding new error-throwing paths — this is the existing pattern for
"this shouldn't happen but don't crash the app" cases (missing HTML nodes, unreachable switch
branches, etc.). Firebase itself is configured through `CrashlyticsManager.configure()` at app
launch, which is also what makes Firestore usable.

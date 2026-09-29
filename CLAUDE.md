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
- Debug-only launch env flags: `MOCKING=1` (forces mock data via `isMockingEnabled`, see `RaceFinishedCardView.swift`) and `DEBUG_BACKGROUND=1` (highlights view backgrounds via `.debugBackground()`).

### Tests

- `RequesterHomeParsingTests` parses the saved PCS homepage fixture `TribunerosTests/pcs_real.html`,
  so a PCS markup change fails loudly instead of silently producing empty sections. When PCS
  redesigns, re-capture the fixture (with `URLSession`, not curl — see below) and update the parsers
  and assertions together.
- Two tests hit the live network and are slow/flaky by nature, not a sign your change broke
  something: `RequesterHomeParsingTests.testGetLatestResultsParsesRealWebsite` (PCS) and
  `RequesterCxTests` (cyclocross24.com + YouTube, retries for up to 10s).
- The `TribunerosTests` target links `Alfy` and `SwiftSoup` explicitly. **Don't link
  `FirebaseFirestore` into it**: sharing the Firestore package between the app and test targets
  fails at link time (missing gRPC/abseil symbols). If a test needs Firestore, call app-target code
  that wraps it.

### Firebase backend (`functions/`)

TypeScript Cloud Functions for Firebase project `tribunerus-4a0ee` (`.firebaserc`), region
`europe-west1`, Node 22 runtime (`functions/package.json` → `engines`). Run these from the repo
root with Node 22 on PATH — the Homebrew `node@22` install is first on PATH in this machine's shell.

- Build: `npm --prefix functions run build`
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
  `cxZone`, `nextToFinishRace`, and `web(URL)`, which opens any link in `Helpers/SafariView.swift`).

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

**The Paddock press list comes from Firebase Remote Config**, key `press_urls`: a JSON array whose
entries are either a URL string or a `{"Name": "url"}` object (the console currently uses the
object form). Non-http(s) entries are dropped. The in-app default (the six original sites) covers
first launch and offline; DEBUG builds fetch with a 0s minimum interval, release keeps the 12h
default.

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

Race detail results (`getCxRaceCategoryResults`) and the YouTube lookup are still fetched on the
device, on demand, when a race is opened.

The "All races" calendar has series filter chips (`CXRaces.RaceSeries`, inferred from the race name
and UCI class since cyclocross24 has no series field), and a row opens `CXEventDetailView`.
`Service.getCxEventDetail` fills it on demand, on the device: the race page's history of winners
(`parseCx24RacePage`, best-effort: it keys on rows holding a rider link and a year, not on table
classes, and is covered only by synthetic HTML in `CXEventDetailTests`), plus the Men Elite results
and video once the race day has come. Its "Winner" row opens `CXWinnerDetailView` (built from `CXRaces.Winner`); each "Past
winners" row opens `CXRiderDetailView` with `RiderContext.win` (a Victory panel whose race card
opens that edition; its time/age tiles and the team come from that edition's results page,
`RiderContext.winResultsURL`, loaded with the rider page through `Service.getCxWinnerDetail`). `CXWinnerDetailView` shows race facts and the winner's results row (time, team, age, fetched
from that edition's results page when not already loaded) plus their rider page via
`Service.getCxWinnerDetail`
(`parseCx24RiderPage`: the `img.rider-avatar__image` avatar selector is shared with the Cloud
Function; facts and recent results are best-effort, like the race page). The winner screen's "Victory" card
pops back when that edition is the race it was opened from (the route carries it:
`winnerDetail(_:from:)`), otherwise it opens the winning edition (`CXRaces.Winner.raceEvent`; for a past winner, the race with that
year, winner and results link) and a recent-results row (on any rider screen) resolves its race via `CXRaces.calendarEvent(for:in:)`: this season's calendar entry
when one matches, else a minimal event built from the row (the detail then takes its winner from
the loaded results). A win (position 1) opens `CXWinnerDetailView` for that race instead
(`Winner(riderResult:rider:raceEvent:)`, route `winnerDetail(_, from: nil)`); anything else opens
`CXEventDetailView`.

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

### "Vapor" design system

The dark, blue-grey "Vapor" look now covers all three tabs and the tab bar. Its tokens are the
`vapor*` cases in `Color.Palette` and `TribuneruText.Style` (Space Grotesk / Space Mono fonts,
bundled under `Tribuneros/Fonts/` and listed in `Info.plist`). `agent-doc/home_redesign_spec.md` is
its source-of-truth spec — palette, type ramp, geometry, and the rule that a section panel is
always darker than the cards on it. Use the `vapor*` tokens for new UI; the older green palette
cases remain only for code that hasn't been migrated.

### Crash reporting instead of throwing

`Helpers/CrashlyticsManager.swift` centralizes non-fatal error reporting. Use the free function
`nonFatalCrashlytics(condition, message, domain:)` (assert-like: reports when `condition` is
false) at call sites instead of adding new error-throwing paths — this is the existing pattern for
"this shouldn't happen but don't crash the app" cases (missing HTML nodes, unreachable switch
branches, etc.). Firebase itself is configured through `CrashlyticsManager.configure()` at app
launch, which is also what makes Firestore usable.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Tribuneros is an iOS/SwiftUI app that scrapes public cycling results/calendars from third-party
sites (no backend of its own) and presents them as three tabs: Today Races (`HomeRaces`),
CX Zone (`CXRaces`, cyclocross), and Hate Zone (a list of external cycling-news webviews).

## Build, test, and run

- Open in Xcode: `open Tribuneros.xcodeproj` — scheme `Tribuneros`, iOS 18+ simulator.
- CLI build: `xcodebuild -project Tribuneros.xcodeproj -scheme Tribuneros -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Run all tests: `xcodebuild -project Tribuneros.xcodeproj -scheme Tribuneros -destination 'platform=iOS Simulator,name=iPhone 15' test`
- Run a single test: add `-only-testing:TribunerosTests/<TestClass>/<testMethod>` to the `test` invocation above.
- Test plan (`Tribuneros/Tribuneros.xctestplan`) skips the placeholder `TribunerosTests.testExample`.
- If Swift Package resolution breaks: Xcode → File → Packages → Reset Package Caches, then clear DerivedData.
- Debug-only launch env flags: `MOCKING=1` (forces mock data via `isMockingEnabled`, see `RaceFinishedCardView.swift`) and `DEBUG_BACKGROUND=1` (highlights view backgrounds via `.debugBackground()`).

### Tests hit live network

`TribunerosTests/RequesterCxTests.swift` calls `Requester.getYoutubeRaceURL` against the real
`cyclocross24.com`/YouTube and retries for up to 10s — it is slow and flaky by nature, not a sign
your change broke something. There is no mocked HTTP layer for the scraping code.

## Architecture

### Feature module pattern (MVI-ish)

Every tab follows the same shape, split across `<Feature>.swift` (namespace enum, `Action` /
`ViewState` / `Representable`), `<Feature>.Interactor.swift` (`Domain` struct + `UseCase` enum +
`InteractorImpl`), and `<Feature>.ViewModel.swift`:

- `InteractorImpl` (in `HomeRacesInteractor.swift` / `CXRaces.Interactor.swift`) owns a
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
  `cxZone`, `nextToFinishRace`).
- `HateZone` doesn't follow this pattern — it's a static list of external URLs rendered as
  webviews, no interactor/view model.

When adding a new tab or reworking one of these, match this Domain/UseCase/Interactor/ViewModel
split rather than putting networking or state directly in a View.

### Data flow: scraping, not a REST API

`Requester.swift` (procyclingstats.com) and `Requester+Cx.swift` (cyclocross24.com) fetch raw HTML
with `URLSession` and parse it with SwiftSoup using hand-written CSS selectors — there is no JSON
API. Parsing failures are swallowed and reported via `nonFatalCrashlytics`/Crashlytics rather than
propagated, so a source site's markup change tends to fail silently (empty sections) rather than
crash. `DTO.swift` holds the parsed wire models; interactors map `DTO` → per-feature `Domain`, and
view models map `Domain` → `Representable` for the view. Don't reuse `DTO` types directly in views.

`HomeRacesInteractorImpl` and `CXRaces.InteractorImpl` share a `RequestThrottleController`
(minimum interval + limited extra retries after failures) to avoid hammering the source site on
every tab reselect/pull-to-refresh.

### `Alfy`: sibling shared package

`Alfy` (SPM dependency, `https://github.com/vilapuigvila/Alfy.git`, same author, checked out
locally at `../Alfy`) supplies cross-project infra: `RequestThrottleController`, `EquatableError`,
the `UserDefault` property-wrapper pattern used in `UserPreferences.swift`, and other
network/cache/db helpers. If a type used in this repo (e.g. `RequestThrottleController`) can't be
found under `Tribuneros/`, look in the `Alfy` package rather than assuming it's missing — and if
it needs a behavior change, that change likely belongs in the `Alfy` repo, not here.

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

### Crash reporting instead of throwing

`Helpers/CrashlyticsManager.swift` centralizes non-fatal error reporting. Use the free function
`nonFatalCrashlytics(condition, message, domain:)` (assert-like: reports when `condition` is
false) at call sites instead of adding new error-throwing paths — this is the existing pattern for
"this shouldn't happen but don't crash the app" cases (missing HTML nodes, unreachable switch
branches, etc.).

### In-progress home screen redesign ("Vapor")

`agent-doc/home_redesign_spec.md` is the source-of-truth spec for an in-progress restyle of the
`HomeRaces` tab only (`CXRaces`/`HateZone` are untouched). It explains the `vapor*` prefixed cases
in `Color.Palette` and `TribuneruText.Style`, and the `Vapor*` component files under
`Tabs/HomeRaces/Components/` — read it before changing home-screen styling so new work matches the
palette/type-ramp/geometry rules it defines rather than introducing a third convention.

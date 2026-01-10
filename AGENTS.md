# Repository Guidelines

## Project Structure & Module Organization
- `Tribuneros.xcodeproj/`: Xcode project (includes Swift Package dependencies).
- `Tribuneros/`: main iOS app source.
  - `Tabs/`: feature areas (for example `HomeRaces/`, `HateZone/`) with subfolders like `Components/` and `Details/`.
  - `Helpers/`: shared utilities (for example Crashlytics setup, preferences).
  - `Styling/`: reusable UI styling primitives.
  - `Assets.xcassets/` and `Preview Content/`: app/preview assets.
- Configuration files: `Tribuneros/Info.plist`, `Tribuneros/GoogleService-Info.plist`.

## Build, Test, and Development Commands
- Open the project: `open Tribuneros.xcodeproj`
- Run locally: Xcode ▶︎ with scheme `Tribuneros` (iOS 18+ simulator).
- CLI build (useful for CI): `xcodebuild -project Tribuneros.xcodeproj -scheme Tribuneros -destination 'platform=iOS Simulator,name=iPhone 15' build`
- If package resolution breaks: Xcode → File → Packages → Reset Package Caches, then clear DerivedData.

## Coding Style & Naming Conventions
- Swift/SwiftUI, 4-space indentation; follow existing formatting (no repo-enforced linter/formatter).
- Naming: types `PascalCase`, members `camelCase`.
- File naming is typically `PascalCase` or `<Feature>.<Role>.swift` (example: `HomeRaces.MainView.swift`).
- Keep feature-specific code within its tab folder; shared styling goes in `Tribuneros/Styling/`.

## Testing Guidelines
- No `*Tests` target is currently committed. If adding tests, use XCTest and name files like `<Type>Tests.swift`.
- Run tests in Xcode (Test navigator) or via `xcodebuild test` once a test target exists.

## Commit & Pull Request Guidelines
- Git history shows short, single-line messages describing the change (often lowercase, e.g. “crashlytics setup”).
- Prefer concise “verb + area” messages (example: `home: refactor race detail parsing`).
- PRs: include a clear description, link related issues, add screenshots for UI changes, and call out any config/dependency changes.

## Security & Configuration Tips
- Firebase configuration lives in `Tribuneros/GoogleService-Info.plist`; avoid committing environment-specific secrets or credentials.
- Useful debug flags: `MOCKING=1` (mock data) and `DEBUG_BACKGROUND=1` (highlight view backgrounds in Debug).

## Text in SwiftUI
- Not use Text("")
- Use TribuneruText()

# Colors
- use `Color.tribuneru(.somecase)`

## Images
- For urls use `CachedImageView(imageUrl: <someOptionalURL>, cornerRadius: 1)`

# Style argument naming
- more than one argument write in multiline style:
    `SomeStructOrClass(
         arg1: <>,
         arg1: <>,
         arg2: <>,
         and so on
     )`

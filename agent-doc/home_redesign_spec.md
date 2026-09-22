# Home redesign — "Panel" implementation spec

Target screen: `HomeRaces.MainView` (the `Today Races` tab).
Source of truth for the visual design: the **Panel** artboard on the
`Tribuneros Air Sections` canvas.

This replaces the current black / green-tint look on that screen only.
`CXRaces` and `HateZone` are untouched until we decide to roll it out.

---

## 1. The idea in one paragraph

The four home sections — Next to finish, Results today, Results yesterday,
Races tomorrow — each become a **rounded panel with its own background
colour**. Titles are large (30pt) and each panel holds a 2-column grid of
small race cards. The palette is cold blue-grey ("Vapor"), not black-and-green.

**The one rule that must not be broken:** a section's panel colour is always
*darker* than the card colour sitting on it. Panels are the air behind the
content; cards float above. If a panel is ever made lighter than `cardSurface`,
the cards read as holes punched in coloured paper and the whole thing collapses.

---

## 2. Typography

Two families, both SIL Open Font License (free to bundle — confirm in each
download's `OFL.txt` before shipping).

| Role | Family | Used for |
|---|---|---|
| UI | **Space Grotesk** | all labels, titles, names |
| Numeric | **Space Mono** | all times, ETAs, countdown values, the spoiler chip |

### Bundling in iOS

1. Download from Google Fonts. Use the **static** `.ttf` files, not the
   variable ones — variable fonts need extra handling in UIKit/SwiftUI.
   Needed cuts: Space Grotesk Regular / Medium / SemiBold / Bold,
   Space Mono Regular / Bold.
2. Add to the target, then list each file in `Info.plist` under `UIAppFonts`.
3. **Verify the PostScript names before wiring them up** — they are what
   `Font.custom` takes, and they differ between static and variable builds.
   Expected: `SpaceGrotesk-Regular`, `SpaceGrotesk-Medium`,
   `SpaceGrotesk-SemiBold`, `SpaceGrotesk-Bold`, `SpaceMono-Regular`,
   `SpaceMono-Bold`. Dump the real list once at launch to confirm:

```swift
for family in UIFont.familyNames.sorted() {
    print(family, UIFont.fontNames(forFamilyName: family))
}
```

4. If a font fails to load, `Font.custom` silently falls back to the system
   face and the screen still works — so a wrong name will not crash, it will
   just look like SF. Check it visually once.

### Type ramp

Every size on the screen. `tracking` is SwiftUI `.tracking()`; values are pt.

| Element | Family | Size | Weight | Tracking | Colour |
|---|---|---|---|---|---|
| Screen title ("Today") | Grotesk | 24 | Bold | −0.4 | `textPrimary` |
| Screen date | Grotesk | 12 | Regular | 0 | `textSecondary` |
| **Section title** | Grotesk | **30** | **Bold** | **−0.8** | `textPrimary` |
| Section trailing date | Grotesk | 12 | Regular | 0 | `textSecondary` |
| Spoiler chip label | **Mono** | 11 | Bold | 0 | `textSecondary` |
| Race name — next to finish | Grotesk | 14 | SemiBold | 0 | `textPrimary` |
| Race name — results | Grotesk | 13 | SemiBold | 0 | `textPrimary` @ 72% |
| Race name — tomorrow | Grotesk | 13 | Medium | 0 | `textPrimary` |
| Winner name | Grotesk | 14 | SemiBold | 0 | `textPrimary` |
| **ETA — next to finish** | **Mono** | **20** | **Bold** | −0.5 | `textPrimary` |
| **Start time — tomorrow** | **Mono** | **18** | **Bold** | −0.4 | `textPrimary` |
| Finish time — results | Mono | 12 | Regular | 0 | `textPrimary` @ 60% |
| ETA line — tomorrow | Mono | 11 | Regular | 0 | `textSecondary` |
| Countdown ("1h 16m") | Grotesk | 11 | SemiBold | 0 | `accent` |
| Meta line ("288 km · 1.UWT") | Grotesk | 11 | Regular | 0 | `textSecondary` |
| Tab bar label | Grotesk | 11 | SemiBold | 0 | active `accent` / `textSecondary` |

Race names use `lineLimit(2)` with `line-height 1.2`; winner names are
single-line with tail truncation. All numeric runs are tabular — Space Mono is
monospaced by construction, but add `.monospacedDigit()` anyway so the SF
fallback still aligns.

---

## 3. Colour

### Core

| Token | Hex | Use |
|---|---|---|
| `pageBackground` | `#070A0E` | screen background, behind the panels |
| `cardSurface` | `#121821` | every race card |
| `textPrimary` | `#EAF0F6` | titles, names, times |
| `textSecondary` | `#8B97A6` | meta, dates, inactive tabs, spoiler chip |
| `accent` | `#5EEAD4` | countdowns, active tab, links |
| `accentPressed` | `#99F6E4` | pressed/highlight state |
| `live` | `#4ADE80` | the dot beside "Next to finish" |

### Section panels

One per section, in screen order. All darker than `cardSurface` — see §1.

| Section | Token | Hex | Hue |
|---|---|---|---|
| Next to finish | `panelRacing` | `#0A1715` | teal |
| Results today | `panelToday` | `#08121F` | blue |
| Results yesterday | `panelYesterday` | `#0E0F22` | indigo |
| Races tomorrow | `panelTomorrow` | `#150E1E` | mauve |

### Derived / alpha values

| Where | Value |
|---|---|
| Race name in a results card | `textPrimary` @ 0.72 |
| Finish time in a results card | `textPrimary` @ 0.60 |
| Dimmed countdown (races later than the next two) | `textPrimary` @ 0.55 |
| Tab bar top divider | `textPrimary` @ 0.10, 0.5pt |
| Flag inset border | white @ 0.22, 0.5pt |
| Tab bar background | `pageBackground` @ 0.95 |

### Contrast (measured, WCAG AA)

| Pair | Ratio |
|---|---|
| `textPrimary` on `cardSurface` | 15.4 : 1 |
| `textSecondary` on `cardSurface` | 5.95 : 1 |
| `accent` on `cardSurface` | 11.9 : 1 |
| `textPrimary` @72% on `cardSurface` | 8.4 : 1 |
| `textPrimary` @60% on `cardSurface` | 6.2 : 1 |

All clear AA for body text. **If you darken a card or lighten the secondary
grey, re-check** — `textSecondary` at 5.95:1 has the least headroom and it
carries the km/class line on every card.

### Adding these to `Colors.swift`

`agent-doc/ux_style.md` says never use raw colours in views, so these go in the
palette. `Colors.swift` has no hex initialiser today — add one:

```swift
extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Color.Palette {
    // Vapor — home screen
    case pageBackground
    case cardSurface
    case textPrimary
    case textSecondary
    case accent
    case live
    case panelRacing
    case panelToday
    case panelYesterday
    case panelTomorrow
}
```

…with the matching `switch` arms in `Color.tribuneru(_:)`:

```swift
case .pageBackground:  Color(hex: 0x070A0E)
case .cardSurface:     Color(hex: 0x121821)
case .textPrimary:     Color(hex: 0xEAF0F6)
case .textSecondary:   Color(hex: 0x8B97A6)
case .accent:          Color(hex: 0x5EEAD4)
case .live:            Color(hex: 0x4ADE80)
case .panelRacing:     Color(hex: 0x0A1715)
case .panelToday:      Color(hex: 0x08121F)
case .panelYesterday:  Color(hex: 0x0E0F22)
case .panelTomorrow:   Color(hex: 0x150E1E)
```

Keep the existing green cases until CX and Hate Zone are migrated too.

---

## 4. Geometry

### Screen

- Horizontal padding: **16**
- Screen header: 26 top, 22 bottom; title and date on one row,
  `alignment: .firstTextBaseline`, title leading / date trailing
- `.preferredColorScheme(.dark)` — this design is dark-only
- No fake status bar; the real one sits above the content

### Section panel

- Corner radius **20**, applied to the whole panel (header + grid together)
- Header padding: **28 top, 20 horizontal, 16 bottom**
- Grid padding: **0 top, 20 horizontal, 24 bottom**
- Gap between panels: **20**
- First panel has no top margin — it sits directly under the screen header
- Panels are inset by the screen's 16pt padding, i.e. **not** full-bleed

### Race card

- Background `cardSurface`, corner radius **8**, padding **12**
- Internal vertical spacing: **10** (Next to finish, Results) / **8** (Tomorrow)
- Grid: 2 equal columns, spacing **10**, cards stretch to fill
- An odd count leaves the last cell empty — Races tomorrow has 3

### Flag

- **16 × 12**, corner radius **1**, 0.5pt inset border white @ 0.22
- 2pt top offset when it sits beside a name that can wrap
- Keep `CachedImageView(imageUrl:)` with the existing flag URLs.
  The flags in the mockup are drawn placeholders, not assets to copy.

### Live dot

- 6 × 6 circle, `live`, beside the "Next to finish" title only

### Tab bar

- 0.5pt top divider, `textPrimary` @ 0.10
- Background `pageBackground` @ 0.95
- Padding: 10 top, 24 horizontal, 22 bottom
- Item: icon 20pt (1.7pt stroke), 6pt gap, 11pt SemiBold label, min width 72
- Active `accent`, inactive `textSecondary`
- The bicycle / no-entry icons stay as they are today

---

## 5. Section anatomy

| # | Section | Header holds | Card shows |
|---|---|---|---|
| 1 | Next to finish | live dot + title | flag, race name, **ETA** (mono 20), countdown, `km · class` |
| 2 | Results today | title + **spoiler toggle** | flag, race name @72%, winner name, finish time |
| 3 | Results yesterday | title + **spoiler toggle** | same as 2 |
| 4 | Races tomorrow | title + date | **start time** (mono 18), flag, race name, `ETA hh:mm` |

The spoiler toggles are the existing `isSpoilerModeResultsToday` /
`isSpoilerModeResultsYesterday` behaviour — unchanged, restyled. Sections 2 and
3 keep collapsing their cards when spoiler mode is on.

Empty states keep using `EmptyResultsCardView`; restyle its background from
`.blueMissingInfoBackground` to the section's own panel colour so an empty
section still reads as that section.

---

## 6. Touch targets

- Race cards are the tap targets — roughly 100pt tall, fine.
- **The spoiler chip is not.** As drawn it is 11pt text with 7pt padding —
  about 29pt tall. It must be expanded to a **44 × 44** tappable area in the
  app (keep the visual chip size, grow the hit area with `.contentShape` and
  padding). This is the one place the mockup is below the iOS minimum.
- Tab bar items already exceed 44pt.

---

## 7. Work to do

1. `Colors.swift` — hex initialiser + the 10 new palette cases.
2. `TribuneruText` — the current `Style` enum has no 30/24/20/18/13pt cases and
   no Space Grotesk / Space Mono support. Either extend the enum with the ramp
   in §2 or add a `family` dimension; the ramp above is the full set needed.
3. `HomeRaces.MainView` — wrap each `build…View(representable)` call in a
   section panel (`VStack` of header + `LazyVGrid`, `.background(panelColour)`,
   `.cornerRadius(20)`), spacing 20, screen padding 16.
4. New card views for the four card shapes in §5. The existing
   `NextToFinishRaceRow`, `RaceFinishedRowView` and `TomorrowRaceCardView` are
   row-shaped, not card-shaped — these are new components, not restyles.
5. Bundle the two fonts and verify PostScript names.
6. Fix the spoiler chip hit area.

---

## 8. Things to confirm

- **Section → colour mapping** is my choice, not derived from anything: teal
  reads as "live" because it matches the accent, the rest just descend in hue.
  Reassign freely if another order feels more natural.
- **Sample data.** The races, riders and times on the artboards are plausible
  sample values, not a verified race calendar. Do not copy them into fixtures
  or tests.
- **Dark only.** There is no light variant of this palette. If the app ever
  needs one, it is a separate design pass, not a token flip.

## Text in SwiftUI
- **Do not use** `Text("...")` (or `Text(verbatim:)`) in Tribuneros UI.
- **Always use** `TribuneruText` for any on-screen text.
- **Always localize** fixed text with `L10n.tr("English key")` and add its Catalan value to a
  `scripts/l10n/fragments/*.json` file (see CLAUDE.md, "Localization"). Scraped data stays verbatim.

Example:
```swift
TribuneruText(
    content: L10n.tr("Team"),
    style: .size12WeightRegular,
    color: .tribuneru(.somecase),
    lineLimit: 1
)

# Colors
- Always use the design system color:
  - `Color.tribuneru(.somecase)`
- Avoid raw colors (`.red`, `Color(...)`, hex, etc.) unless explicitly requested.

Optional extra rule (often helpful): “Prefer `.tribuneru(...)` over `Color.tribuneru(...)` when the API supports it, for consistency with your earlier `TribuneruText(color: .tribuneru(.somecase))`.”

## Images
- Remote/URL images must use:
  - `CachedImageView(imageUrl: <someOptionalURL>, cornerRadius: 1)`
- Avoid `AsyncImage` / custom loaders unless necessary.

# Swift style: argument formatting
- If a call has **more than one argument**, use multiline formatting:

```swift
SomeStructOrClass(
    arg1: ...,
    arg2: ...,
    arg3: ...
)

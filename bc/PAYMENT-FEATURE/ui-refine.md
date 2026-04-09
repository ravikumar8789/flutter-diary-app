# Paywall UI refine: sticky CTA + responsive tokens

## Goals
1. **Sticky bottom:** Continue button (+ footer links) stay visible; header, benefits, and pricing scroll above.
2. **Responsive architecture:** Use `ResponsiveInfo` + `ResponsiveTokens` like other screens (padding, spacing, optional max content width).
3. **No regressions:** Premium flow, Analytics gate, loading/empty states, purchase/restore, bottom nav on Analytics.

---

## Constraint (must read before coding)

`PaywallContent` is used in two places:

| Host | Layout |
|------|--------|
| **PremiumScreen** | `Scaffold` → `body: PaywallContent()` — **bounded height** ✓ |
| **AnalyticsScreen** | `Expanded` → `ResponsiveBody(useScrollView: true)` → `_buildAnalyticsBody` → `PaywallContent` — paywall is **inside an outer `SingleChildScrollView`** |

**Problem:** Inside an unbounded-height scroll parent, `Column` + `Expanded` + inner `SingleChildScrollView` **will not work** (`Expanded` needs a finite max height).

**Fix (required for Analytics):** When the analytics body shows the paywall (non‑premium or premium error path), **do not** wrap that widget in `ResponsiveBody`’s scroll. Options:

- **A (recommended):** In `analytics_screen.dart`, branch at the `Expanded` child: if `!isPremium` (or paywall path), use `Expanded(child: PaywallContent())` **without** wrapping paywall in `ResponsiveBody(useScrollView: true)`. Keep `ResponsiveBody(useScrollView: true, …)` only for the full analytics column.
- **B:** Pass `ResponsiveBody(useScrollView: false)` when content is paywall — only works if the branching is explicit so paywall fills `Expanded` alone.

Implement **one** clear branch: *paywall mode* → full `Expanded` height to `PaywallContent`; *analytics mode* → existing `ResponsiveBody` + scroll.

---

## Implementation plan

### 1. `lib/widgets/paywall_content.dart`

**Layout**
- Root for success state: `Column(crossAxisAlignment: stretch)`:
  - `Expanded` → `SingleChildScrollView` with:
    - `ResponsiveTokens.screenPadding`-based horizontal padding (top padding can match `screenPaddingVertical` or `spacingM`).
    - Optional: `Align` + `ConstrainedBox(maxWidth: ResponsiveTokens.maxContentWidth)` *inside* the scroll so content column doesn’t stretch too wide on tablets (same idea as `ResponsiveBody`).
  - **Bottom block** (non-scrolling):
    - `SafeArea` with `top: false` **or** `MediaQuery.padding.bottom`-aware padding so home indicator is respected.
    - Horizontal padding = `ResponsiveTokens.screenPaddingHorizontal`.
    - `FilledButton` Continue (unchanged behavior).
    - Footer row Restore · Terms · Privacy (unchanged callbacks).

**Responsive**
- `import` `responsive_info.dart`, `responsive_tokens.dart`.
- `final info = ResponsiveInfo.of(context);` in `build` for main content.
- Replace fixed `24`, `28`, `16`, `20` with `spacingM/L`, `screenPadding` as appropriate.
- Icon circle: optional `info.value` for diameter on compact vs expanded (minor).

**States (no behavior change)**
- Loading: keep `Center(CircularProgressIndicator())`.
- Empty offering: keep centered message; optionally use responsive padding only.

**Pricing / benefits**
- No copy changes unless spacing tweaks break layout; logic unchanged.

**Analytics bottom nav**
- Paywall’s bottom block must sit **above** the `AppBottomNavigationBar`. Because `PaywallContent` is already inside `Column` → `Expanded` → … → above the nav, `SafeArea(bottom: true)` on the sticky block **or** extra `padding: EdgeInsets.only(bottom: 8)` is usually enough; verify on device — the nav is **sibling** below `Expanded`, so paywall body height is already “above nav”. **Do not** double-pad unless needed after visual check.

### 2. `lib/screens/analytics_screen.dart`

**Structural change (critical)**
- Refactor body so when premium gate shows `PaywallContent`, that tree is:
  - `Expanded(child: PaywallContent())`  
  — **not** inside `ResponsiveBody(useScrollView: true)`.
- When premium and analytics content shows, keep current:
  - `Expanded(child: ResponsiveBody(useScrollView: true, useSafeArea: false, child: analytics column))`.

**How to avoid duplicate provider watches**
- Options: extract a small `Widget` that watches `connectivity` + `premium` and returns either `PaywallContent` or the scrollable analytics body; **or** compute a boolean `showPaywall` inside existing `_buildAnalyticsBody` and **lift** the branching one level up so `Expanded` chooses the correct child.

**Offline**
- Unchanged: offline UI still not paywall; still inside scroll path if that’s current behavior — verify after refactor that offline branch still gets `ResponsiveBody` scroll as today.

### 3. `lib/screens/premium_screen.dart`

- Likely **no change** unless `PaywallContent` needs `SafeArea` for notch (Scaffold usually handles with AppBar).
- Smoke-test: non-premium → paywall sticky CTA; premium → details unchanged.

---

## Testing checklist (nothing broke)

- [ ] **Premium → Paywall:** scroll benefits/pricing; Continue fixed at bottom; Restore works.
- [ ] **Analytics (not premium, online):** paywall fills area above bottom nav; Continue visible; scroll only middle; tab switch still works.
- [ ] **Analytics (premium):** weekly/monthly scroll unchanged.
- [ ] **Analytics offline:** offline message unchanged.
- [ ] **Purchase / restore:** same as before; snacks still show.
- [ ] **Tablet / wide:** content respects `maxContentWidth` if applied; no horizontal overflow.
- [ ] **Large text (accessibility):** inner scroll still scrolls; sticky footer may grow — verify no overlap.

---

## Out of scope (this pass)

- Terms / Privacy URLs (still TODO).
- Changing benefit copy or count.

---

## Summary

| File | Action |
|------|--------|
| `paywall_content.dart` | Column + Expanded scroll + sticky footer; wire `ResponsiveInfo` / `ResponsiveTokens`. |
| `analytics_screen.dart` | Branch so paywall is **not** inside outer scrollable `ResponsiveBody`. |
| `premium_screen.dart` | Verify only; adjust if SafeArea needed. |

After implementation, run `flutter analyze` on touched files.

---

## Implemented (2026-03-26)
- `paywall_content.dart`: sticky CTA + footer, scrollable block, `ResponsiveInfo` / `ResponsiveTokens`.
- `analytics_screen.dart`: `_buildAnalyticsExpandedContent` — paywall outside `ResponsiveBody` scroll; offline + premium analytics unchanged pattern.

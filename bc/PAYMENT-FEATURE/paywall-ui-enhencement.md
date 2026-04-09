# Paywall UI Enhancement Plan

## Goal
Update `PaywallContent` to match the reference design (Cat.io Pro style) while using the app's InnerGlow theme (coral primary, warm beige, Nunito).

## Theme Reference
- **Primary:** Coral/salmon `#E98463` (theme.colorScheme.primary)
- **Background:** Warm beige/cream (scaffoldBackgroundColor)
- **Surface:** Cards use surfaceColor, surfaceVariant for pricing container
- **Text:** textPrimaryColor / onSurface for titles, onSurfaceVariant for descriptions
- **Font:** Nunito (via theme.textTheme)

## UI Structure (Top → Bottom)

### 1. Header
- **Icon:** `Icons.workspace_premium` in circular container (primary bg or primary color), size ~64
- **Title:** "Get Premium" (headlineMedium, bold)
- **Subtitle:** "See what shapes your week, month, and mood." (bodyLarge, onSurfaceVariant)

### 2. Benefits List (7 items)
Each row: checkmark icon (primary) + Column(title, description)
- Title: bodyLarge, fontWeight 600
- Description: bodyMedium, onSurfaceVariant

| # | Title | Description |
|---|-------|-------------|
| 1 | Discover what shaped your week | AI recap of your patterns and highlights |
| 2 | See how your mood changes over time | Charts and trends across weeks and months |
| 3 | Find out how habits affect your mood | See which habits help or hurt your mood |
| 4 | See what you think about most | Your most common topics and themes |
| 5 | Track your consistency and streaks | Journaling and self-care streaks to stay motivated |
| 6 | Get personalized recommendations | AI suggestions based on your entries |
| 7 | See your monthly story | Your journey and growth over the month |

### 3. Pricing Section
- Container: surfaceVariant background, rounded corners (12–16)
- Layout: Row with 2 plan cards side-by-side (or wrap if many packages)
- **Plan card:** Tap to select
  - Selected: primary border (2px), checkmark circle filled
  - Unselected: outline border (surfaceVariant)
  - Content: Plan name (bold), price, sub-price (e.g. "Only $X/mo")
  - Badge: "X% OFF" for annual when applicable (top-left of card)
- Use `PackageType.annual` and `PackageType.monthly`; show Lifetime if present

### 4. CTA Button
- Full-width FilledButton
- Label: "Continue" or "Subscribe"
- Use theme elevatedButtonTheme (coral, rounded 12)
- Loading state: CircularProgressIndicator

### 5. Footer
- Row: "Restore Purchases" | "Terms" | "Privacy"
- TextButton style, small font (labelMedium)
- Terms/Privacy: optional links (can be placeholders or URLs)

## Implementation Notes

### File
- `lib/widgets/paywall_content.dart`

### Changes
1. Replace 2 benefits with 7 benefits (title + description format)
2. Replace RadioListTile with selectable plan cards (side-by-side)
3. Add discount badge for annual package (compute % if monthly exists)
4. Update header: "Get Premium" + locked subtitle
5. Add footer: Restore | Terms | Privacy
6. Use `Icons.check` or `Icons.check_circle` for benefit checkmarks
7. Use theme colors throughout (no hardcoded colors except white on primary)

### Package Label Mapping
- `PackageType.monthly` → "Monthly"
- `PackageType.annual` → "Yearly"
- `PackageType.lifetime` → "Lifetime"

### Responsive
- Plan cards: `Expanded` in Row when 2 packages; if 3+, use Wrap or horizontal scroll
- Padding: 24 horizontal, consistent vertical spacing (16–24)

### No Changes To
- PremiumScreen, AnalyticsScreen (PaywallContent usage)
- Premium logic, purchase flow, restore flow

---

## Implementation Complete
- `lib/widgets/paywall_content.dart` updated per plan
- Header: "Get Premium" + "See what shapes your week, month, and mood."
- 7 benefits with checkmark + title + description
- Side-by-side plan cards with selection state, discount badge for yearly
- CTA "Continue", footer Restore · Terms · Privacy

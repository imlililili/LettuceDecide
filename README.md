# LettuceDecide

LettuceDecide is an iOS app that turns a week of "how busy am I" answers and what's already in your fridge into a full week of meals — filtering out anything unsafe for your allergies or dietary restrictions along the way — and hands you a shopping list for whatever's still missing.

## What it does

- **Calendar** — set how busy you are for each day of the week (relaxed / normal / busy), then generate a full 7-day meal plan. Each day's recipe respects that day's time budget (a "busy" day only gets quick, simple recipes) and the plan never repeats the same recipe twice in a week unless it genuinely has no other safe option. Review the week and confirm the days you actually want to cook.
- **Home** — your dashboard. The top half shows cards for every meal you've confirmed (recipe photo + name), sorted by date; the bottom half is your shopping list — automatically built from what your confirmed recipes need that isn't already in your pantry.
- **Pantry** — track what ingredients you have on hand, with quantities and units.
- **Settings** — manage allergens, dietary restrictions, and other longer-term food preferences. These are enforced strictly: the weekly planner only ever proposes recipes that pass your allergen and dietary filters first.

Recipe data comes from the [Spoonacular API](https://spoonacular.com/food-api), including full step-by-step instructions and ingredient quantities/units shown directly in the app (with attribution to the original source, per Spoonacular's terms of use) — you never have to leave the app to see how to cook something.

## Why it's designed this way

A few principles run through the whole app:

- **Fail closed on allergens.** If an ingredient's allergen data can't be verified, it's treated as unsafe whenever the user has any dietary restriction — never assumed safe by default.
- **Never guess a conversion.** Ingredient quantities only get combined or converted when it's mathematically safe to do so — e.g. tablespoons and cups convert to millilitres using fixed, well-known ratios. Converting between fundamentally different kinds of measurement (say, turning a volume into a weight) would require guessing an ingredient's density, so the app refuses to do it and keeps those quantities as separate, honest entries instead.
- **Be honest about uncertain data.** If Spoonacular reports a quantity in a unit that doesn't actually mean what it looks like (e.g. "servings" reported as if it were a count of items), the app flags it and shows "Amount unclear — check the recipe" rather than presenting a fabricated-looking number. The same honesty applies to cached data: if the app falls back to a cached recipe because of a network issue, the UI says so.

## Architecture

LettuceDecide follows MVVM with an explicit Use Case layer sitting between the ViewModels and the domain/data layer:

```
View → ViewModel (@MainActor, ObservableObject) → Use Case (struct, execute()) → Domain Model + Repository/Store protocol
```

Each use case has a single, testable responsibility, a typed `LocalizedError` enum with human-readable failure messages (where the operation can actually fail), and unit test coverage for both the happy path and failure paths. Two are deliberately infallible by design and documented as such rather than padded out with an empty error enum.

Pure business logic that doesn't need I/O — matching recipes against pantry contents, building a week's assignment, merging shopping list quantities — is kept in dependency-free types (`PantryMatcher`, `WeeklyPlanBuilder`, ingredient-merging helpers) so it can be unit tested without mocking a network call.

Persistence follows one consistent pattern across the app: a `Storing` protocol per domain concept (pantry, preferences, schedule, confirmed meals, shopping list, recipe cache), backed by a Codable + JSON file store for the real app and an in-memory store for tests. Recipe data specifically goes through a decorator (`CachingRecipeRepository`) that falls back to cached results only on a genuine network failure — never on a missing API key or a malformed response, since those aren't reasons to pretend cached data is current.

Navigation is a bottom tab bar: Home, Pantry, Calendar, Settings — each with its own independent navigation stack.

### Ingredient identity and unit handling

Two recurring problems in recipe data get handled deliberately rather than papered over:

- **Ingredient identity.** The same ingredient often shows up under different names across recipes (e.g. "garlic" vs "garlic clove"). Shopping list items are matched by Spoonacular's own internal ingredient ID first, falling back to a normalized name only when no ID is available.
- **Unit consistency.** Volume units (millilitres, cups, tablespoons, teaspoons) are freely convertible using fixed cooking-approximation ratios, so they merge into a single line rather than fragmenting a shopping list into several entries for the same bottle of oil. Weight and count never cross-convert with volume or each other, since that would require guessing. Pantry storage takes this a step further and normalizes every volume entry down to millilitres on the way in, so the pantry only ever holds three canonical unit kinds: grams, pieces, and millilitres.

## Tech stack

- SwiftUI (MVVM)
- Swift Testing (`@Test`, `#expect`) for unit tests, XCUITest for UI tests
- Spoonacular API for recipe data
- JSON + Codable for local persistence (no SwiftData, kept consistent across the whole persistence layer)
- GitHub Actions CI (macOS runner, builds and runs the full test suite against an iOS Simulator on every push)

## Getting started

1. Clone the repo and open `LettuceDecide.xcodeproj` in Xcode.
2. Get a free API key from [Spoonacular](https://spoonacular.com/food-api) and add it to `LettuceDecide/Resources/Config.plist` (gitignored — this file is never committed):
   ```xml
   <key>SpoonacularAPIKey</key>
   <string>YOUR_KEY_HERE</string>
   ```
3. Build and run. Without a configured key, the app falls back to a small set of mock recipes so the UI is still fully explorable — it will never silently pretend mock data is live.

## Testing

```
xcodebuild test -scheme LettuceDecide -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Unit tests are organized one file per use case (`XxxUseCaseTests.swift`) plus domain model and view model tests. UI tests are grouped by user flow rather than by screen (e.g. `PantryFlowUITests`, `CookingAndShoppingFlowUITests`, `SettingsFlowUITests`), so each file tells the story of one thing a user actually does in the app.

## Project workflow

Every feature is developed on its own branch and merged into `main` only after the full test suite passes locally — nothing is committed directly to `main`. Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `test:`, `docs:`).

## Status

Core flows are implemented and tested: allergen/dietary-safe weekly meal planning against pantry and busyness constraints, day-by-day plan confirmation, an aggregated and unit-merged shopping list, pantry management, and live Spoonacular integration.

The checklist below tracks feature-level progress at a glance — check the commit history and open branches for exact detail.

### Done

- [x] MVVM + explicit Use Case layer architecture, one typed error enum and test file per use case
- [x] Bottom tab navigation: Home, Pantry, Calendar, Settings
- [x] Live Spoonacular integration with an offline cache fallback (`CachingRecipeRepository`)
- [x] Allergen and dietary-restriction filtering, fail-closed on unverified data
- [x] Busyness-aware weekly meal plan generation (`GenerateWeeklyMealPlanUseCase` + `WeeklyPlanBuilder`), no repeated recipes in the same week
- [x] Day-by-day plan confirmation flow, confirmed meals persisted and shown on Home
- [x] Shopping list: ingredient-ID-based merging, safe volume-unit conversion, honest "amount unclear" handling for unusable source units
- [x] Pantry storage normalized to three canonical units (grams / pieces / millilitres)
- [x] Cooking deduction (`UpdateInventoryAfterCookingUseCase`) using the same safe volume conversion as the shopping list
- [x] Reactive local updates (pantry changes, shopping list) without unnecessary network re-fetches

### In progress

- [ ] Moving a purchased shopping list item into the pantry automatically
- [ ] Removing a meal from the Home dashboard once it's marked as cooked
- [ ] Clearer handling for Spoonacular API errors (distinguishing a real network failure from a quota/payment-required response)

### Not started

- [ ] Shopping list UI: manual check-off/remove without going through the pantry-purchase flow
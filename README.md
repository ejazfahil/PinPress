# PinPress

**A Pinterest-style iOS app built in SwiftUI — with a custom, cost-aware image-caching layer and a polished, accessibility-minded UI.**

![Swift](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS-blue)
![Combine](https://img.shields.io/badge/Combine-reactive-green)
![Xcode](https://img.shields.io/badge/Xcode-16%2B-147EFB)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)

> **Status:** Working single-screen-set demo app. All four tabs render and the feed,
> caching, swipe carousel, infinite scroll, and pull-to-refresh are fully implemented
> against demo data (random images from `picsum.photos`). Search and the AI mood-board
> are intentionally mocked.

---

## Overview

PinPress is a Pinterest-inspired feed app written entirely in **SwiftUI**. It
demonstrates a custom asynchronous image-loading and caching pipeline, a multi-image
swipe carousel per pin, infinite scrolling, and an MVVM feed architecture — all with
attention to Human Interface Guidelines details such as accessibility labels,
predictable image sizing, and a refreshable feed.

The entire app is currently implemented in two source files (`PinPressApp.swift` and
`ContentView.swift`), making it a compact, readable reference for these SwiftUI patterns.

---

## Features

### Custom image caching (the centrepiece)

The heart of the app is a hand-rolled caching layer built on `NSCache`, paired with a
custom `CachedAsyncImage` view — rather than relying on the framework's `AsyncImage`.

- **`ImageCache`** is a singleton wrapping `NSCache<NSURL, UIImage>` configured with a
  **count limit of 500 images** and a **total cost limit of ~150 MB**. On insert, each
  image's cost is estimated from its encoded byte size (`pngData()?.count`), so the cache
  evicts based on real memory pressure rather than a naive item count.
- **`CachedAsyncImage`** drives the load lifecycle: on appearance it **checks the cache
  first** and returns immediately on a hit; on a miss it fetches via `URLSession`
  off the main thread (`async/await`), decodes the image, **inserts it into the cache**,
  and updates the view. State is keyed to the URL (`.task(id: url)`) so the right image
  loads even as cells are recycled.
- **Graceful fallbacks:** while loading, a `ProgressView` is shown; on failure or a nil
  URL, a decorative "Image unavailable" placeholder is rendered. Loaded images fade in
  with a short opacity transition.

This gives Pinterest-like scroll performance: images are fetched once, kept warm in
memory, and re-displayed instantly on revisit — with no main-thread blocking.

### Pinterest-style feed

- A two-column `LazyVGrid` of rounded, shadowed pin tiles that lazily instantiate cells
  as you scroll.
- Each tile shows a category chip (over `.ultraThinMaterial`) and a title.

### Multi-image swipe carousel

- Every `Pin` can hold **multiple image URLs**. `PinTileView` presents them in a paged
  `TabView` (`.tabViewStyle(.page)`) so users can **swipe through images** within a
  single tile, complete with page indicators.

### Infinite scroll

- `HomeFeedViewModel.maybeLoadMore(whenShowing:)` triggers when a tile within a
  threshold of the end appears, appending the next "page" of pins after a simulated
  network latency — wired to extend cleanly to a real paginated API.

### Pull-to-refresh

- The feed is `.refreshable`, resetting the pin set via the view model.

### Tab-based navigation

Four tabs, each in its own `NavigationStack`:

- **Home** — the pin feed described above.
- **Search** — a search field UI (results are a placeholder/mock).
- **Create** — a **mock "AI Mood Board" generator**: pick mood / colour / style and a
  free-text prompt, then "generate" a placeholder image after simulated latency. (No real
  generative backend; it returns a random demo image.)
- **Profile** — a static profile placeholder.

### Accessibility & HIG details

Throughout the code: accessibility labels on pins, categories, pickers and search;
decorative placeholders marked `accessibilityHidden`; combined picker elements; and
predictable fixed tile heights.

---

## Architecture

The app follows an **MVVM** pattern for its feed:

- **Model** — `Pin` (`Identifiable`, `Hashable`): id, title, `imageURLs`, category.
- **View** — `RootTabView`, `HomeFeedView`, `PinTileView`, `SearchView`,
  `AIMoodBoardView`, `ProfileView`, and the reusable `CachedAsyncImage` / `PickerRow`.
- **ViewModel** — `HomeFeedViewModel` (`@MainActor`, `ObservableObject`): owns the
  `@Published` pin list and loading state, plus infinite-scroll and refresh logic.
- **Services / infrastructure** — `DemoImageService` (seed-based `picsum.photos` URL
  generation and demo pin construction) and the `ImageCache` singleton.

---

## Tech Stack & Tools

- **Swift 5**, **SwiftUI**
- **Combine** (`ObservableObject` / `@Published`)
- **UIKit interop** — `UIImage`, `NSCache`
- **Swift Concurrency** — `async/await`, `Task`, `@MainActor`
- **URLSession** for networking
- **Xcode 16+**, targeting iOS

---

## Project Structure

```
PinPress/
├── PinPressApp.swift        # @main App entry point
├── ContentView.swift        # Entire app: cache, views, view model, models, services
├── PinPress.xcodeproj.zip   # Zipped Xcode project
├── PinPress.key             # Keynote slide deck for the project
└── README.md
```

> Note: the source is currently organised as two flat Swift files rather than separate
> `Models/ Views/ ViewModels/` folders. Splitting these out is a natural next step
> (see *Future Work*).

---

## Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/ejazfahil/PinPress.git
   ```
2. Unzip `PinPress.xcodeproj.zip` and open the resulting `PinPress.xcodeproj` in
   **Xcode 16+**.
3. Select an iPhone simulator (iOS 17+ recommended for the SwiftUI APIs used).
4. Build and run (⌘R). The feed loads demo images from `picsum.photos`, so an internet
   connection is needed to see images.

---

## Challenges

- **Smooth scrolling with remote images:** solved with cost-aware `NSCache` eviction and
  a cache-first async loader so cells reuse cleanly without main-thread stalls.
- **Correct image binding under cell reuse:** addressed by keying the load task to the
  image URL so a recycled cell always shows the right image.
- **Infinite scroll without flicker:** a threshold-based prefetch appends pages ahead of
  the scroll position.

## Future Work

- Replace demo data with a real paginated backend (Firebase / REST) and real search.
- Add a true masonry/staggered grid for variable-height tiles.
- Persist images to disk for an offline mode (currently memory-only caching).
- Add likes, boards, save functionality, and authentication.
- Split the monolithic `ContentView.swift` into `Models/`, `Views/`, `ViewModels/`,
  and `Services/` for scalability.

## Conclusion

PinPress is a compact, honest demonstration of production-relevant SwiftUI techniques —
most notably a custom, memory-aware image cache and async loader — wrapped in a clean,
accessible Pinterest-style interface. It is structured to grow into a full app by
swapping demo services for real backends.

---

*Author: Fahil Ejaz — iOS / SwiftUI*

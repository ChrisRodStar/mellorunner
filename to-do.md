# Implementation To-Do List

This document outlines the step-by-step tasks required to resolve all defects, missing host modules, and behavioral discrepancies identified in the AidokuRunner parity audit.

---

## Phase 1: Critical Bug Fixes (Wire Format & Host Signatures)

- [x] **Task 1: Fix `NetRequest.Method` enum and missing HTTP methods**
  - **Target File**: [`Sources/MelloRunner/Host/Network/NetRequest.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Network/NetRequest.swift)
  - **Changes**:
    1. Fix the integer raw values for `head` and `delete` (currently inverted):
       - Change `case head = 4` to `case head = 3`.
       - Change `case delete = 3` to `case delete = 4`.
    2. Add the 4 missing HTTP methods supported by upstream:
       - `case patch = 5`
       - `case options = 6`
       - `case connect = 7`
       - `case trace = 8`
    3. Update the `methodString` computed property to return `"PATCH"`, `"OPTIONS"`, `"CONNECT"`, and `"TRACE"`.
  - **Verification**: Update [`Tests/MelloRunnerTests/Host/NetworkImportsTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Host/NetworkImportsTests.swift) to verify integer discriminants (0 through 8) and `URLRequest.httpMethod` strings.

- [x] **Task 2: Fix `net.set_timeout` parameter signature**
  - **Target File**: [`Sources/MelloRunner/Host/Network/NetworkImports.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Network/NetworkImports.swift)
  - **Changes**:
    1. Update the function type signature at line 184:
       - Change `parameters: [.i32, .i32]` to `parameters: [.i32, .f64]`.
    2. Update argument extraction:
       - Read `args[1].f64` (reinterpreting bit pattern as `Float64` / `Double`) instead of `args[1].i32`.
       - Set `request.timeoutInterval = max(1.0, timeoutSeconds)`.
  - **Verification**: Add a test in [`Tests/MelloRunnerTests/Host/NetworkImportsTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Host/NetworkImportsTests.swift) invoking `net.set_timeout` with floating-point parameters (e.g. `30.0`) and validating `request.timeoutInterval`.

---

## Phase 2: Missing Host Modules

- [ ] **Task 3: Implement `CanvasImports` (15 2D graphics functions)**
  - **New File**: [`Sources/MelloRunner/Host/Canvas/CanvasImports.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Canvas/CanvasImports.swift)
  - **Modified Files**:
    - [`Sources/MelloRunner/Bridge/HostBridge.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Bridge/HostBridge.swift)
    - [`Sources/MelloRunner/Session/SourceSessionConfiguration.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSessionConfiguration.swift)
  - **Changes**:
    1. Implement a `CanvasContext` class wrapping `CGContext` with `CGAffineTransform` stack management.
    2. Implement all 15 host functions in the `"canvas"` module:
       - `canvas.new_context(width: i32, height: i32) -> i32`
       - `canvas.set_transform(desc: i32, a: f64, b: f64, c: f64, d: f64, tx: f64, ty: f64)`
       - `canvas.draw_image(desc: i32, imageRef: i32, x: f64, y: f64)`
       - `canvas.copy_image(desc: i32, imageRef: i32, sx: f64, sy: f64, sW: f64, sH: f64, dx: f64, dy: f64, dW: f64, dH: f64)`
       - `canvas.fill(desc: i32, r: f64, g: f64, b: f64, a: f64, x: f64, y: f64, w: f64, h: f64)`
       - `canvas.stroke(desc: i32, r: f64, g: f64, b: f64, a: f64, lineWidth: f64, x: f64, y: f64, w: f64, h: f64)`
       - `canvas.draw_text(desc: i32, text: i32, textLen: i32, x: f64, y: f64, font: i32)`
       - `canvas.get_image(desc: i32) -> i32`
       - `canvas.new_font(size: f64, weight: i32) -> i32`
       - `canvas.system_font(size: f64, weight: i32) -> i32`
       - `canvas.load_font(data: i32, dataLen: i32, size: f64) -> i32`
       - `canvas.new_image(data: i32, dataLen: i32) -> i32`
       - `canvas.get_image_data(imageRef: i32) -> i32`
       - `canvas.get_image_width(imageRef: i32) -> i32`
       - `canvas.get_image_height(imageRef: i32) -> i32`
    3. Store canvas contexts, fonts, and bitmap images in `ResourceStore`.
    4. Register `canvasImports.register(into: &imports, store: store)` inside `HostBridge.makeImports(store:)`.
  - **Verification**: Create [`Tests/MelloRunnerTests/Host/CanvasImportsTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Host/CanvasImportsTests.swift) testing context creation, drawing, image slicing, and PNG/JPEG export.

- [ ] **Task 4: Implement WebKit webview handler for `JavaScriptImports`**
  - **New File**: [`Sources/MelloRunner/Host/JavaScript/WebKitHandler.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/JavaScript/WebKitHandler.swift)
  - **Modified File**: [`Sources/MelloRunner/Host/JavaScript/JavaScriptImports.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/JavaScript/JavaScriptImports.swift)
  - **Changes**:
    1. Implement a `@MainActor` `WebKitHandler` managing `WKWebView`, `WKNavigationDelegate`, `WKUserContentController`, and `WKHTTPCookieStore`.
    2. Replace the 10 stubbed functions in `JavaScriptImports.swift`:
       - `webview_create() -> i32`
       - `webview_set_rule_list(desc, ptr, len) -> i32`
       - `webview_load(desc, reqDesc) -> i32`
       - `webview_load_html(desc, htmlPtr, htmlLen, urlPtr, urlLen) -> i32`
       - `webview_wait_for_load(desc) -> i32`
       - `webview_eval(desc, ptr, len) -> i32`
       - `webview_eval_async(desc, ptr, len) -> i32`
       - `webview_add_user_script(desc, ptr, len, atEnd, mainFrameOnly) -> i32`
       - `webview_get_cookies(desc) -> i32`
       - `webview_delete_cookie(desc, namePtr, nameLen, valPtr, valLen, domainPtr, domainLen) -> i32`
  - **Verification**: Add test cases in [`Tests/MelloRunnerTests/Host/JavaScriptImportsTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Host/JavaScriptImportsTests.swift) verifying HTML loading and cookie handling.

---

## Phase 3: `SourceSession` Runtime Behaviors

- [ ] **Task 5: Implement `loadSettingsDefaults` on session initialization**
  - **Target File**: [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. Add private method `loadSettingsDefaults(from settings: [Setting])`.
    2. Recursively inspect settings (including groups and pages) and extract `defaultValue`.
    3. Register any non-nil default values into `bridge.settingsStore` under the session namespace.
    4. Call `loadSettingsDefaults` on `staticSettings` during `init` and on dynamic settings in `getSettings()`.
  - **Verification**: Add a test in [`Tests/MelloRunnerTests/Session/SourceSessionTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Session/SourceSessionTests.swift) verifying that `settingsStore` returns the manifest default for an untouched setting key.

- [ ] **Task 6: Dynamic base URL resolution**
  - **Target File**: [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. Change `urls` from a pure computed property to a property backed by a thread-safe array `resolvedUrls: OSAllocatedUnfairLock<[URL]>`.
    2. During `init`, initialize `resolvedUrls` with the manifest URLs.
    3. If `features.providesBaseUrl` is true, invoke `getBaseUrl()` and, if valid and not already present, prepend it to `resolvedUrls`.
  - **Verification**: Add a test in [`Tests/MelloRunnerTests/Session/SourceSessionTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Session/SourceSessionTests.swift) verifying that an extension exporting `get_base_url` updates `session.urls`.

- [ ] **Task 7: Synthesize extra settings (`getExtraSettings`)**
  - **Target File**: [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. Implement `getExtraSettings() -> [Setting]`:
       - If `languages.count > 1`, synthesize a language selection setting (`"languages"` or `"language"` depending on `config.languageSelectType`).
       - If `config.allowsBaseUrlSelect == true` and `urls.count > 1`, synthesize a base URL picker setting (`"baseUrl"`).
    2. In `getSettings()`, prepend or append `getExtraSettings()` to the returned list.
  - **Verification**: Add a test verifying synthesized language and base URL settings on multi-language and multi-mirror manifests.

- [ ] **Task 8: Respect `hidesFiltersWhileSearching`**
  - **Target File**: [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. In `getSearchMangaList(query:page:filters:)`, check:
       ```swift
       let effectiveFilters = (query?.isEmpty == false && (manifest.config?.hidesFiltersWhileSearching ?? false)) ? [] : filters
       ```
    2. Pass `effectiveFilters` to guest encoding instead of the raw `filters` array.
  - **Verification**: Add a test confirming that filters are suppressed during keyword search when `hidesFiltersWhileSearching == true`.

- [ ] **Task 9: Default chapter language backfill**
  - **Target File**: [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. In `getMangaUpdate(manga:needsDetails:needsChapters:)`:
       - If `languages.count == 1`, iterate over `updatedManga.chapters` and set `chapter.language = languages.first` where `chapter.language == nil`.
  - **Verification**: Add a test confirming chapters without explicit language tags receive the sole source language.

- [ ] **Task 10: Stream partial manga updates in `makePartialHandler`**
  - **Target Files**:
    - [`Sources/MelloRunner/Session/SourceSessionConfiguration.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSessionConfiguration.swift)
    - [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. Add `partialMangaHandler: (@Sendable (Manga) -> Void)?` to `SourceSessionConfiguration`.
    2. In `makePartialHandler`, attempt decoding `Manga` if `HomePartialResult` decoding fails:
       ```swift
       if let manga = try? PostcardDecoder().decode(Manga.self, from: data) {
           var updated = manga
           updated.sourceKey = sessionKey
           configuration.partialMangaHandler?(updated)
       }
       ```
  - **Verification**: Add a test verifying that partial manga updates delivered via `env.send_partial_result` invoke `partialMangaHandler`.

- [ ] **Task 11: Tag search mapping helper (`matchingGenreFilter`)**
  - **Target File**: [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. Implement `public func matchingGenreFilter(for tag: String) async throws -> FilterValue?`:
       - Query filters via `getSearchFilters()`.
       - Find select or multi-select filters where `isGenre == true`.
       - Match `tag` against filter `options` or `ids` (case-insensitively).
       - Return `.select(id:value:)` or `.multiselect(id:included:excluded:)`.
  - **Verification**: Add a test verifying tag search mapping against static and dynamic genre filters.

- [ ] **Task 12: `Identifiable`, `Equatable`, and `clearCache()` on `SourceSession`**
  - **Target File**: [`Sources/MelloRunner/Session/SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift)
  - **Changes**:
    1. Conform `SourceSession: Identifiable, Equatable`:
       - `public var id: String { key }`
       - `public static func == (lhs: SourceSession, rhs: SourceSession) -> Bool { lhs.key == rhs.key }`
    2. Implement `public func clearCache() async`:
       - Clear stored image buffers, reset rate limiters, and flush WebKit cookies/website data.
  - **Verification**: Add tests verifying conformance and cache clearing.

---

## Phase 4: Final Validation

- [ ] **Task 13: Full Test Suite Execution & Lint Verification**
  - Run `swift test` across all targets.
  - Run `swift-format lint --recursive Sources Tests`.
  - Verify 100% test pass rate with zero warnings.

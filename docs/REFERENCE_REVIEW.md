# AidokuRunner reference review

Reviewed on October 1, 2026 to identify compatibility requirements and architecture concerns.

## Scope and provenance

Reference: local `Reference/AidokuRunner`, upstream <https://github.com/Aidoku/AidokuRunner>, revision `cc4d06ff399e7169b9c647bccede7cb29bc805c6`. Read every tracked Swift file and text/configuration file: 61 tracked files total, including 52 Swift files. The remaining binary fixture was inspected for header, section boundaries, imports, exports, byte count, and SHA-256; its instructions were not disassembled or executed. Generated build files, dependency checkouts, and Git internals were outside this review.

The upstream README states source-available copyright restrictions and a distribution exception for Aidoku. This review uses upstream implementation details to identify compatibility questions and design concerns. It copies no implementation or fixture into MelloRunner, makes no clean-room claim, and establishes no distribution clearance. The proposed organization is informed by this inspection. Upstream observations are evidence of behavior at this revision, not a completed source extension specification.

## File-by-file inventory

Paths below are relative to the reference checkout. Entries under each directory account for every tracked file.

### Package and configuration

| File | Responsibility and architectural implication |
| --- | --- |
| `.gitignore` | Excludes build output, user state, and credentials-related files. |
| `.swiftlint.yml` | Broad lint configuration with many exclusions; style configuration does not enforce resource ownership or ABI correctness. |
| `.swiftpm/xcode/package.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | Xcode workspace bookkeeping. |
| `.swiftpm/xcode/xcshareddata/xcschemes/AidokuRunner-Package.xcscheme` | Package build, launch, profile, and archive configuration. |
| `.swiftpm/xcode/xcshareddata/xcschemes/AidokuRunner.xcscheme` | Similar configuration with an explicit test target. |
| `Package.swift` | One library target; Wasm3 and SwiftSoup dependencies; SwiftLint build plugin; Swift 6 mode; older deployment targets. |
| `Package.resolved` | Records exact dependency revisions; Wasm3 follows a branch in the manifest. MelloRunner should document the exact engine revision selected. |
| `README.md` | Describes Wasm3 execution and upstream distribution restrictions. |

### Sources/AidokuRunner

| File | Responsibility and architectural implication |
| --- | --- |
| `Runner.swift` | Public source operations and optional defaults; also exposes raw host-handle storage. Keep handles internal in MelloRunner. |
| `Source.swift` | Package loading, metadata, runner construction, feature checks, default settings, language defaults, filter policy, and WebKit cache clearing. Separate loading, execution, and Melloku policy. |
| `Interpreter.swift` | Actor owns Wasm3 module, host store, callbacks, import registration, feature discovery, export invocation, result framing, decoding, and restart. Split these responsibilities behind an internal execution boundary. |
| `SourceLibrary.swift` | Minimal import-library linking protocol. Required import validation should be explicit. |
| `GlobalStore.swift` | Instance-associated integer handles backed by `[Int32: Any]`; monotonically advances handles and resets when empty. Define resource kinds, limits, stale-handle behavior, and release rules. |
| `SettingsStore.swift` | Shared UserDefaults access and SwiftUI bindings. Inject storage; keep SwiftUI binding creation in Melloku. |
| `DemoSource.swift` | Demo data and a non-Wasm runner. Put independently authored test doubles in test support; app preview content belongs with the app. |

### Sources/AidokuRunner/Imports

| File | Responsibility and architectural implication |
| --- | --- |
| `Env.swift` | Logging, compatibility abort, blocking sleep, partial results. Specify partial-result framing and cancellation. |
| `Std.swift` | Host-handle destruction, buffer access, current date, UTC offset, date parsing. Separate memory access from clock/date services. |
| `Defaults.swift` | Namespaced settings access with Postcard values and guest-memory framing. Separate ABI conversion from persistence. |
| `Net.swift` | Request mutation, individual/batch execution, rate limiting, response access, image decoding, HTML conversion. Separate request ABI from injected transport and host resources. |
| `Html.swift` | SwiftSoup parsing, queries, navigation, mutation, and handles. Keep DOM backend details inside the host implementation. |
| `JavaScript.swift` | JavaScriptCore and WebKit imports, async evaluation bridges, content rules, scripts, cookies. Give JavaScript and browser resources separate owners. |
| `Canvas.swift` | Canvas imports plus path/style decoding, image/font creation, drawing, and graphics helpers. Separate graphics wire values from rendering; establish iOS/macOS parity. |

### Sources/AidokuRunner/Models

| File | Responsibility and architectural implication |
| --- | --- |
| `Chapter.swift` | Chapter fields with epoch-date and URL encoding. Document field order and primitive widths. |
| `Cookie.swift` | Serializable HTTP cookie representation. Browser policy remains an injected service responsibility. |
| `DeepLink.swift` | Optional manga, chapter, and listing result. Optional capability needs distinct handling. |
| `Filter.swift` | Filter descriptors, JSON defaults, selection metadata. Separate descriptor JSON from binary contracts. |
| `FilterValue.swift` | Tagged search inputs with explicit binary encoding order. Preserve contract tags independently of public model organization. |
| `Home.swift` | Home layouts, nested links, partial results, binary tags, and source-key normalization. Separate wire decoding from normalization and event delivery. |
| `KeyKind.swift` | Manga/chapter migration selector. Document ABI values. |
| `Listing.swift` | Listing value and forgiving decode defaults. Define when defaults are valid rather than masking malformed binary values. |
| `Manga.swift` | Manga value, binary fields, merge behavior, and home-link convenience. Keep merge/presentation policy outside wire coding. |
| `MangaPageResult.swift` | Paginated entries and source-key normalization. |
| `MangaWithChapter.swift` | Combined manga/chapter result. |
| `Page.swift` | Public page values, UI image payloads, internal wire values, and handle resolution. Invalid image handles currently disappear through `compactMap` in the caller. Make invalid-result handling explicit. |
| `Response.swift` | Image-processing request/response wire values and image handles. These are distinct from general HTTP transport results. |
| `Setting.swift` | Settings descriptors, JSON and binary coding, nested options, login metadata, and presentation hints. Keep schema support while Melloku owns presentation. |
| `SourceError.swift` | Guest/source error categories. Distinguish these from engine traps, invalid ABI data, host-service errors, and cancellation. |
| `SourceFeatures.swift` | Optional export capability flags. Validate signatures as well as export presence. |
| `SourceInfo.swift` | Package metadata, static listings, and source configuration. Metadata must be available without executing guest code. |
| `Codable/EpochDate.swift` | Epoch seconds with encoder-specific optional representation. Put binary adaptation in the wire layer. |
| `Codable/LocalizedString.swift` | JSON string-or-localization-map representation and current-locale selection. Parsing and locale choice are separate concerns. |
| `Codable/URLAsString.swift` | URL-string encoding with encoder-specific option tags. Keep ABI encoding explicit. |

### Sources/AidokuRunner/Utilities and Extensions

| File | Responsibility and architectural implication |
| --- | --- |
| `Utilities/BlockingTask.swift` | Unstructured task plus semaphore bridge and unchecked Sendable state. Do not run this pattern on Swift's cooperative executor. |
| `Utilities/CallbackHandler.swift` | Callback registrations and retained partial state; removing callbacks leaves stored state behind. Scope events/state to an operation. |
| `Utilities/ExcludedFromCoding.swift` | Source identity wrapper that emits no binary data. Separate host identity from wire values. |
| `Utilities/IsolatedJSContext.swift` | Actor-owned JSContext, evaluation, and Promise continuations using shared global callback names. Define overlapping-call and cancellation behavior. |
| `Utilities/NetRequest.swift` | Mutable request builder and response storage in one value. Separate request creation from execution outcome. |
| `Utilities/PlatformImage.swift` | UIKit/AppKit image abstraction, with unchecked Sendable for NSImage. Keep native UI objects out of general source results. |
| `Utilities/Postcard/PostcardDecoder.swift` | Codable adapter consuming a sequential byte cursor. Validate UTF-8, boolean/option tags, integer widths, collection limits, and complete payload consumption. |
| `Utilities/Postcard/PostcardEncoder.swift` | Codable adapter with mutable buffer and collection-length patching; detects dictionary coding keys by type-name string. Use an explicit schema and avoid reliance on private Swift implementation names. |
| `Utilities/Postcard/VarInt.swift` | Varints and zigzag integers. Bound encoded length and overflow; test signed extremes. |
| `Utilities/RateLimit.swift` | Actor with wall-clock fixed windows. Use a monotonic clock for elapsed waits and bound request concurrency separately. |
| `Utilities/SinglePublisher.swift` | One callback sink per publisher. Prefer operation-scoped events with defined buffering and lifetime. |
| `Utilities/WebViewHandler.swift` | Main-actor WebKit owner, semaphore navigation wait, script messages, and pending continuations. Add failure, cancellation, handler removal, and shutdown contracts. |
| `Extensions/URL.swift` | Compatibility wrappers for older OS URL APIs. Deployment at OS 27 removes the need for these availability branches. |
| `Extensions/UUID.swift` | SHA-1-derived source storage identifier. Existing storage identity compatibility is a separate migration decision. |
| `Extensions/WKWebsiteDataStore.swift` | Source-specific browser stores and cache removal; resumes after scheduling removals, not after all removals complete. Make completion semantics explicit. |

### Tests/AidokuRunnerTests

| File | Responsibility and architectural implication |
| --- | --- |
| `AidokuRunnerTests.swift` | Loading, panic/restart, JavaScript and WebKit behavior; some tests depend on remote image loading. MelloRunner needs deterministic fixtures and separate network-dependent checks. |
| `ModelCodingTests.swift` | Manga encode/decode round trip. Round trips alone do not prove independent wire compatibility. |
| `Resources/Payload/source.json` | Metadata for the upstream test source. Inspected only; not adopted as a fixture. |
| `Resources/Payload/main.wasm` | 96,688-byte upstream binary. Six imports: `std.destroy`, `env.print`, `defaults.get`, `std.buffer_len`, `std.read_buffer`, `env.abort`. Exports memory, initialization/freeing, core operations, and several optional operations. It does not exercise every host namespace. |

Binary SHA-256: `36f5bce15a283037e0ce6e016df6b7775278427d4266969fe06a46db45efb5cb`.

## Design implications

The agreed folder layout, subsystem responsibilities, and implementation stages are documented in [Architecture](ARCHITECTURE.md).

The inspection identifies these questions for implementation:

- Which guest resources survive an invocation, and when are returned page/image handles released?
- Can the selected engine suspend host imports, or does it require bounded execution workers outside Swift's cooperative executor? Apple's [runtime explanation](https://developer.apple.com/videos/play/wwdc2021/10254/) describes the forward-progress risks of semaphore waits on future task work.
- How are pending JavaScript and WebKit operations cancelled, and how are script handlers and continuations released?
- Which observed defaults and error behaviors are part of the source contract, and which are upstream implementation choices?

The [Postcard specification](https://postcard.jamesmunns.com/wire-format) defines primitive encoding and requires a shared schema. It does not establish Aidoku's model field order or result framing. Record separate evidence for those bridge requirements before implementation.

Repeated export lookup, byte-array conversions in buffer access, per-call date formatter construction, and collection-prefix buffer replacement in the reference encoder are candidates for measurement. This review establishes no bottleneck or speed improvement. Keep benchmark tooling local; record fixture hashes, toolchain, hardware, configuration, warmups, and raw samples with any published measurements. Separate host-service waiting from runtime work.

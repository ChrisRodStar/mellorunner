# Development roadmap

## Completed milestones

- [x] **Milestone 1: WebAssembly engine selection & verification**
  - Evaluated candidate runtimes (WasmKit vs Wasm3 vs JavaScriptCore).
  - Selected and integrated WasmKit 0.4.1 under Apache 2.0 (LLVM Exception).
  - Recorded architectural decision in [`docs/decisions/0001-engine-selection.md`](decisions/0001-engine-selection.md).
- [x] **Milestone 2: Isolated execution foundation**
  - Implemented `RuntimeError`, `RuntimeValue`, `RuntimeEngine`, and `WasmInstance`.
  - Added `ExecutionSession` actor providing thread confinement, an invocation gate, and zero-copy guest memory borrowing (`withMemory`).
  - Implemented export function caching to avoid repeated export table lookups.
  - Verified `answer.wasm` execution (yielding 42), traps, bounds checks, and teardown in `ExecutionSessionTests` (14 passing tests in 0.005s).
  - Measured release performance in `mellorunner-benchmark` (4.67 µs instantiation, 7.29 µs actor invocation, 5.00 µs memory borrow).

- [x] **Milestone 3: Postcard binary wire format (`Serialization/Postcard/`)**
  - Implemented zero-copy `PostcardReader` over `UnsafeRawBufferPointer` with bounds checks.
  - Implemented bounded LEB128/VarInt decoding (u32: 5 bytes, u64: 10 bytes) and ZigZag signed integers (`VarInt.swift`).
  - Added strict discriminant validation for booleans (`0x00`/`0x01`) and Option tags (`0x00`/`0x01`), fixing upstream silent corruption bugs.
  - Implemented `PostcardWriter` for fast binary serialization.
  - Implemented full Swift `Codable` bridge (`PostcardDecoder` and `PostcardEncoder`) with keyed, unkeyed (staged sequence length), and single-value containers.
  - Verified exact Rust `postcard` crate wire byte compatibility and edge cases in `PostcardTests` (14 passing tests in 0.002s; 28 total project tests passing in release mode in 0.004s).

- [x] **Milestone 4: Host bridge & memory management (`Bridge/`)**
  - Implemented thread-safe `ResourceStore` (`Sources/MelloRunner/Bridge/ResourceStore.swift`) with `OSAllocatedUnfairLock` managing outbound host byte buffers (`[Int32: Data]`) passed to the guest.
  - Implemented core `std` imports (`Sources/MelloRunner/Bridge/StandardImports.swift`): `std.buffer_len`, `std.read_buffer`, `std.destroy`, `std.current_date`, `std.utc_offset`, `std.parse_date` (with full timezone/locale caching).
  - Implemented core `env` imports: `env.print`, `env.abort`, `env.sleep`, `env.send_partial_result`.
  - Implemented `ResultReader` (`Sources/MelloRunner/Bridge/ResultReader.swift`): robust extraction of framed `(length, payload)` from guest linear memory return pointers, negative error code mapping (`BridgeError`), `UInt32.max` error string decoding, and guaranteed `free_result(ptr)` deallocation.
  - Implemented actor-isolated `HostBridge` (`Sources/MelloRunner/Bridge/HostBridge.swift`) coordinating `ExecutionSession`, `ResourceStore`, `StandardImports`, and extensible `additionalImports`.
  - Comprehensive unit and integration test coverage: `ResourceStoreTests` (7 tests), `ResultReaderTests` (7 tests), `StandardImportsTests` (4 tests), and `HostBridgeTests` (3 tests), including real-world execution of the 96KB upstream extension binary (`payload.wasm`), bringing project test suite to 49 passing tests in 0.039s.

## Active & upcoming milestones

> [!IMPORTANT]
> **Mandatory Milestone Benchmarking Policy**:
> Upon completing any milestone, always run the performance benchmark harness against AidokuRunner, compare before-and-after speed numbers, verify zero performance regressions, and save the report in `Benchmarks/Results/milestone-<N>.md`.

- [x] **Milestone 5: Source models & wire schema (`Models/`, `Serialization/`)**
  - Implemented public domain models in Swift 6.4 with full `Sendable`, `Hashable`, `Identifiable`, and `Codable` conformance:
    - [`Manga.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Manga.swift): `Manga`, `PublishingStatus`, `ContentRating`, `Viewer`, `UpdateStrategy` with `sourceKey` excluded from wire encoding.
    - [`Chapter.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Chapter.swift): `Chapter` with Unix epoch seconds wire serialization, `Date?`, and `URL?` conversion.
    - [`Page.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Page.swift): `Page`, `PageContent` (`.url`, `.text`, `.imageDescriptor`, `.zipFile`), and `PageContext`.
    - [`Listing.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Listing.swift): `Listing`, `ListingKind` (`.default`, `.popular`, `.latest`, `.list`).
    - [`MangaPageResult.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/MangaPageResult.swift): `MangaPageResult` with `entries`, `hasNextPage`, and `setSourceKey` propagation.
    - [`Filter.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Filter.swift): `Filter`, `SelectFilter`, `MultiSelectFilter`, `SortDefault` matching exact Aidoku Postcard wire schema (`Option<bool>` wire tags).
    - [`FilterValue.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/FilterValue.swift): `FilterValue`, `SortFilterValue` matching query parameter serialization.
    - [`Setting.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Setting.swift): `Setting`, `SettingType`, and all 13 interactive setting controls (`GroupSetting`, `ToggleSetting`, `SelectSetting`, etc.).
  - Added [`ModelCodingTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Models/ModelCodingTests.swift) with 10 comprehensive test cases covering unit round-trips and real Wasm decoding (`get_listings`, `get_filters`, `get_settings`) against upstream `payload.wasm`.
  - All 59 tests in 8 suites pass in 0.043s with zero swift-format lint warnings.
  - Run head-to-head benchmark and record results in [`Benchmarks/Results/milestone-5.md`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Benchmarks/Results/milestone-5.md).

- [x] **Milestone 6: Host services integration (`Host/`)**
  - `Host/Network`: Protocol-driven HTTP transport (`HTTPTransport`) supporting [`URLSessionTransport.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Network/URLSessionTransport.swift) and deterministic [`MockHTTPTransport.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Network/MockHTTPTransport.swift); token-bucket pacing in [`RateLimiter.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Network/RateLimiter.swift); full WasmKit `net.*` imports in [`NetworkImports.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Network/NetworkImports.swift).
  - `Host/HTML`: Complete DOM parsing, querying, traversal, and mutation module via `SwiftSoup` in [`HTMLImports.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/HTML/HTMLImports.swift) (39 functions covering `parse`, `select`, `attr`, `text`, `children`, and kind identification).
  - `Host/Settings`: Thread-safe settings store protocol [`SettingsStore.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Settings/SettingsStore.swift) with [`InMemorySettingsStore.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Settings/InMemorySettingsStore.swift) (unfair lock) and [`UserDefaultsSettingsStore.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Settings/UserDefaultsSettingsStore.swift); Postcard-encoded `defaults.*` imports in [`DefaultsImports.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/Settings/DefaultsImports.swift).
  - `Host/JavaScript`: Isolated JavaScriptCore evaluation actor in [`IsolatedJSContext.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/JavaScript/IsolatedJSContext.swift); HTTP cookie model in [`Cookie.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Cookie.swift); `js.*` host imports in [`JavaScriptImports.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Host/JavaScript/JavaScriptImports.swift).
  - Unified [`HostBridge.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Bridge/HostBridge.swift) automatically registering all host modules into WasmKit with composable `register(into:store:)` hooks.
  - Comprehensive unit test suites (76 tests in 12 suites pass in 0.072s with zero swift-format warnings).
  - Executed head-to-head release benchmark with zero regressions and recorded results in [`Benchmarks/Results/milestone-6.md`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Benchmarks/Results/milestone-6.md).

- [x] **Milestone 7: Public source session API (`Package/`, `Session/`, `Models/`)**
  - Implemented [`SourceManifest.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/SourceManifest.swift), [`SourceFeatures.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/SourceFeatures.swift), [`Home.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/Home.swift), [`DeepLinkResult.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/DeepLinkResult.swift), [`KeyKind.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/KeyKind.swift), and [`MangaWithChapter.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/MangaWithChapter.swift).
  - Integrated Christopher's high-performance [`ZipMello`](https://github.com/ChrisRodStar/zipmello.git) engine (`ArchiveMemoryReader`) into [`AIXPackageReader.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Package/AIXPackageReader.swift) for safe, synchronous, CRC32-verified `.aix` archive decompression.
  - Implemented immutable [`SourcePackage.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Package/SourcePackage.swift) loading `.aix` archives, raw archive data, and directories with static filters and settings decoding.
  - Implemented high-level thread-safe coordinator [`SourceSession.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Session/SourceSession.swift) with automatic export capability discovery, static/dynamic listings/filters/settings merging, and search/chapter/update/page/auth operations.
  - Comprehensive unit test suites (87 tests across 15 suites pass in 0.152s with zero compiler warnings and zero swift-format warnings).
  - Executed head-to-head release benchmark against AidokuRunner, proving MelloRunner with ZipMello is **1.37x faster** on cold session initialization (565.49 µs vs 774.35 µs, even including live in-memory archive decompression!) and **1.11x faster** on high-level listings execution; recorded results in [`Benchmarks/Results/milestone-7.md`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Benchmarks/Results/milestone-7.md).

- [x] **Milestone 8: Upstream extension compatibility verification**
  - Fully verified against the reference upstream binary ([`main.wasm`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Reference/AidokuRunner/Tests/AidokuRunnerTests/Resources/Payload/main.wasm)) and production `.aix` extension ([`en.asurascans-v19.aix`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Reference/en.asurascans-v19.aix)).
  - Implemented exact Postcard wire format parity for complex enums (`HomeComponent.Value`, `HomeLinkValue`) and Rust `HashMap<String, String>` mapping for [`ImageResponse.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Sources/MelloRunner/Models/ImageResponse.swift).
  - Added streaming partial home feed updates via `env.send_partial_result` and `partialHomeHandler`.
  - Added image processing pipeline (`processPageImage`, `processCoverImage`) with fallback support.
  - Added fast runtime recovery via `SourceSession.restart()` re-initialization (148.11 µs / restart, **2.39x faster** than AidokuRunner).
  - Created [`UpstreamCompatibilityTests.swift`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Tests/MelloRunnerTests/Compatibility/UpstreamCompatibilityTests.swift) with 9 comprehensive test suites (all 96 tests in 16 test suites pass in 0.274s with zero warnings).
  - Executed head-to-head release benchmark: MelloRunner is **1.31x faster** on `getHome()` (324.66 µs vs 425.15 µs), **1.42x faster** on `getSearchMangaList()` (16.59 µs vs 23.52 µs), and **2.39x faster** on `restart()`; recorded results in [`Benchmarks/Results/milestone-8.md`](file:///Users/chris/Desktop/Workspace/IdeasTo/mellorunner/Benchmarks/Results/milestone-8.md).

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

- [ ] **Milestone 6: Host services integration (`Host/`)**
  - `Host/Network`: Injected HTTP transport contract (`URLRequest` execution, bounded concurrency, status/header validation).
  - `Host/HTML`: DOM parsing and querying backend for scraping HTML responses.
  - `Host/Settings`: Namespaced key-value storage contract for source configuration.
  - `Host/JavaScript` & `Host/Browser`: Isolated JavaScriptCore context evaluation and WebKit cookies.
  - Execute head-to-head benchmark and record results in `Benchmarks/Results/milestone-6.md`.

- [ ] **Milestone 7: Public source session API (`Sources/`)**
  - Package loader for `.wasm` binaries + `source.json` manifests.
  - High-level `SourceSession` coordinating initialization, search (`getSearchMangaList`), details (`getMangaUpdate`), chapters, and pages.
  - Capability discovery: inspecting optional exports (`get_home`, `get_filters`, `process_page_image`, etc.).
  - Execute head-to-head benchmark and record results in `Benchmarks/Results/milestone-7.md`.

- [ ] **Milestone 8: Upstream extension compatibility verification**
  - Load the reference upstream binary (`Reference/AidokuRunner/Tests/AidokuRunnerTests/Resources/Payload/main.wasm`).
  - Execute live test suite against deterministic network mocks.
  - End-to-end benchmarks comparing memory footprint and throughput against reference runner.
  - Execute head-to-head benchmark and record results in `Benchmarks/Results/milestone-8.md`.

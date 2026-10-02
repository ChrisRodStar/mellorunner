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

- [x] **Milestone 3: Postcard binary wire format (`Compatibility/Postcard/`)**
  - Implemented zero-copy `PostcardReader` over `UnsafeRawBufferPointer` with bounds checks.
  - Implemented bounded LEB128/VarInt decoding (u32: 5 bytes, u64: 10 bytes) and ZigZag signed integers (`VarInt.swift`).
  - Added strict discriminant validation for booleans (`0x00`/`0x01`) and Option tags (`0x00`/`0x01`), fixing upstream silent corruption bugs.
  - Implemented `PostcardWriter` for fast binary serialization.
  - Implemented full Swift `Codable` bridge (`PostcardDecoder` and `PostcardEncoder`) with keyed, unkeyed (staged sequence length), and single-value containers.
  - Verified exact Rust `postcard` crate wire byte compatibility and edge cases in `PostcardTests` (14 passing tests in 0.002s; 28 total project tests passing in release mode in 0.004s).

## Active & upcoming milestones

- [ ] **Milestone 4: API 0.7 host ABI & memory bridge (`Compatibility/API07/`)**
  - Implement type-safe `HostResourceStore` for tracking outbound host buffers (`[Int32: Data]`) passed to the guest.
  - Implement core `std` imports: `std.buffer_len`, `std.read_buffer`, `std.destroy`.
  - Implement core `env` imports: `env.print`, `env.abort`, `env.send_partial_result`.
  - Implement result framing: read `(length, payload)` from guest linear memory return pointers and invoke guest `free_result(ptr)`.
  - End-to-end integration test with a fixture verifying handle passing, buffer reading, and result framing.

- [ ] **Milestone 5: Source models & API 0.7 schema (`Sources/Models/`, `Compatibility/API07/Wire/`)**
  - Define public immutable models: `Manga`, `Chapter`, `Page`, `Filter`, `FilterValue`, `Listing`, `MangaPageResult`.
  - Implement wire conversion schemas mapping Postcard binary fields to public models.
  - Verify field ordering and option tags match the Aidoku API 0.7 wire specification.

- [ ] **Milestone 6: Host services integration (`Host/`)**
  - `Host/Network`: Injected HTTP transport contract (`URLRequest` execution, bounded concurrency, status/header validation).
  - `Host/HTML`: DOM parsing and querying backend for scraping HTML responses.
  - `Host/Settings`: Namespaced key-value storage contract for source configuration.
  - `Host/JavaScript` & `Host/Browser`: Isolated JavaScriptCore context evaluation and WebKit cookies.

- [ ] **Milestone 7: Public source session API (`Sources/`)**
  - Package loader for `.wasm` binaries + `source.json` manifests.
  - High-level `SourceSession` coordinating initialization, search (`getSearchMangaList`), details (`getMangaUpdate`), chapters, and pages.
  - Capability discovery: inspecting optional exports (`get_home`, `get_filters`, `process_page_image`, etc.).

- [ ] **Milestone 8: Upstream extension compatibility verification**
  - Load the reference upstream binary (`Reference/AidokuRunner/Tests/AidokuRunnerTests/Resources/Payload/main.wasm`).
  - Execute live test suite against deterministic network mocks.
  - End-to-end benchmarks comparing memory footprint and throughput against reference runner.

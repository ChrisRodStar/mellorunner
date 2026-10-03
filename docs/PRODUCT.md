# Product Scope

MelloRunner is an independent, pure-Swift WebAssembly execution runtime for manga source extensions on iOS and macOS.

## Responsibilities

MelloRunner provides:
- WebAssembly execution powered by WasmKit with strict memory safety and Swift 6 concurrency.
- Complete host import services across `std`, `env`, `defaults`, `net`, `html`, `canvas`, and `js`.
- Framing, memory bounds checking, and Postcard binary serialization.
- High-level `SourceSession` API managing extension lifecycles, configuration synthesis, package archives (`.aix`), and streaming updates.

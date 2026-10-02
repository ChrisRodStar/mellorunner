# 0001: Execution engine selection

- Status: Accepted
- Date: 2026-10-02
- Deciders: Christopher Rodriguez, Antigravity

## Context

MelloRunner executes WebAssembly-based manga source extensions on iOS 27 and macOS 27 using Swift 6.4. The runtime must run on physical iOS devices under App Store distribution rules, which disallow runtime code generation (JIT) without special entitlements (`get-task-allow` or debug entitlements).

Upstream AidokuRunner uses Wasm3, a C99 interpreter. While compact, Wasm3 requires C function pointers for host callbacks, unsafe pointer manipulation for guest memory, and synchronous return from all host functions. In AidokuRunner, integrating asynchronous host services (such as HTTP requests and WebKit JavaScript evaluation) led to blocking unstructured tasks with semaphores (`Utilities/BlockingTask.swift`), risking starvation of Swift's cooperative thread pool. Furthermore, upstream distribution restrictions prevent redistributing AidokuRunner or its derivatives.

## Decision

We adopt **WasmKit** (`https://github.com/swiftwasm/WasmKit.git`, version `0.4.1`) as the core WebAssembly execution engine for MelloRunner.

## Technical evaluation and rationale

1. **Platform compliance and safety**: WasmKit is written entirely in Swift and operates as an interpreter. It requires no writable and executable (`W^X`) memory pages and runs without special entitlements on iOS and macOS.
2. **Swift 6 concurrency model**: WasmKit types and execution interfaces integrate cleanly with Swift 6 strict concurrency, `@Sendable` closures, and typed errors. Host functions are registered as Swift closures, eliminating C bridging thunks, global pointer tables, and unchecked `Sendable` wrappers.
3. **Execution safety without thread starvation**: Asynchronous host operations can be coordinated within Swift structured concurrency rather than blocking POSIX threads or cooperative workers with semaphores.
4. **Performance characteristics**: Version 0.4.0 introduced major interpreter optimizations, doubling instruction execution throughput. In source extension workloads, execution time is dominated by network I/O, HTML/DOM queries, and binary serialization rather than dense numerical compute.
5. **Licensing and provenance**: WasmKit is developed by the SwiftWasm organization and bundled in official Swift toolchains since Swift 6.2. It is licensed under Apache 2.0 with LLVM Exceptions, permitting inclusion and distribution in MelloRunner.

## Architecture boundary

The WasmKit dependency remains an internal implementation detail of `Sources/MelloRunner/Runtime/Engine/`. WasmKit-specific types (`ExecutionEngine`, `Instance`, `Store`, `GuestMemory`) are never exposed across the public `MelloRunner` API boundary.

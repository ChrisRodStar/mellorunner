# Architecture

MelloRunner targets Swift 6.4, iOS 27, and macOS 27. Keep the library in one SwiftPM target initially, with a separate test target. Benchmarks and developer tools remain local and are excluded from Git, following ZipMello's repository convention. The benchmark package is separate from application dependencies.

The folders below organize responsibilities within the existing targets. They do not create module boundaries or imply that the planned features are implemented. Planned folders enter Git when they contain real files; no placeholder files are needed. Existing Swift files remain at their current paths until implementation work requires moving them.

## Layout

```text
Sources/
  MelloRunner/
    ModuleHeader.swift                 # existing implementation, unchanged
    Runtime/
      Engine/
      Execution/
    Sources/
      Models/
        Filters/
        Settings/
        Home/
    Bridge/
      Wire/
      Imports/
    Serialization/
      Postcard/
    Host/
      Network/
      Settings/
      HTML/
      JavaScript/
      Browser/
      Graphics/
      Time/
Tests/
  MelloRunnerTests/
    ModuleHeaderTests.swift            # existing tests, unchanged
    Runtime/
    Bridge/
    Serialization/
      Postcard/
    Host/
    Support/
    Fixtures/                         # existing independent answer.wasm
Benchmarks/                           # local only; ignored by Git
Tools/                                # local only; ignored by Git
docs/
  contracts/
    bridge/
  decisions/
assets/                               # approved branding
```

## Responsibilities

| Location | Owns | Boundary |
| --- | --- | --- |
| `Runtime/` | Module inspection, execution limits, runtime failures | Contains no manga/source schema or application policy. |
| `Runtime/Engine/` | Selected engine integration, guest memory, validated export handles, engine teardown | Engine-specific types stay internal. |
| `Runtime/Execution/` | Invocation scheduling, temporary-resource scopes, host resource handles | Access follows the engine's safety requirements; lifetimes are explicit. |
| `Sources/` | Package loading, immutable descriptors, source sessions, capabilities, source events/errors | Provides the source-facing API consumed by Melloku. |
| `Sources/Models/` | Public manga, chapter, page, search, filter, settings, and home values | Public property order must not define binary field order. UI binding and rendering stay in Melloku. |
| `Bridge/` | Host-guest communication bridge, argument dispatch, result framing and release | Connects guest Wasm runtime to host services and models. |
| `Bridge/Wire/` | Extension wire schemas and conversion to public values | Holds field order, tags, primitive widths, and optional representations. |
| `Bridge/Imports/` | Guest import adapters for each host namespace | Converts ABI arguments/results; delegates service work to `Host/`. |
| `Serialization/Postcard/` | Bounded binary primitives, varints, encoding/decoding errors | Depends on the wire-format specification, not source models or engine details. |
| `Host/Network/` | Transport contract, request/response values, bounded batch coordination | Melloku supplies network policy and transport configuration. |
| `Host/Settings/` | Namespaced storage contract and typed values | Melloku supplies persistence; no global UserDefaults or SwiftUI bindings in the contract. |
| `Host/HTML/` | DOM backend and HTML-resource ownership | DOM implementation types stay internal. |
| `Host/JavaScript/` | JavaScriptCore contexts and evaluation lifecycle | No JavaScriptCore object crosses the source-facing API. |
| `Host/Browser/` | Main-actor WebKit resources, navigation, script handlers, pending-operation cleanup | Melloku supplies browser data-store and cookie policy. |
| `Host/Graphics/` | Image, canvas, and font mechanisms | Wire schemas remain in compatibility; native UI image conversion belongs at the app boundary. |
| `Host/Time/` | Injectable wall-date access and monotonic elapsed waits | Date semantics and duration measurement are distinct. |
| `Tests/MelloRunnerTests/Support/` | Deterministic service doubles and resource-lifetime probes | Test-only support does not become a library dependency. |
| `docs/contracts/bridge/` | Import/export signatures, schemas, ownership, errors, and provenance | Written before the corresponding bridge implementation. |
| `docs/decisions/` | Engine selection and consequential architecture decisions | Records evidence, exact revisions, tradeoffs, and unresolved limitations. |

Keep related small types together when they serve one contract. Split files when ownership, dependencies, or review scope differ. Avoid general `Utilities/` and `Extensions/` folders that obscure which subsystem owns a helper.

## Dependency direction

The source session coordinates bridge operations. Bridge adapters use the runtime to invoke exports and access guest memory; import adapters use host services. Wire conversion produces public source values. The Postcard primitives do not depend on either the runtime or public models.

The runtime may accept engine-neutral host callbacks, but it must not name guest namespaces, import manga models, or depend on concrete network/browser/graphics implementations. Host implementations must not call the source session to reenter the same guest instance implicitly. Share explicit internal contract types where necessary rather than creating circular subsystem dependencies.

Melloku depends on the source-facing API and supplies its service configuration. Installation transactions, UI, credentials, and application storage policy remain in Melloku.

Use additional SwiftPM targets only when a concrete dependency, access-control, or optional-product requirement justifies them. Do not expose a public engine plug-in framework for the first execution slice.

## Ownership and concurrency

`ModuleHeader` is an immutable Sendable value. It accepts bounded bytes and reads the eight-byte WebAssembly header. It makes no claim that the remaining bytes form a valid module; the eventual execution engine must validate the complete module.

The planned runtime adapter will own its engine instance and linear-memory lifetime. Host services will be injected through explicit contracts. Avoid holding pointers across engine calls that may grow memory, and keep result ownership and release rules explicit.

The session owns source-level state and resources. Each invocation owns its temporary handles, partial-result registrations, and cleanup. Guest resources that must survive a call stay session-owned until their documented release point. The API contract must settle those lifetimes before implementation.

Use Sendable values at concurrency boundaries. Keep mutable engine state under one owner. Actor isolation alone does not prevent overlapping operations across suspension points; define an invocation gate if the engine requires exclusive calls. If synchronous guest imports require blocking, the execution design must keep that blocking outside Swift's cooperative executor. WebKit access remains on `MainActor`.

Select the execution engine after checking platform support, cancellation behavior, licenses, and representative workloads. Concurrency must respect the chosen engine's instance-safety requirements. No engine or actor model is selected by this scaffold.

## Build in slices

1. Select and document the engine. Implement only the runtime files needed to load `answer.wasm`, invoke `answer`, verify 42, and test teardown and initialization failures.
2. Specify bridge initialization, search, required imports, result framing, and resource ownership with provenance. Implement one deterministic search flow.
3. Add details, chapters, and pages, followed by the optional capabilities Melloku needs. Populate model and host folders as those contracts become supported.
4. Measure startup, guest execution, host dispatch, decoding, and teardown with reproducible fixtures. Keep service waiting separate from runtime work.

Legacy source format support remains a separate decision; there is no legacy compatibility folder. Directory organization establishes no performance improvement or compatibility guarantee.

The [reference review](REFERENCE_REVIEW.md) records all inspected upstream files and the reasoning behind these boundaries. It is not a completed source API specification or a clean-room claim.

# Next work

1. [x] Select an execution engine after checking Apple-platform support, licensing, memory limits, and interruption support (completed 2026-10-02; adopted WasmKit in `docs/decisions/0001-engine-selection.md`).
2. [x] Execute the generated `answer.wasm` fixture and verify 42, failures, and resource teardown (completed 2026-10-02; implemented in `Runtime/Engine` and `Runtime/Execution`, tested in `ExecutionSessionTests`).
3. Document the first source API 0.7 import/export and result-serialization contracts with provenance.
4. Implement bounded Postcard deserializer and one deterministic source search flow with injected host services, then add details, chapters, and pages.
5. Compare startup, host calls, decoding, and memory use before integrating into Melloku.


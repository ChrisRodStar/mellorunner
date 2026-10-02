import Foundation
import MelloRunner
import Testing

@Suite struct ExecutionSessionTests {
    private func loadAnswerFixture() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "answer", withExtension: "wasm", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    @Test func `Execute answer export and receive 42`() async throws {
        let data = try loadAnswerFixture()
        let session = try ExecutionSession(data: data)

        #expect(await session.hasExport("answer"))
        #expect(await !session.hasExport("missing"))

        let results = try await session.invoke("answer")
        #expect(results == [.i32(42)])

        let intResult = try await session.invokeInt32("answer")
        #expect(intResult == 42)
    }

    @Test func `Reject call to nonexistent export`() async throws {
        let data = try loadAnswerFixture()
        let session = try ExecutionSession(data: data)

        await #expect(throws: RuntimeError.exportNotFound("doesNotExist")) {
            try await session.invoke("doesNotExist")
        }
    }

    @Test func `Reject invalid and truncated modules`() async {
        #expect(throws: RuntimeError.self) {
            try ExecutionSession(data: Data([0, 97, 115, 109]))
        }

        #expect(throws: RuntimeError.self) {
            try ExecutionSession(data: Data(repeating: 0, count: 16))
        }

        // Valid header but invalid section bytes
        let malformedModule = Data([0, 97, 115, 109, 1, 0, 0, 0, 0xFF, 0xFF])
        #expect(throws: RuntimeError.self) {
            try ExecutionSession(data: malformedModule)
        }
    }

    @Test func `Enforce configured byte limit during session creation`() throws {
        let data = try loadAnswerFixture()
        #expect(throws: RuntimeError.self) {
            try ExecutionSession(data: data, maximumBytes: 10)
        }
    }

    @Test func `Trapping function raises RuntimeError trap`() async throws {
        // (module (func (export "boom") unreachable))
        let trapWasm = Data([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x04, 0x01, 0x60, 0x00, 0x00,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x08, 0x01, 0x04, 0x62, 0x6f, 0x6f, 0x6d, 0x00, 0x00,
            0x0a, 0x05, 0x01, 0x03, 0x00, 0x00, 0x0b,
        ])
        let session = try ExecutionSession(data: trapWasm)
        #expect(await session.hasExport("boom"))

        do {
            try await session.invoke("boom")
            Issue.record("Expected trap error was not thrown")
        } catch RuntimeError.trap(let message) {
            #expect(!message.isEmpty)
        } catch {
            Issue.record("Unexpected error thrown: \(error)")
        }
    }

    @Test func `Explicit session close releases resources and rejects further invocations`() async throws {
        let data = try loadAnswerFixture()
        let session = try ExecutionSession(data: data)

        #expect(await session.hasExport("answer"))
        await session.close()

        #expect(await !session.hasExport("answer"))

        await #expect(throws: RuntimeError.instanceClosed) {
            try await session.invoke("answer")
        }
    }

    @Test func `RuntimeValue representations and conversions`() {
        let i32 = RuntimeValue.i32(42)
        let i64 = RuntimeValue.i64(100)
        let f32 = RuntimeValue.f32(3.14)
        let f64 = RuntimeValue.f64(2.71828)

        #expect(i32.i32Value == 42)
        #expect(i32.i64Value == nil)
        #expect(i64.i64Value == 100)
        #expect(f32.f32Value == 3.14)
        #expect(f64.f64Value == 2.71828)
        #expect(i32.description == "i32(42)")
    }

    @Test func `Guest memory reading and zero-copy access`() async throws {
        // Module with exported memory and "hello" data segment at offset 0
        let memoryWasm = Data([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x05, 0x03, 0x01, 0x00, 0x01,
            0x07, 0x0a, 0x01, 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02, 0x00,
            0x0b, 0x0b, 0x01, 0x00, 0x41, 0x00, 0x0b, 0x05, 0x68, 0x65, 0x6c, 0x6c, 0x6f,
        ])
        let session = try ExecutionSession(data: memoryWasm)
        #expect(await session.hasExport("memory"))

        let data = try await session.readMemory(offset: 0, count: 5)
        #expect(String(decoding: data, as: UTF8.self) == "hello")

        let str = try await session.withMemory(offset: 0, count: 5) { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
        #expect(str == "hello")

        // Out of bounds check
        await #expect(throws: RuntimeError.self) {
            _ = try await session.readMemory(offset: 65536, count: 1)
        }
    }

    @Test func `Read memory on module without memory export throws exportNotFound`() async throws {
        let data = try loadAnswerFixture()
        let session = try ExecutionSession(data: data)

        await #expect(throws: RuntimeError.exportNotFound("memory")) {
            _ = try await session.readMemory(offset: 0, count: 4)
        }
    }
}

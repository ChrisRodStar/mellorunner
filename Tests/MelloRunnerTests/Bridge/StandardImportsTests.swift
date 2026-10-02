import Foundation
import os
import Testing
@testable import MelloRunner
import WasmKit

@Suite("StandardImports Tests")
struct StandardImportsTests {

    @Test("Direct date and time standard operations")
    func dateTimeOperations() {
        let imports = StandardImports()

        let now = Date.now.timeIntervalSince1970
        let guestNow = imports.currentDate()
        #expect(abs(guestNow - now) < 5.0)

        let expectedOffset = -Int64(TimeZone.current.secondsFromGMT())
        #expect(imports.utcOffset() == expectedOffset)
    }

    @Test("Date parsing with various formats, time zones, and error cases")
    func parseDateOperations() {
        let imports = StandardImports()

        // 1. UTC timestamp check: 2026-01-01 00:00:00 UTC = 1767225600
        let epoch = imports.parseDate(
            string: "2026-01-01 00:00:00",
            format: "yyyy-MM-dd HH:mm:ss",
            localeIdentifier: "en_US_POSIX",
            timeZoneIdentifier: "UTC"
        )
        #expect(epoch == 1767225600.0)

        // 2. Defaulting to UTC when timeZoneIdentifier is nil/empty
        let defaultEpoch = imports.parseDate(
            string: "2026-01-01 00:00:00",
            format: "yyyy-MM-dd HH:mm:ss"
        )
        #expect(defaultEpoch == 1767225600.0)

        // 3. "current" locale and time zone
        let currentEpoch = imports.parseDate(
            string: "2026-01-01 00:00:00",
            format: "yyyy-MM-dd HH:mm:ss",
            localeIdentifier: "current",
            timeZoneIdentifier: "current"
        )
        #expect(currentEpoch > 0)

        // 4. Invalid date string returns -5.0
        let invalidDate = imports.parseDate(
            string: "not-a-date",
            format: "yyyy-MM-dd"
        )
        #expect(invalidDate == -5.0)
    }

    @Test("Resource lifecycle operations: store, bufferLength, destroy")
    func resourceOperations() {
        let store = ResourceStore()
        let imports = StandardImports(resourceStore: store)

        let descriptor = store.store(Data([10, 20, 30, 40, 50]))
        #expect(imports.bufferLength(descriptor: descriptor) == 5)
        #expect(imports.bufferLength(descriptor: 999) == -1)

        imports.destroy(descriptor: descriptor)
        #expect(imports.bufferLength(descriptor: descriptor) == -1)
        #expect(store.count == 0)
    }

    @Test("Instantiation and execution of payload.wasm with standard and env imports")
    func payloadInstantiation() async throws {
        let url = try #require(
            Bundle.module.url(forResource: "payload", withExtension: "wasm", subdirectory: "Fixtures")
        )
        let data = try Data(contentsOf: url)

        let printedMessages = OSAllocatedUnfairLock(initialState: [String]())
        let store = ResourceStore()
        let stdImports = StandardImports(
            resourceStore: store,
            printHandler: { msg in
                printedMessages.withLock { $0.append(msg) }
            }
        )

        let engine = RuntimeEngine.shared
        let session = try ExecutionSession(
            data: data,
            engine: engine,
            makeImports: { store in
                var imports = stdImports.makeImports(store: store)
                imports.define(
                    module: "defaults",
                    name: "get",
                    Function(
                        store: store,
                        type: FunctionType(parameters: [.i32, .i32], results: [.i32])
                    ) { _, _ in
                        [.i32(UInt32(bitPattern: -1))]
                    }
                )
                return imports
            }
        )

        let module = try parseWasm(bytes: [UInt8](data))

        // Verify exports
        #expect(await session.hasExport("memory"))
        #expect(await session.hasExport("free_result"))
        #expect(await session.hasExport("start"))

        // Invoke start export
        let startResult = try await session.invoke("start")
        #expect(startResult.isEmpty)
    }
}

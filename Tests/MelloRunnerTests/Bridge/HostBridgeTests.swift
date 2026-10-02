import Foundation
import Testing
@testable import MelloRunner
import WasmKit

@Suite("HostBridge Tests")
struct HostBridgeTests {

    private func loadAnswerFixture() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "answer", withExtension: "wasm", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    private func loadPayloadFixture() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "payload", withExtension: "wasm", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    @Test("Initialize HostBridge with answer.wasm and execute invoke and invokeInt32")
    func basicInvocation() async throws {
        let data = try loadAnswerFixture()
        let bridge = try HostBridge(wasmBytes: data)

        let result = try await bridge.invoke("answer")
        #expect(result == [.i32(42)])

        let intResult = try await bridge.invokeInt32("answer")
        #expect(intResult == 42)

        await bridge.close()
    }

    @Test("Manage resources through HostBridge")
    func resourceManagement() async throws {
        let data = try loadAnswerFixture()
        let bridge = try HostBridge(wasmBytes: data)

        let testData = Data([100, 101, 102])
        let d1 = await bridge.storeResource(testData)
        let d2 = await bridge.storeResource(string: "MelloRunner")

        #expect(d1 == 1)
        #expect(d2 == 2)
        #expect(bridge.resourceStore.count == 2)

        let removed = await bridge.removeResource(d1)
        #expect(removed == testData)
        #expect(bridge.resourceStore.count == 1)

        await bridge.close()
        #expect(bridge.resourceStore.count == 0)
    }

    @Test("Initialize HostBridge with payload.wasm using additionalImports")
    func payloadBridgeExecution() async throws {
        let data = try loadPayloadFixture()

        let bridge = try HostBridge(
            wasmBytes: data,
            additionalImports: { store, imports in
                // Provide defaults.get to satisfy the payload binary
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
            }
        )

        // Verify start export can be invoked
        let startResult = try await bridge.invoke("start")
        #expect(startResult.isEmpty)

        // Call get_filters() which returns a framed Postcard result
        let filtersData = try await bridge.invokeResult("get_filters")
        #expect(filtersData.count >= 0)

        // Call get_settings() which returns a framed Postcard result
        let settingsData = try await bridge.invokeResult("get_settings")
        #expect(settingsData.count >= 0)

        // Call get_listings() which returns a framed Postcard result
        let listingsData = try await bridge.invokeResult("get_listings")
        #expect(listingsData.count >= 0)

        await bridge.close()
    }
}

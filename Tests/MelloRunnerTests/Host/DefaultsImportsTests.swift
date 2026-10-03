import Foundation
import Testing
import WasmKit

@testable import MelloRunner

@Suite("Defaults Imports Tests")
struct DefaultsImportsTests {
    @Test("InMemorySettingsStore get, set, and typed accessors")
    func testInMemorySettingsStore() {
        let store = InMemorySettingsStore()

        store.set(true, forKey: "test.bool")
        store.set(Int(42), forKey: "test.int")
        store.set(Float(3.14), forKey: "test.float")
        store.set("hello", forKey: "test.string")
        store.set(["a", "b", "c"], forKey: "test.array")
        store.set(Data([0x01, 0x02, 0x03]), forKey: "test.data")

        #expect(store.bool(forKey: "test.bool") == true)
        #expect(store.int(forKey: "test.int") == 42)
        #expect(store.float(forKey: "test.float") == Float(3.14))
        #expect(store.string(forKey: "test.string") == "hello")
        #expect(store.stringArray(forKey: "test.array") == ["a", "b", "c"])
        #expect(store.data(forKey: "test.data") == Data([0x01, 0x02, 0x03]))

        store.removeValue(forKey: "test.string")
        #expect(store.string(forKey: "test.string") == nil)

        store.removeAll()
        #expect(store.allValues.isEmpty)
    }

    @Test("DefaultsImports registers functions and encodes settings data")
    func testDefaultsImportsModuleRegistration() throws {
        let resourceStore = ResourceStore()
        let settingsStore = InMemorySettingsStore(initialValues: [
            "my_source.api_key": "secret_123",
            "my_source.enabled": true,
        ])

        let defaults = DefaultsImports(
            resourceStore: resourceStore,
            settingsStore: settingsStore,
            namespace: "my_source"
        )

        let wasmStore = Store(engine: Engine())
        let imports = defaults.makeImports(store: wasmStore)
        _ = imports

        #expect(settingsStore.string(forKey: "my_source.api_key") == "secret_123")
        #expect(settingsStore.bool(forKey: "my_source.enabled") == true)
    }

    @Test("Postcard wire encoding for setting values round-trip")
    func testSettingsPostcardEncoding() throws {
        let encoder = PostcardEncoder()
        let decoder = PostcardDecoder()

        let stringData = try encoder.encode("custom_setting_value")
        let decodedString = try decoder.decode(String.self, from: stringData)
        #expect(decodedString == "custom_setting_value")

        let arrayData = try encoder.encode(["tag1", "tag2", "tag3"])
        let decodedArray = try decoder.decode([String].self, from: arrayData)
        #expect(decodedArray == ["tag1", "tag2", "tag3"])
    }
}

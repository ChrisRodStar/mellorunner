import Foundation
import Testing
@testable import MelloRunner
import WasmKit

@Suite("ResultReader Tests")
struct ResultReaderTests {

    private func createTestMemory() throws -> Memory {
        let memoryWasm = Data([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x05, 0x03, 0x01, 0x00, 0x01,
            0x07, 0x0a, 0x01, 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02, 0x00
        ])
        let module = try parseWasm(bytes: [UInt8](memoryWasm))
        let engine = Engine()
        let store = Store(engine: engine)
        let instance = try module.instantiate(store: store)
        guard case .memory(let memory) = instance.export("memory") else {
            throw RuntimeError.exportNotFound("memory")
        }
        return memory
    }

    @Test("Negative error codes map to BridgeError enum cases")
    func negativeErrorCodes() throws {
        let memory = try createTestMemory()

        #expect(throws: BridgeError.unimplemented) {
            try ResultReader.readResultData(result: -2, memory: memory)
        }
        #expect(throws: BridgeError.networkError) {
            try ResultReader.readResultData(result: -3, memory: memory)
        }
        #expect(throws: BridgeError.htmlError) {
            try ResultReader.readResultData(result: -4, memory: memory)
        }
        #expect(throws: BridgeError.jsError) {
            try ResultReader.readResultData(result: -5, memory: memory)
        }
        #expect(throws: BridgeError.canvasError) {
            try ResultReader.readResultData(result: -6, memory: memory)
        }
        #expect(throws: BridgeError.utf8Error) {
            try ResultReader.readResultData(result: -7, memory: memory)
        }
        #expect(throws: BridgeError.jsonParseError) {
            try ResultReader.readResultData(result: -8, memory: memory)
        }
        #expect(throws: BridgeError.deserializeError) {
            try ResultReader.readResultData(result: -9, memory: memory)
        }
        #expect(throws: BridgeError.unknownGuestErrorCode(-42)) {
            try ResultReader.readResultData(result: -42, memory: memory)
        }
    }

    @Test("Out of bounds pointer throws invalidResultPointer")
    func outOfBoundsPointer() throws {
        let memory = try createTestMemory()
        let outOfBoundsPtr = Int32(memory.byteCount + 10)

        #expect(throws: BridgeError.invalidResultPointer(outOfBoundsPtr)) {
            try ResultReader.readResultData(result: outOfBoundsPtr, memory: memory)
        }
    }

    @Test("Header length smaller than 8 bytes throws corruptedResultHeader")
    func headerLengthTooSmall() throws {
        let memory = try createTestMemory()
        let ptr: UInt = 64

        // Write totalLength = 4 (less than 8)
        memory.withUnsafeMutableBufferPointer(offset: ptr, count: 4) { buffer in
            buffer.storeBytes(of: UInt32(4).littleEndian, as: UInt32.self)
        }

        #expect(throws: BridgeError.corruptedResultHeader("Allocated length 4 is smaller than 8-byte header")) {
            try ResultReader.readResultData(result: Int32(ptr), memory: memory)
        }
    }

    @Test("Payload length exceeding memory bounds throws corruptedResultHeader")
    func payloadExceedsMemory() throws {
        let memory = try createTestMemory()
        let ptr: UInt = UInt(memory.byteCount - 16)

        // Write totalLength = 1000 (exceeds remaining 16 bytes)
        memory.withUnsafeMutableBufferPointer(offset: ptr, count: 4) { buffer in
            buffer.storeBytes(of: UInt32(1000).littleEndian, as: UInt32.self)
        }

        #expect(throws: BridgeError.self) {
            try ResultReader.readResultData(result: Int32(ptr), memory: memory)
        }
    }

    @Test("Guest error message string with UInt32.max header triggers freeResult and throws guestError")
    func guestErrorMessage() throws {
        let memory = try createTestMemory()
        let ptr: UInt = 128
        let errorMessage = "Rate limited by upstream host"
        let errorBytes = [UInt8](errorMessage.utf8)
        let stringTotalLength = UInt32(12 + errorBytes.count)

        // Write totalLength = UInt32.max at ptr
        memory.withUnsafeMutableBufferPointer(offset: ptr, count: 4) { buffer in
            buffer.storeBytes(of: UInt32.max.littleEndian, as: UInt32.self)
        }
        // Write stringTotalLength at ptr + 8
        memory.withUnsafeMutableBufferPointer(offset: ptr + 8, count: 4) { buffer in
            buffer.storeBytes(of: stringTotalLength.littleEndian, as: UInt32.self)
        }
        // Write UTF-8 string at ptr + 12
        errorBytes.withUnsafeBytes { raw in
            memory.withUnsafeMutableBufferPointer(offset: ptr + 12, count: errorBytes.count) { buffer in
                buffer.baseAddress?.copyMemory(from: raw.baseAddress!, byteCount: errorBytes.count)
            }
        }

        var freedPointer: Int32?
        let freeClosure: (Int32) -> Void = { pointer in
            freedPointer = pointer
        }

        #expect(throws: BridgeError.guestError(errorMessage)) {
            try ResultReader.readResultData(result: Int32(ptr), memory: memory, freeResult: freeClosure)
        }

        #expect(freedPointer == Int32(ptr))
    }

    @Test("Valid result pointer extracts payload data and invokes freeResult")
    func extractPayloadSuccessfully() throws {
        let memory = try createTestMemory()
        let ptr: UInt = 256
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03])
        let totalLength = UInt32(8 + payload.count)

        // Write totalLength at ptr
        memory.withUnsafeMutableBufferPointer(offset: ptr, count: 4) { buffer in
            buffer.storeBytes(of: totalLength.littleEndian, as: UInt32.self)
        }
        // Zero out reserved 4 bytes at ptr + 4
        memory.withUnsafeMutableBufferPointer(offset: ptr + 4, count: 4) { buffer in
            buffer.storeBytes(of: UInt32(0), as: UInt32.self)
        }
        // Write payload at ptr + 8
        payload.withUnsafeBytes { raw in
            memory.withUnsafeMutableBufferPointer(offset: ptr + 8, count: payload.count) { dest in
                dest.baseAddress?.copyMemory(from: raw.baseAddress!, byteCount: payload.count)
            }
        }

        var freedPointer: Int32?
        let extracted = try ResultReader.readResultData(
            result: Int32(ptr),
            memory: memory,
            freeResult: { freedPointer = $0 }
        )

        #expect(extracted == payload)
        #expect(freedPointer == Int32(ptr))
    }

    struct TestModel: Codable, Equatable {
        let id: String
        let score: Int32
        let tags: [String]
    }

    @Test("decodeResult deserializes Postcard payload from guest memory")
    func decodeResultModel() throws {
        let memory = try createTestMemory()
        let ptr: UInt = 512

        let original = TestModel(id: "mello-test", score: 99, tags: ["swift", "wasm", "postcard"])
        let encoder = PostcardEncoder()
        let encodedBytes = try encoder.encode(original)
        let totalLength = UInt32(8 + encodedBytes.count)

        // Write totalLength at ptr
        memory.withUnsafeMutableBufferPointer(offset: ptr, count: 4) { buffer in
            buffer.storeBytes(of: totalLength.littleEndian, as: UInt32.self)
        }
        // Write payload at ptr + 8
        encodedBytes.withUnsafeBytes { raw in
            memory.withUnsafeMutableBufferPointer(offset: ptr + 8, count: encodedBytes.count) { dest in
                dest.baseAddress?.copyMemory(from: raw.baseAddress!, byteCount: encodedBytes.count)
            }
        }

        var freedPointer: Int32?
        let decoded: TestModel = try ResultReader.decodeResult(
            TestModel.self,
            result: Int32(ptr),
            memory: memory,
            freeResult: { freedPointer = $0 }
        )

        #expect(decoded == original)
        #expect(freedPointer == Int32(ptr))
    }
}

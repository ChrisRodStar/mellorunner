import Foundation
import Testing
import MelloRunner

@Suite struct ModuleHeaderTests {
    private let header = Data([0, 97, 115, 109, 1, 0, 0, 0])

    @Test func `Inspect an independently generated module`() throws {
        let url = try #require(Bundle.module.url(forResource: "answer", withExtension: "wasm", subdirectory: "Fixtures"))
        let bytes = try Data(contentsOf: url)
        let result = try ModuleHeader(data: bytes)
        #expect(result.binaryVersion == 1)
        #expect(result.byteCount == bytes.count)
    }

    @Test(arguments: 0..<8)
    func `Reject truncated headers`(length: Int) {
        #expect(throws: ModuleInspectionError.truncatedHeader) {
            try ModuleHeader(data: Data(header.prefix(length)))
        }
    }

    @Test func `Reject invalid magic and unsupported versions`() {
        #expect(throws: ModuleInspectionError.invalidMagic) {
            try ModuleHeader(data: Data(repeating: 0, count: 8))
        }
        #expect(throws: ModuleInspectionError.unsupportedVersion(256)) {
            try ModuleHeader(data: Data([0, 97, 115, 109, 0, 1, 0, 0]))
        }
    }

    @Test func `Enforce configured byte limits`() throws {
        #expect(throws: ModuleInspectionError.invalidByteLimit) {
            try ModuleHeader(data: header, maximumBytes: 7)
        }
        #expect(throws: ModuleInspectionError.moduleTooLarge) {
            try ModuleHeader(data: header + Data([0]), maximumBytes: 8)
        }
        #expect(try ModuleHeader(data: header, maximumBytes: 8).byteCount == 8)
    }

    @Test func `Accept Data with a nonzero start index`() throws {
        let slice = (Data([255]) + header).dropFirst()
        #expect(try ModuleHeader(data: slice).binaryVersion == 1)
    }
}

import Foundation
import MelloRunner
import Testing

@Suite("ResourceStore Tests")
struct ResourceStoreTests {
    @Test("Store and fetch Data returns expected content and descriptors")
    func storeAndFetchData() {
        let store = ResourceStore()
        let data1 = Data([0x01, 0x02, 0x03, 0x04])
        let data2 = Data([0xAA, 0xBB, 0xCC])

        let d1 = store.store(data1)
        let d2 = store.store(data2)

        #expect(d1 == 1)
        #expect(d2 == 2)
        #expect(store.count == 2)

        #expect(store.fetch(d1) == data1)
        #expect(store.fetch(d2) == data2)
        #expect(store.fetch(999) == nil)
    }

    @Test("Store String properly encodes UTF-8 bytes")
    func storeString() {
        let store = ResourceStore()
        let text = "Hello, MelloRunner! 🚀"
        let d = store.store(string: text)

        let fetched = store.fetch(d)
        #expect(fetched != nil)
        #expect(fetched == Data(text.utf8))
        #expect(store.length(of: d) == Int32(Data(text.utf8).count))
    }

    @Test("Length of valid and invalid descriptors")
    func lengthOfDescriptors() {
        let store = ResourceStore()
        let data = Data(repeating: 0x42, count: 128)
        let d = store.store(data)

        #expect(store.length(of: d) == 128)
        #expect(store.length(of: -1) == -1)
        #expect(store.length(of: 100) == -1)
    }

    @Test("copyBytes into destination buffer with strict bounds checking")
    func copyBytesBounds() {
        let store = ResourceStore()
        let sample = Data([10, 20, 30, 40, 50])
        let descriptor = store.store(sample)

        var destination = [UInt8](repeating: 0, count: 5)
        let status = destination.withUnsafeMutableBytes { buffer in
            store.copyBytes(from: descriptor, to: buffer, count: 5)
        }
        #expect(status == 0)
        #expect(destination == [10, 20, 30, 40, 50])

        // Partial copy
        var partial = [UInt8](repeating: 0, count: 3)
        let partialStatus = partial.withUnsafeMutableBytes { buffer in
            store.copyBytes(from: descriptor, to: buffer, count: 3)
        }
        #expect(partialStatus == 0)
        #expect(partial == [10, 20, 30])

        // Buffer size exceeds stored data count -> returns -2
        var overBuffer = [UInt8](repeating: 0, count: 10)
        let overStatus = overBuffer.withUnsafeMutableBytes { buffer in
            store.copyBytes(from: descriptor, to: buffer, count: 6)
        }
        #expect(overStatus == -2)

        // Invalid descriptor -> returns -1
        let invalidStatus = partial.withUnsafeMutableBytes { buffer in
            store.copyBytes(from: 999, to: buffer, count: 3)
        }
        #expect(invalidStatus == -1)
    }

    @Test("Remove descriptor releases resource")
    func removeResource() {
        let store = ResourceStore()
        let d = store.store(Data([1, 2, 3]))
        #expect(store.count == 1)

        let removed = store.remove(d)
        #expect(removed == Data([1, 2, 3]))
        #expect(store.count == 0)
        #expect(store.fetch(d) == nil)
        #expect(store.length(of: d) == -1)
        #expect(store.remove(d) == nil)
    }

    @Test("removeAll clears all resources and resets descriptor index")
    func removeAll() {
        let store = ResourceStore()
        _ = store.store(Data([1]))
        _ = store.store(Data([2]))
        _ = store.store(Data([3]))
        #expect(store.count == 3)

        store.removeAll()
        #expect(store.count == 0)

        // Reset nextDescriptor to 1
        let newD = store.store(Data([4]))
        #expect(newD == 1)
    }

    @Test("Concurrent access from multiple concurrent tasks is thread-safe")
    func concurrentAccessStress() async {
        let store = ResourceStore()
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let data = Data(repeating: UInt8(i % 256), count: 64)
                    let d = store.store(data)
                    #expect(store.length(of: d) == 64)
                    #expect(store.fetch(d) == data)
                    _ = store.remove(d)
                }
            }
        }

        #expect(store.count == 0)
    }
}

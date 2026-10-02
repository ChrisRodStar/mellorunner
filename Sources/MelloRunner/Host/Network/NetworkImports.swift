import Foundation
import SwiftSoup
import WasmKit

/// Provides `net` host functions imported by WebAssembly source extensions to execute HTTP requests.
public final class NetworkImports: @unchecked Sendable {
    public enum NetResult: Int32 {
        case success = 0
        case invalidDescriptor = -1
        case invalidString = -2
        case invalidMethod = -3
        case invalidUrl = -4
        case invalidHtml = -5
        case invalidBufferSize = -6
        case missingData = -7
        case missingResponse = -8
        case missingUrl = -9
        case requestError = -10
        case failedMemoryWrite = -11
        case notAnImage = -12
    }

    public let resourceStore: ResourceStore
    public let transport: any HTTPTransport
    public let rateLimiter: RateLimiter

    public init(
        resourceStore: ResourceStore,
        transport: any HTTPTransport = URLSessionTransport(),
        rateLimiter: RateLimiter = RateLimiter()
    ) {
        self.resourceStore = resourceStore
        self.transport = transport
        self.rateLimiter = rateLimiter
    }

    /// Registers the `net` module functions into the given WasmKit `Imports`.
    public func register(into imports: inout Imports, store: Store) {
        // 1. net.init(method: i32) -> i32
        imports.define(
            module: "net",
            name: "init",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let methodRaw = Int(Int32(bitPattern: args[0].i32))
                guard let method = NetRequest.Method(rawValue: methodRaw) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidMethod.rawValue))]
                }
                let request = NetRequest(method: method)
                let descriptor = self.resourceStore.storeObject(request)
                return [.i32(UInt32(bitPattern: descriptor))]
            }
        )

        // 2. net.set_url(descriptor: i32, value: i32, length: i32) -> i32
        imports.define(
            module: "net",
            name: "set_url",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let valueOffset = Int(Int32(bitPattern: args[1].i32))
                let length = Int(Int32(bitPattern: args[2].i32))

                guard var request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard valueOffset >= 0, length > 0 else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                guard let memory = caller.instance?.exports[memory: "memory"] else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard UInt(valueOffset) + UInt(length) <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                let urlString: String? = memory.withUnsafeBufferPointer(offset: UInt(valueOffset), count: length) {
                    buf in
                    String(bytes: buf, encoding: .utf8)
                }

                guard let urlString, let url = URL(string: urlString) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidUrl.rawValue))]
                }

                request.url = url
                self.resourceStore.setObject(descriptor, request)
                return [.i32(UInt32(bitPattern: NetResult.success.rawValue))]
            }
        )

        // 3. net.set_header(descriptor: i32, key: i32, keyLength: i32, value: i32, valueLength: i32) -> i32
        imports.define(
            module: "net",
            name: "set_header",
            Function(
                store: store,
                type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32], results: [.i32])
            ) { [weak self] caller, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let keyOffset = Int(Int32(bitPattern: args[1].i32))
                let keyLength = Int(Int32(bitPattern: args[2].i32))
                let valOffset = Int(Int32(bitPattern: args[3].i32))
                let valLength = Int(Int32(bitPattern: args[4].i32))

                guard var request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard keyOffset >= 0, keyLength > 0, valOffset >= 0, valLength > 0 else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                guard let memory = caller.instance?.exports[memory: "memory"] else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard UInt(keyOffset) + UInt(keyLength) <= memory.byteCount,
                    UInt(valOffset) + UInt(valLength) <= memory.byteCount
                else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                let keyString: String? = memory.withUnsafeBufferPointer(offset: UInt(keyOffset), count: keyLength) {
                    buf in
                    String(bytes: buf, encoding: .utf8)
                }
                let valString: String? = memory.withUnsafeBufferPointer(offset: UInt(valOffset), count: valLength) {
                    buf in
                    String(bytes: buf, encoding: .utf8)
                }

                guard let keyString, let valString else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                request.headers[keyString] = valString
                self.resourceStore.setObject(descriptor, request)
                return [.i32(UInt32(bitPattern: NetResult.success.rawValue))]
            }
        )

        // 4. net.set_body(descriptor: i32, value: i32, length: i32) -> i32
        imports.define(
            module: "net",
            name: "set_body",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let bodyOffset = Int(Int32(bitPattern: args[1].i32))
                let length = Int(Int32(bitPattern: args[2].i32))

                guard var request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard bodyOffset >= 0, length >= 0 else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                guard let memory = caller.instance?.exports[memory: "memory"] else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard UInt(bodyOffset) + UInt(length) <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                let bodyData: Data? = memory.withUnsafeBufferPointer(offset: UInt(bodyOffset), count: length) { buf in
                    Data(buf)
                }

                request.body = bodyData
                self.resourceStore.setObject(descriptor, request)
                return [.i32(UInt32(bitPattern: NetResult.success.rawValue))]
            }
        )

        // 5. net.set_timeout(descriptor: i32, timeout: i32) -> i32
        imports.define(
            module: "net",
            name: "set_timeout",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let timeoutSeconds = Double(Int32(bitPattern: args[1].i32))

                guard var request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                request.timeoutInterval = max(1.0, timeoutSeconds)
                self.resourceStore.setObject(descriptor, request)
                return [.i32(UInt32(bitPattern: NetResult.success.rawValue))]
            }
        )

        // 6. net.set_rate_limit(requests: i32, period: i32) -> i32
        imports.define(
            module: "net",
            name: "set_rate_limit",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let requests = Int(Int32(bitPattern: args[0].i32))
                let period = Double(Int32(bitPattern: args[1].i32))

                Task {
                    await self.rateLimiter.setRateLimit(requests: requests, period: period)
                }
                return [.i32(UInt32(bitPattern: NetResult.success.rawValue))]
            }
        )

        // 7. net.send(descriptor: i32) -> i32
        imports.define(
            module: "net",
            name: "send",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)

                guard var request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let urlRequest = request.toURLRequest() else {
                    return [.i32(UInt32(bitPattern: NetResult.missingUrl.rawValue))]
                }

                let transport = self.transport
                let rateLimiter = self.rateLimiter

                let semaphore = DispatchSemaphore(value: 0)
                let resultBox = SingleRequestResult()

                Task.detached {
                    await rateLimiter.acquire()
                    do {
                        let (data, response) = try await transport.send(request: urlRequest)
                        resultBox.data = data
                        resultBox.response = response
                    } catch {
                        resultBox.error = error
                    }
                    semaphore.signal()
                }
                semaphore.wait()

                request.responseData = resultBox.data
                request.response = resultBox.response
                request.responseError = resultBox.error
                self.resourceStore.setObject(descriptor, request)

                if resultBox.error != nil {
                    return [.i32(UInt32(bitPattern: NetResult.requestError.rawValue))]
                }
                return [.i32(UInt32(bitPattern: NetResult.success.rawValue))]
            }
        )

        // 8. net.data_len(descriptor: i32) -> i32
        imports.define(
            module: "net",
            name: "data_len",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let data = request.responseData else {
                    return [.i32(UInt32(bitPattern: NetResult.missingData.rawValue))]
                }
                return [.i32(UInt32(bitPattern: Int32(truncatingIfNeeded: data.count)))]
            }
        )

        // 9. net.read_data(descriptor: i32, buffer: i32, size: i32) -> i32
        imports.define(
            module: "net",
            name: "read_data",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let bufferOffset = Int(Int32(bitPattern: args[1].i32))
                let size = Int(Int32(bitPattern: args[2].i32))

                guard let request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let data = request.responseData else {
                    return [.i32(UInt32(bitPattern: NetResult.missingData.rawValue))]
                }
                guard bufferOffset >= 0, size >= 0, size <= data.count else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidBufferSize.rawValue))]
                }

                guard let memory = caller.instance?.exports[memory: "memory"] else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard UInt(bufferOffset) + UInt(size) <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: NetResult.failedMemoryWrite.rawValue))]
                }

                _ = memory.withUnsafeMutableBufferPointer(offset: UInt(bufferOffset), count: size) { dest in
                    data.copyBytes(to: dest)
                }

                return [.i32(UInt32(bitPattern: NetResult.success.rawValue))]
            }
        )

        // 10. net.get_status_code(descriptor: i32) -> i32
        imports.define(
            module: "net",
            name: "get_status_code",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let response = request.response else {
                    return [.i32(UInt32(bitPattern: NetResult.missingResponse.rawValue))]
                }
                return [.i32(UInt32(bitPattern: Int32(response.statusCode)))]
            }
        )

        // 11. net.get_url(descriptor: i32) -> i32
        imports.define(
            module: "net",
            name: "get_url",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let url = request.response?.url?.absoluteString ?? request.url?.absoluteString else {
                    return [.i32(UInt32(bitPattern: NetResult.missingUrl.rawValue))]
                }
                let strDescriptor = self.resourceStore.store(string: url)
                return [.i32(UInt32(bitPattern: strDescriptor))]
            }
        )

        // 12. net.get_header(descriptor: i32, key: i32, keyLength: i32) -> i32
        imports.define(
            module: "net",
            name: "get_header",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let keyOffset = Int(Int32(bitPattern: args[1].i32))
                let keyLength = Int(Int32(bitPattern: args[2].i32))

                guard let request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let response = request.response else {
                    return [.i32(UInt32(bitPattern: NetResult.missingResponse.rawValue))]
                }
                guard let memory = caller.instance?.exports[memory: "memory"] else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard keyOffset >= 0, UInt(keyOffset) + UInt(keyLength) <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                let keyString: String? = memory.withUnsafeBufferPointer(offset: UInt(keyOffset), count: keyLength) {
                    buf in
                    String(bytes: buf, encoding: .utf8)
                }

                guard let keyString else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidString.rawValue))]
                }

                let value = response.value(forHTTPHeaderField: keyString) ?? ""
                let strDescriptor = self.resourceStore.store(string: value)
                return [.i32(UInt32(bitPattern: strDescriptor))]
            }
        )

        // 13. net.html(descriptor: i32) -> i32
        imports.define(
            module: "net",
            name: "html",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let data = request.responseData, let htmlString = String(data: data, encoding: .utf8) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidHtml.rawValue))]
                }

                do {
                    let doc = try SwiftSoup.parse(htmlString, request.url?.absoluteString ?? "")
                    let docDescriptor = self.resourceStore.storeObject(doc)
                    return [.i32(UInt32(bitPattern: docDescriptor))]
                } catch {
                    return [.i32(UInt32(bitPattern: NetResult.invalidHtml.rawValue))]
                }
            }
        )

        // 14. net.get_image(descriptor: i32) -> i32
        imports.define(
            module: "net",
            name: "get_image",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let request: NetRequest = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let data = request.responseData else {
                    return [.i32(UInt32(bitPattern: NetResult.notAnImage.rawValue))]
                }
                let imageDescriptor = self.resourceStore.store(data)
                return [.i32(UInt32(bitPattern: imageDescriptor))]
            }
        )

        // 15. net.send_all(descriptors: i32, length: i32) -> i32
        imports.define(
            module: "net",
            name: "send_all",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self else { return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))] }
                let descOffset = Int(Int32(bitPattern: args[0].i32))
                let length = Int(Int32(bitPattern: args[1].i32))

                guard descOffset >= 0, length > 0 else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard let memory = caller.instance?.exports[memory: "memory"] else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }
                guard UInt(descOffset) + UInt(length * 4) <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: NetResult.invalidDescriptor.rawValue))]
                }

                // Read descriptor array from guest linear memory
                let descArray: [Int32] = memory.withUnsafeBufferPointer(offset: UInt(descOffset), count: length * 4) {
                    buf in
                    buf.withMemoryRebound(to: Int32.self) { Array($0) }
                }

                let requests = descArray.map { self.resourceStore.fetchObject($0) as NetRequest? }
                let transport = self.transport
                let rateLimiter = self.rateLimiter

                let semaphore = DispatchSemaphore(value: 0)
                let batchBox = BatchRequestResult(count: length, requests: requests)

                Task.detached {
                    await withTaskGroup(of: (Int, Data?, HTTPURLResponse?, (any Error & Sendable)?).self) { group in
                        for (idx, req) in requests.enumerated() {
                            guard let req, let urlReq = req.toURLRequest() else {
                                batchBox.errorResults[idx] = NetResult.invalidDescriptor.rawValue
                                continue
                            }
                            group.addTask {
                                await rateLimiter.acquire()
                                do {
                                    let (data, resp) = try await transport.send(request: urlReq)
                                    return (idx, data, resp, nil)
                                } catch {
                                    return (idx, nil, nil, error)
                                }
                            }
                        }

                        for await (idx, data, resp, err) in group {
                            if let err {
                                batchBox.errorResults[idx] = NetResult.requestError.rawValue
                                if var req = batchBox.updatedRequests[idx] {
                                    req.responseError = err
                                    batchBox.updatedRequests[idx] = req
                                }
                            } else {
                                batchBox.errorResults[idx] = NetResult.success.rawValue
                                if var req = batchBox.updatedRequests[idx] {
                                    req.responseData = data
                                    req.response = resp
                                    batchBox.updatedRequests[idx] = req
                                }
                            }
                        }
                    }
                    semaphore.signal()
                }
                semaphore.wait()

                // Update resource store objects
                for (idx, req) in batchBox.updatedRequests.enumerated() {
                    if let req {
                        self.resourceStore.setObject(descArray[idx], req)
                    }
                }

                // Write error status codes back into memory
                memory.withUnsafeMutableBufferPointer(offset: UInt(descOffset), count: length * 4) { dest in
                    dest.withMemoryRebound(to: Int32.self) { rebound in
                        for (i, val) in batchBox.errorResults.enumerated() {
                            rebound[i] = val
                        }
                    }
                }

                let hasError = batchBox.errorResults.contains { $0 != NetResult.success.rawValue }
                return [
                    .i32(UInt32(bitPattern: hasError ? NetResult.requestError.rawValue : NetResult.success.rawValue))
                ]
            }
        )
    }

    /// Creates and returns a populated `Imports` instance containing the `net` module.
    public func makeImports(store: Store) -> Imports {
        var imports = Imports()
        register(into: &imports, store: store)
        return imports
    }
}

private final class SingleRequestResult: @unchecked Sendable {
    var data: Data?
    var response: HTTPURLResponse?
    var error: (any Error & Sendable)?
}

private final class BatchRequestResult: @unchecked Sendable {
    var errorResults: [Int32]
    var updatedRequests: [NetRequest?]

    init(count: Int, requests: [NetRequest?]) {
        self.errorResults = Array(repeating: 0, count: count)
        self.updatedRequests = requests
    }
}

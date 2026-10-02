import Foundation
import SwiftSoup
import WasmKit

/// Provides `html` host functions imported by WebAssembly source extensions to parse, traverse, and query HTML DOM trees.
public final class HTMLImports: @unchecked Sendable {
    public enum HTMLKind: Int32 {
        case unknown = 0
        case node = 1
        case textNode = 2
        case dataNode = 3
        case comment = 4
        case element = 5
        case elementList = 6
        case document = 7
    }

    public enum HTMLResult: Int32 {
        case success = 0
        case invalidDescriptor = -1
        case invalidString = -2
        case invalidHtml = -3
        case invalidQuery = -4
        case noResult = -5
        case swiftSoupError = -6
    }

    public let resourceStore: ResourceStore

    public init(resourceStore: ResourceStore) {
        self.resourceStore = resourceStore
    }

    private func getMemory(from caller: borrowing Caller) -> Memory? {
        guard let instance = caller.instance else { return nil }
        guard let exportValue = instance.export("memory") else { return nil }
        guard case .memory(let memory) = exportValue else { return nil }
        return memory
    }

    private func readString(from memory: Memory, offset: UInt32, length: UInt32) -> String? {
        if length == 0 { return "" }
        let uOffset = UInt(offset)
        let uLength = Int(length)
        guard uOffset + UInt(uLength) <= memory.byteCount else { return nil }
        return memory.withUnsafeBufferPointer(offset: uOffset, count: uLength) { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }

    /// Registers all `html` module functions into the given WasmKit `Imports`.
    public func register(into imports: inout Imports, store: Store) {
        // 1. html.parse(html: i32, html_len: i32, base_url: i32, base_url_len: i32) -> i32
        imports.define(
            module: "html",
            name: "parse",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                guard let htmlString = self.readString(from: memory, offset: args[0].i32, length: args[1].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let baseUrlString = self.readString(from: memory, offset: args[2].i32, length: args[3].i32)

                do {
                    let doc =
                        if let baseUrlString, !baseUrlString.isEmpty {
                            try SwiftSoup.parse(htmlString, baseUrlString)
                        } else {
                            try SwiftSoup.parse(htmlString)
                        }
                    let desc = self.resourceStore.storeObject(doc)
                    return [.i32(UInt32(bitPattern: desc))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidHtml.rawValue))]
                }
            }
        )

        // 2. html.parse_fragment(html: i32, html_len: i32, base_url: i32, base_url_len: i32) -> i32
        imports.define(
            module: "html",
            name: "parse_fragment",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                guard let htmlString = self.readString(from: memory, offset: args[0].i32, length: args[1].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let baseUrlString = self.readString(from: memory, offset: args[2].i32, length: args[3].i32)

                do {
                    let doc =
                        if let baseUrlString, !baseUrlString.isEmpty {
                            try SwiftSoup.parseBodyFragment(htmlString, baseUrlString)
                        } else {
                            try SwiftSoup.parseBodyFragment(htmlString)
                        }
                    let desc = self.resourceStore.storeObject(doc)
                    return [.i32(UInt32(bitPattern: desc))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidHtml.rawValue))]
                }
            }
        )

        // 3. html.escape(text: i32, text_len: i32) -> i32
        imports.define(
            module: "html",
            name: "escape",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                guard let text = self.readString(from: memory, offset: args[0].i32, length: args[1].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let escaped = Entities.escape(text)
                let desc = self.resourceStore.store(string: escaped)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 4. html.unescape(text: i32, text_len: i32) -> i32
        imports.define(
            module: "html",
            name: "unescape",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                guard let text = self.readString(from: memory, offset: args[0].i32, length: args[1].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                do {
                    let unescaped = try Entities.unescape(text)
                    let desc = self.resourceStore.store(string: unescaped)
                    return [.i32(UInt32(bitPattern: desc))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 5. html.kind(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "kind",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if item is Document {
                    return [.i32(UInt32(bitPattern: HTMLKind.document.rawValue))]
                } else if item is Element {
                    return [.i32(UInt32(bitPattern: HTMLKind.element.rawValue))]
                } else if item is Elements {
                    return [.i32(UInt32(bitPattern: HTMLKind.elementList.rawValue))]
                } else if item is Comment {
                    return [.i32(UInt32(bitPattern: HTMLKind.comment.rawValue))]
                } else if item is TextNode {
                    return [.i32(UInt32(bitPattern: HTMLKind.textNode.rawValue))]
                } else if item is DataNode {
                    return [.i32(UInt32(bitPattern: HTMLKind.dataNode.rawValue))]
                } else if item is Node {
                    return [.i32(UInt32(bitPattern: HTMLKind.node.rawValue))]
                } else {
                    return [.i32(UInt32(bitPattern: HTMLKind.unknown.rawValue))]
                }
            }
        )

        // 6. html.child_nodes(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "child_nodes",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let node: Node = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                let desc = self.resourceStore.storeObject(node.getChildNodes())
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 7. html.has_attr(descriptor: i32, key: i32, key_len: i32) -> i32
        imports.define(
            module: "html",
            name: "has_attr",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let node: Node = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let attr = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                return [.i32(node.hasAttr(attr) ? 1 : 0)]
            }
        )

        // 8. html.set_attr(descriptor: i32, key: i32, key_len: i32, val: i32, val_len: i32) -> i32
        imports.define(
            module: "html",
            name: "set_attr",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let node: Node = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let key = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                guard let val = self.readString(from: memory, offset: args[3].i32, length: args[4].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    if val.isEmpty {
                        try node.removeAttr(key)
                    } else {
                        try node.attr(key, val)
                    }
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 9. html.remove_attr(descriptor: i32, key: i32, key_len: i32) -> i32
        imports.define(
            module: "html",
            name: "remove_attr",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let node: Node = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let key = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    try node.removeAttr(key)
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 10. html.set_text(descriptor: i32, text: i32, text_len: i32) -> i32
        imports.define(
            module: "html",
            name: "set_text",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let text = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    try elem.text(text)
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 11. html.set_html(descriptor: i32, text: i32, text_len: i32) -> i32
        imports.define(
            module: "html",
            name: "set_html",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let html = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    try elem.html(html)
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 12. html.prepend(descriptor: i32, text: i32, text_len: i32) -> i32
        imports.define(
            module: "html",
            name: "prepend",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let text = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    try elem.prepend(text)
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 13. html.append(descriptor: i32, text: i32, text_len: i32) -> i32
        imports.define(
            module: "html",
            name: "append",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let text = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    try elem.append(text)
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 14. html.children(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "children",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                let desc = self.resourceStore.storeObject(elem.children())
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 15. html.base_uri(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "base_uri",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                let desc = self.resourceStore.store(string: elem.getBaseUri())
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 16. html.own_text(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "own_text",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                let desc = self.resourceStore.store(string: elem.ownText())
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 17. html.data(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "data",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if let elem = item as? Element {
                    let desc = self.resourceStore.store(string: elem.data())
                    return [.i32(UInt32(bitPattern: desc))]
                } else if let node = item as? DataNode {
                    let desc = self.resourceStore.store(string: node.getWholeData())
                    return [.i32(UInt32(bitPattern: desc))]
                } else if let node = item as? Comment {
                    let desc = self.resourceStore.store(string: node.getData())
                    return [.i32(UInt32(bitPattern: desc))]
                } else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
            }
        )

        // 18. html.id(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "id",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                let desc = self.resourceStore.store(string: elem.id())
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 19. html.tag_name(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "tag_name",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                let desc = self.resourceStore.store(string: elem.tagName())
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 20. html.class_name(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "class_name",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                do {
                    let className = try elem.className()
                    let desc = self.resourceStore.store(string: className)
                    return [.i32(UInt32(bitPattern: desc))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 21. html.has_class(descriptor: i32, name: i32, name_len: i32) -> i32
        imports.define(
            module: "html",
            name: "has_class",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let className = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                return [.i32(elem.hasClass(className) ? 1 : 0)]
            }
        )

        // 22. html.add_class(descriptor: i32, name: i32, name_len: i32) -> i32
        imports.define(
            module: "html",
            name: "add_class",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let className = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    try elem.addClass(className)
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 23. html.remove_class(descriptor: i32, name: i32, name_len: i32) -> i32
        imports.define(
            module: "html",
            name: "remove_class",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elem: Element = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let className = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    try elem.removeClass(className)
                    return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 24. html.first(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "first",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elems: Elements = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let first = elems.first() else {
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                }
                let desc = self.resourceStore.storeObject(first)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 25. html.last(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "last",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let elems: Elements = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let last = elems.last() else {
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                }
                let desc = self.resourceStore.storeObject(last)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 26. html.get(descriptor: i32, index: i32) -> i32
        imports.define(
            module: "html",
            name: "get",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let index = Int(args[1].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if let elems = item as? Elements {
                    if elems.indices.contains(index) {
                        let desc = self.resourceStore.storeObject(elems.get(index))
                        return [.i32(UInt32(bitPattern: desc))]
                    }
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                } else if let array = item as? [Node] {
                    if array.indices.contains(index) {
                        let desc = self.resourceStore.storeObject(array[index])
                        return [.i32(UInt32(bitPattern: desc))]
                    }
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                } else if let array = item as? [Any] {
                    if array.indices.contains(index) {
                        let desc = self.resourceStore.storeObject(array[index])
                        return [.i32(UInt32(bitPattern: desc))]
                    }
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                }

                return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
            }
        )

        // 27. html.size(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "size",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if let elems = item as? Elements {
                    return [.i32(UInt32(elems.size()))]
                } else if let array = item as? [Any] {
                    return [.i32(UInt32(array.count))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
            }
        )

        // 28. html.parent(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "parent",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if let elem = item as? Element, let parent = elem.parent() {
                    let desc = self.resourceStore.storeObject(parent)
                    return [.i32(UInt32(bitPattern: desc))]
                } else if let node = item as? Node, let parent = node.parent() {
                    let desc = self.resourceStore.storeObject(parent)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )

        // 29. html.siblings(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "siblings",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if let elem = item as? Element {
                    let desc = self.resourceStore.storeObject(elem.siblingElements())
                    return [.i32(UInt32(bitPattern: desc))]
                } else if let node = item as? Node {
                    let desc = self.resourceStore.storeObject(node.siblingNodes())
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
            }
        )

        // 30. html.next(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "next",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if let elem = item as? Element, let next = try? elem.nextElementSibling() {
                    let desc = self.resourceStore.storeObject(next)
                    return [.i32(UInt32(bitPattern: desc))]
                } else if let node = item as? Node, let next = node.nextSibling() {
                    let desc = self.resourceStore.storeObject(next)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )

        // 31. html.previous(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "previous",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                if let elem = item as? Element, let prev = try? elem.previousElementSibling() {
                    let desc = self.resourceStore.storeObject(prev)
                    return [.i32(UInt32(bitPattern: desc))]
                } else if let node = item as? Node, let prev = node.previousSibling() {
                    let desc = self.resourceStore.storeObject(prev)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )

        // 32. html.attr(descriptor: i32, key: i32, key_len: i32) -> i32
        imports.define(
            module: "html",
            name: "attr",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let key = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                let value: String? =
                    if let elems = item as? Elements {
                        try? elems.attr(key)
                    } else if let node = item as? Node {
                        try? node.attr(key)
                    } else {
                        nil
                    }

                if let value {
                    let desc = self.resourceStore.store(string: value)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )

        // 33. html.outer_html(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "outer_html",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                let value: String? =
                    if let elems = item as? Elements {
                        try? elems.outerHtml()
                    } else if let node = item as? Node {
                        try? node.outerHtml()
                    } else {
                        nil
                    }

                if let value {
                    let desc = self.resourceStore.store(string: value)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )

        // 34. html.remove(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "remove",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                do {
                    if let elems = item as? Elements {
                        try elems.remove()
                        return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                    } else if let node = item as? Node {
                        try node.remove()
                        return [.i32(UInt32(bitPattern: HTMLResult.success.rawValue))]
                    }
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.swiftSoupError.rawValue))]
                }
            }
        )

        // 35. html.select(descriptor: i32, query: i32, query_len: i32) -> i32
        imports.define(
            module: "html",
            name: "select",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let queryString = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    let matched: Elements? =
                        if let baseElems = item as? Elements {
                            try baseElems.select(queryString)
                        } else if let elem = item as? Element {
                            try elem.select(queryString)
                        } else {
                            nil
                        }

                    if let matched {
                        let desc = self.resourceStore.storeObject(matched)
                        return [.i32(UInt32(bitPattern: desc))]
                    }
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidQuery.rawValue))]
                }
            }
        )

        // 36. html.select_first(descriptor: i32, query: i32, query_len: i32) -> i32
        imports.define(
            module: "html",
            name: "select_first",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }
                guard let queryString = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidString.rawValue))]
                }

                do {
                    let matchedFirst: Element? =
                        if let baseElems = item as? Elements {
                            try baseElems.select(queryString).first()
                        } else if let elem = item as? Element {
                            try elem.select(queryString).first()
                        } else {
                            nil
                        }

                    if let matchedFirst {
                        let desc = self.resourceStore.storeObject(matchedFirst)
                        return [.i32(UInt32(bitPattern: desc))]
                    }
                    return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidQuery.rawValue))]
                }
            }
        )

        // 37. html.text(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "text",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                let text: String? =
                    if let elems = item as? Elements {
                        try? elems.text()
                    } else if let elem = item as? Element {
                        try? elem.text()
                    } else if let textNode = item as? TextNode {
                        textNode.text()
                    } else {
                        nil
                    }

                if let text {
                    let desc = self.resourceStore.store(string: text)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )

        // 38. html.untrimmed_text(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "untrimmed_text",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                let text: String? =
                    if let elems = item as? Elements {
                        try? elems.text(trimAndNormaliseWhitespace: false)
                    } else if let elem = item as? Element {
                        try? elem.text(trimAndNormaliseWhitespace: false)
                    } else if let textNode = item as? TextNode {
                        textNode.getWholeText()
                    } else {
                        nil
                    }

                if let text {
                    let desc = self.resourceStore.store(string: text)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )

        // 39. html.html(descriptor: i32) -> i32
        imports.define(
            module: "html",
            name: "html",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let item: Any = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: HTMLResult.invalidDescriptor.rawValue))]
                }

                let text: String? =
                    if let elems = item as? Elements {
                        try? elems.html()
                    } else if let elem = item as? Element {
                        try? elem.html()
                    } else {
                        nil
                    }

                if let text {
                    let desc = self.resourceStore.store(string: text)
                    return [.i32(UInt32(bitPattern: desc))]
                }
                return [.i32(UInt32(bitPattern: HTMLResult.noResult.rawValue))]
            }
        )
    }

    /// Creates and returns a populated `Imports` instance containing the `html` module.
    public func makeImports(store: Store) -> Imports {
        var imports = Imports()
        register(into: &imports, store: store)
        return imports
    }
}

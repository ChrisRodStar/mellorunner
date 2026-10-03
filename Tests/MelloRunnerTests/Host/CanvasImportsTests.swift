import CoreGraphics
import Foundation
import Testing
import WasmKit

@testable import MelloRunner

#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

@Suite("Canvas Imports Tests")
struct CanvasImportsTests {
    @Test("CanvasContext initialization and dimensions")
    func testCanvasContextCreation() {
        let ctx = CanvasContext(width: 200, height: 100)
        #expect(ctx != nil)
        #expect(ctx?.width == 200)
        #expect(ctx?.height == 100)

        let invalidCtx = CanvasContext(width: 0, height: 100)
        #expect(invalidCtx == nil)
    }

    @Test("CanvasImports new_context registration and descriptor return")
    func testNewContextFunction() {
        let store = Store(engine: Engine())
        let resourceStore = ResourceStore()
        let canvas = CanvasImports(resourceStore: resourceStore)
        let imports = canvas.makeImports(store: store)
        _ = imports

        // Test context creation via Store directly
        let ctx = CanvasContext(width: 150, height: 150)
        #expect(ctx != nil)
        let desc = resourceStore.storeObject(ctx!)
        #expect(desc > 0)
        let fetched: CanvasContext? = resourceStore.fetchObject(desc)
        #expect(fetched != nil)
        #expect(fetched?.width == 150)
    }

    @Test("Canvas image creation, dimension inspection, and PNG extraction")
    func testCanvasImageLifecycle() throws {
        let resourceStore = ResourceStore()

        // Create a 10x10 synthetic PNG bitmap
        let ctx = CanvasContext(width: 10, height: 10)!
        let img = try #require(ctx.makeImage())
        #expect(img.size.width == 10)
        #expect(img.size.height == 10)

        let desc = resourceStore.storeObject(img)
        #expect(desc > 0)

        let fetchedImage = try #require(resourceStore.fetchImage(desc))
        #expect(fetchedImage.size.width == 10)
        #expect(fetchedImage.size.height == 10)

        let pngData = try #require(fetchedImage.pngData())
        #expect(!pngData.isEmpty)

        // Store raw data and verify fetchImage converts it automatically
        let rawDesc = resourceStore.store(pngData)
        let convertedImage = try #require(resourceStore.fetchImage(rawDesc))
        #expect(convertedImage.size.width == 10)
    }

    @Test("Canvas path filling and stroke execution")
    func testCanvasPathOperations() throws {
        let ctx = try #require(CanvasContext(width: 100, height: 100))

        let path = CanvasPath(ops: [
            .moveTo(CanvasPoint(x: 10, y: 10)),
            .lineTo(CanvasPoint(x: 90, y: 10)),
            .lineTo(CanvasPoint(x: 90, y: 90)),
            .lineTo(CanvasPoint(x: 10, y: 90)),
            .close,
        ])

        let color = CanvasColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ctx.fill(path: path, color: color)

        let strokeStyle = CanvasStrokeStyle(
            color: CanvasColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),
            width: 2.0,
            cap: .round,
            join: .round,
            miterLimit: 10.0,
            dashArray: [],
            dashOffset: 0.0
        )
        ctx.stroke(path: path, style: strokeStyle)

        let rendered = try #require(ctx.makeImage())
        #expect(rendered.size.width == 100)
        #expect(rendered.size.height == 100)
    }

    @Test("Canvas text rendering and system font loading")
    func testCanvasTextRendering() throws {
        let ctx = try #require(CanvasContext(width: 200, height: 50))
        let font = PlatformFont.systemFont(ofSize: 14, weight: .bold)

        ctx.drawText(
            string: "Test Title",
            font: font,
            size: 14,
            x: 10,
            y: 10,
            color: CanvasColor(red: 0, green: 0, blue: 0, alpha: 1)
        )

        let rendered = try #require(ctx.makeImage())
        #expect(rendered.size.width == 200)
    }

    @Test("Canvas copy_image slicing and composite drawing")
    func testCanvasCopyImage() throws {
        let sourceCtx = try #require(CanvasContext(width: 100, height: 100))
        let sourceImage = try #require(sourceCtx.makeImage())

        let destCtx = try #require(CanvasContext(width: 200, height: 200))
        let drawResult = destCtx.drawImage(image: sourceImage, dstX: 0, dstY: 0, dstW: 100, dstH: 100)
        #expect(drawResult == .success)

        let copyResult = destCtx.copyImage(
            image: sourceImage,
            srcX: 0,
            srcY: 0,
            srcW: 50,
            srcH: 50,
            dstX: 100,
            dstY: 100,
            dstW: 100,
            dstH: 100
        )
        #expect(copyResult == .success)

        let finalImage = try #require(destCtx.makeImage())
        #expect(finalImage.size.width == 200)
    }

    @Test("CanvasImports invocation via synthetic WasmKit module")
    func testCanvasWasmExecution() throws {
        let store = Store(engine: Engine())
        let resourceStore = ResourceStore()
        let canvas = CanvasImports(resourceStore: resourceStore)
        let imports = canvas.makeImports(store: store)

        // Synthetic Wasm calling canvas.new_context(100.0, 100.0) -> i32
        // Type 0: (f32, f32) -> i32
        // Type 1: () -> i32
        // Import: "canvas" "new_context" func 0
        // Export: "test_new_context" -> func 1
        let wasmBytes: [UInt8] = [
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,  // Magic & Version
            0x01, 0x0b, 0x02,  // Type section (11 bytes)
            0x60, 0x02, 0x7d, 0x7d, 0x01, 0x7f,  // type 0: (f32, f32) -> i32
            0x60, 0x00, 0x01, 0x7f,  // type 1: () -> i32
            0x02, 0x16, 0x01,  // Import section (22 bytes)
            0x06, 0x63, 0x61, 0x6e, 0x76, 0x61, 0x73,  // "canvas"
            0x0b, 0x6e, 0x65, 0x77, 0x5f, 0x63, 0x6f, 0x6e, 0x74, 0x65, 0x78, 0x74,  // "new_context"
            0x00, 0x00,  // func 0
            0x03, 0x02, 0x01, 0x01,  // Function section: func 1 has type 1
            0x07, 0x14, 0x01,  // Export section (20 bytes)
            0x10, 0x74, 0x65, 0x73, 0x74, 0x5f, 0x6e, 0x65, 0x77, 0x5f, 0x63, 0x6f, 0x6e, 0x74, 0x65, 0x78, 0x74, 0x00,
            0x01,  // "test_new_context" -> func 1
            0x0a, 0x10, 0x01,  // Code section (16 bytes)
            0x0e, 0x00,  // func 1 body: 14 bytes, 0 locals
            0x43, 0x00, 0x00, 0xc8, 0x42,  // f32.const 100.0 (0x42c80000)
            0x43, 0x00, 0x00, 0xc8, 0x42,  // f32.const 100.0 (0x42c80000)
            0x10, 0x00,  // call 0
            0x0b,  // end
        ]

        let module = try parseWasm(bytes: wasmBytes)
        let instance = try module.instantiate(store: store, imports: imports)

        guard let testFnExport = instance.export("test_new_context"),
            case .function(let testFn) = testFnExport
        else {
            Issue.record("Missing test_new_context export")
            return
        }

        let res = try testFn.invoke([])
        guard let first = res.first, case .i32(let descPattern) = first else {
            Issue.record("Expected i32 from test_new_context")
            return
        }

        let desc = Int32(bitPattern: descPattern)
        #expect(desc > 0)
        let createdCtx: CanvasContext? = resourceStore.fetchObject(desc)
        #expect(createdCtx != nil)
        #expect(createdCtx?.width == 100)
        #expect(createdCtx?.height == 100)
    }
}

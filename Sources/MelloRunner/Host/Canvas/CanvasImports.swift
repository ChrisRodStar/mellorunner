import CoreGraphics
import CoreText
import Foundation
import WasmKit

#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

/// Provides `canvas` host functions imported by WebAssembly source extensions to create 2D graphics contexts,
/// draw shapes, render typography, slice images, and export rasterized buffers.
public final class CanvasImports: @unchecked Sendable {
    public enum CanvasResult: Int32 {
        case success = 0
        case invalidContext = -1
        case invalidImagePointer = -2
        case invalidImage = -3
        case invalidSrcRect = -4
        case invalidResult = -5
        case invalidBounds = -6
        case invalidPath = -7
        case invalidStyle = -8
        case invalidString = -9
        case invalidFont = -10
        case invalidData = -11
        case fontLoadFailed = -12
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

    private func readData(from memory: Memory, offset: Int32, length: Int32) -> Data? {
        guard offset >= 0, length >= 0 else { return nil }
        if length == 0 { return Data() }
        let uOffset = UInt(offset)
        let uLength = Int(length)
        guard uOffset + UInt(uLength) <= memory.byteCount else { return nil }
        return memory.withUnsafeBufferPointer(offset: uOffset, count: uLength) { buf in
            Data(buf)
        }
    }

    private func readString(from memory: Memory, offset: Int32, length: Int32) -> String? {
        guard let data = readData(from: memory, offset: offset, length: length) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func readGuestBuffer(from memory: Memory, pointer: Int32) -> Data? {
        guard pointer >= 0 else { return nil }
        let uOffset = UInt(pointer)
        guard uOffset + 8 <= memory.byteCount else { return nil }
        let totalLength: UInt32 = memory.withUnsafeBufferPointer(offset: uOffset, count: 4) { raw in
            raw.load(as: UInt32.self)
        }
        guard totalLength >= 8, uOffset + UInt(totalLength) <= memory.byteCount else { return nil }
        let payloadLength = Int(totalLength - 8)
        return memory.withUnsafeBufferPointer(offset: uOffset + 8, count: payloadLength) { raw in
            Data(raw)
        }
    }

    /// Registers all 15 `canvas` module functions into the given WasmKit `Imports`.
    public func register(into imports: inout Imports, store: Store) {
        // 1. canvas.new_context(width: f32, height: f32) -> i32
        imports.define(
            module: "canvas",
            name: "new_context",
            Function(store: store, type: FunctionType(parameters: [.f32, .f32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))] }
                let width = Float(bitPattern: args[0].f32)
                let height = Float(bitPattern: args[1].f32)

                guard width > 0, height > 0 else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidBounds.rawValue))]
                }

                guard let context = CanvasContext(width: Int(width), height: Int(height)) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }

                let desc = self.resourceStore.storeObject(context)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 2. canvas.set_transform(desc: i32, tx: f32, ty: f32, sx: f32, sy: f32, angle: f32) -> i32
        imports.define(
            module: "canvas",
            name: "set_transform",
            Function(
                store: store,
                type: FunctionType(parameters: [.i32, .f32, .f32, .f32, .f32, .f32], results: [.i32])
            ) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))] }
                let desc = Int32(bitPattern: args[0].i32)
                guard let canvasCtx: CanvasContext = self.resourceStore.fetchObject(desc) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }

                let tx = Float(bitPattern: args[1].f32)
                let ty = Float(bitPattern: args[2].f32)
                let sx = Float(bitPattern: args[3].f32)
                let sy = Float(bitPattern: args[4].f32)
                let angle = Float(bitPattern: args[5].f32)

                canvasCtx.setTransform(translateX: tx, translateY: ty, scaleX: sx, scaleY: sy, rotateAngle: angle)
                return [.i32(UInt32(bitPattern: CanvasResult.success.rawValue))]
            }
        )

        // 3. canvas.draw_image(desc: i32, imageRef: i32, dstX: f32, dstY: f32, dstW: f32, dstH: f32) -> i32
        imports.define(
            module: "canvas",
            name: "draw_image",
            Function(
                store: store,
                type: FunctionType(parameters: [.i32, .i32, .f32, .f32, .f32, .f32], results: [.i32])
            ) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))] }
                let desc = Int32(bitPattern: args[0].i32)
                guard let canvasCtx: CanvasContext = self.resourceStore.fetchObject(desc) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }
                let imageRef = Int32(bitPattern: args[1].i32)
                guard let image = self.resourceStore.fetchImage(imageRef) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidImagePointer.rawValue))]
                }

                let dstX = Float(bitPattern: args[2].f32)
                let dstY = Float(bitPattern: args[3].f32)
                let dstW = Float(bitPattern: args[4].f32)
                let dstH = Float(bitPattern: args[5].f32)

                let res = canvasCtx.drawImage(image: image, dstX: dstX, dstY: dstY, dstW: dstW, dstH: dstH)
                return [.i32(UInt32(bitPattern: res.rawValue))]
            }
        )

        // 4. canvas.copy_image(desc: i32, imageRef: i32, sx: f32, sy: f32, sW: f32, sH: f32, dx: f32, dy: f32, dW: f32, dH: f32) -> i32
        imports.define(
            module: "canvas",
            name: "copy_image",
            Function(
                store: store,
                type: FunctionType(
                    parameters: [.i32, .i32, .f32, .f32, .f32, .f32, .f32, .f32, .f32, .f32],
                    results: [.i32]
                )
            ) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))] }
                let desc = Int32(bitPattern: args[0].i32)
                guard let canvasCtx: CanvasContext = self.resourceStore.fetchObject(desc) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }
                let imageRef = Int32(bitPattern: args[1].i32)
                guard let image = self.resourceStore.fetchImage(imageRef) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidImagePointer.rawValue))]
                }

                let sx = Float(bitPattern: args[2].f32)
                let sy = Float(bitPattern: args[3].f32)
                let sW = Float(bitPattern: args[4].f32)
                let sH = Float(bitPattern: args[5].f32)
                let dx = Float(bitPattern: args[6].f32)
                let dy = Float(bitPattern: args[7].f32)
                let dW = Float(bitPattern: args[8].f32)
                let dH = Float(bitPattern: args[9].f32)

                let res = canvasCtx.copyImage(
                    image: image,
                    srcX: sx,
                    srcY: sy,
                    srcW: sW,
                    srcH: sH,
                    dstX: dx,
                    dstY: dy,
                    dstW: dW,
                    dstH: dH
                )
                return [.i32(UInt32(bitPattern: res.rawValue))]
            }
        )

        // 5. canvas.fill(desc: i32, pathPtr: i32, r: f32, g: f32, b: f32, a: f32) -> i32
        imports.define(
            module: "canvas",
            name: "fill",
            Function(
                store: store,
                type: FunctionType(parameters: [.i32, .i32, .f32, .f32, .f32, .f32], results: [.i32])
            ) { [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }
                let desc = Int32(bitPattern: args[0].i32)
                guard let canvasCtx: CanvasContext = self.resourceStore.fetchObject(desc) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }

                let pathPtr = Int32(bitPattern: args[1].i32)
                guard let pathData = self.readGuestBuffer(from: memory, pointer: pathPtr),
                    let path = try? PostcardDecoder().decode(CanvasPath.self, from: pathData)
                else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidPath.rawValue))]
                }

                let r = Float(bitPattern: args[2].f32)
                let g = Float(bitPattern: args[3].f32)
                let b = Float(bitPattern: args[4].f32)
                let a = Float(bitPattern: args[5].f32)

                let color = CanvasColor(red: r, green: g, blue: b, alpha: a)
                canvasCtx.fill(path: path, color: color)
                return [.i32(UInt32(bitPattern: CanvasResult.success.rawValue))]
            }
        )

        // 6. canvas.stroke(desc: i32, pathPtr: i32, stylePtr: i32) -> i32
        imports.define(
            module: "canvas",
            name: "stroke",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }
                let desc = Int32(bitPattern: args[0].i32)
                guard let canvasCtx: CanvasContext = self.resourceStore.fetchObject(desc) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }

                let pathPtr = Int32(bitPattern: args[1].i32)
                guard let pathData = self.readGuestBuffer(from: memory, pointer: pathPtr),
                    let path = try? PostcardDecoder().decode(CanvasPath.self, from: pathData)
                else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidPath.rawValue))]
                }

                let stylePtr = Int32(bitPattern: args[2].i32)
                guard let styleData = self.readGuestBuffer(from: memory, pointer: stylePtr),
                    let style = try? PostcardDecoder().decode(CanvasStrokeStyle.self, from: styleData)
                else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidStyle.rawValue))]
                }

                canvasCtx.stroke(path: path, style: style)
                return [.i32(UInt32(bitPattern: CanvasResult.success.rawValue))]
            }
        )

        // 7. canvas.draw_text(desc: i32, textPtr: i32, textLen: i32, size: f32, x: f32, y: f32, fontPtr: i32, r: f32, g: f32, b: f32, a: f32) -> i32
        imports.define(
            module: "canvas",
            name: "draw_text",
            Function(
                store: store,
                type: FunctionType(
                    parameters: [.i32, .i32, .i32, .f32, .f32, .f32, .i32, .f32, .f32, .f32, .f32],
                    results: [.i32]
                )
            ) { [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }
                let desc = Int32(bitPattern: args[0].i32)
                guard let canvasCtx: CanvasContext = self.resourceStore.fetchObject(desc) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }

                let textPtr = Int32(bitPattern: args[1].i32)
                let textLen = Int32(bitPattern: args[2].i32)
                guard let text = self.readString(from: memory, offset: textPtr, length: textLen) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidString.rawValue))]
                }

                let size = Float(bitPattern: args[3].f32)
                let x = Float(bitPattern: args[4].f32)
                let y = Float(bitPattern: args[5].f32)

                let fontPtr = Int32(bitPattern: args[6].i32)
                guard let font: PlatformFont = self.resourceStore.fetchObject(fontPtr) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidFont.rawValue))]
                }

                let r = Float(bitPattern: args[7].f32)
                let g = Float(bitPattern: args[8].f32)
                let b = Float(bitPattern: args[9].f32)
                let a = Float(bitPattern: args[10].f32)

                let color = CanvasColor(red: r, green: g, blue: b, alpha: a)
                canvasCtx.drawText(string: text, font: font, size: size, x: x, y: y, color: color)
                return [.i32(UInt32(bitPattern: CanvasResult.success.rawValue))]
            }
        )

        // 8. canvas.get_image(desc: i32) -> i32
        imports.define(
            module: "canvas",
            name: "get_image",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))] }
                let desc = Int32(bitPattern: args[0].i32)
                guard let canvasCtx: CanvasContext = self.resourceStore.fetchObject(desc) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidContext.rawValue))]
                }

                guard let image = canvasCtx.makeImage() else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidResult.rawValue))]
                }

                let imageDesc = self.resourceStore.storeObject(image)
                return [.i32(UInt32(bitPattern: imageDesc))]
            }
        )

        // 9. canvas.new_font(namePtr: i32, nameLen: i32) -> i32
        imports.define(
            module: "canvas",
            name: "new_font",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidFont.rawValue))]
                }
                let namePtr = Int32(bitPattern: args[0].i32)
                let nameLen = Int32(bitPattern: args[1].i32)
                guard let name = self.readString(from: memory, offset: namePtr, length: nameLen) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidString.rawValue))]
                }

                guard let font = PlatformFont(name: name, size: PlatformFont.systemFontSize) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidFont.rawValue))]
                }

                let fontDesc = self.resourceStore.storeObject(font)
                return [.i32(UInt32(bitPattern: fontDesc))]
            }
        )

        // 10. canvas.system_font(weight: i32) -> i32
        imports.define(
            module: "canvas",
            name: "system_font",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: CanvasResult.invalidFont.rawValue))] }
                let weightRaw = Int32(bitPattern: args[0].i32)
                let weight = CanvasFontWeight(rawValue: UInt8(clamping: weightRaw)) ?? .regular
                let font = PlatformFont.systemFont(ofSize: PlatformFont.systemFontSize, weight: weight.platformWeight)
                let fontDesc = self.resourceStore.storeObject(font)
                return [.i32(UInt32(bitPattern: fontDesc))]
            }
        )

        // 11. canvas.load_font(urlPtr: i32, urlLen: i32) -> i32
        imports.define(
            module: "canvas",
            name: "load_font",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.fontLoadFailed.rawValue))]
                }
                let urlPtr = Int32(bitPattern: args[0].i32)
                let urlLen = Int32(bitPattern: args[1].i32)
                guard let urlString = self.readString(from: memory, offset: urlPtr, length: urlLen),
                    let url = URL(string: urlString)
                else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidString.rawValue))]
                }

                guard let dataProvider = CGDataProvider(url: url as CFURL),
                    let cgFont = CGFont(dataProvider)
                else {
                    return [.i32(UInt32(bitPattern: CanvasResult.fontLoadFailed.rawValue))]
                }

                if #available(macOS 15.0, iOS 18.0, *) {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                } else {
                    CTFontManagerRegisterGraphicsFont(cgFont, nil)
                }

                guard let name = cgFont.postScriptName as? String,
                    let font = PlatformFont(name: name, size: PlatformFont.systemFontSize)
                else {
                    return [.i32(UInt32(bitPattern: CanvasResult.fontLoadFailed.rawValue))]
                }

                let fontDesc = self.resourceStore.storeObject(font)
                return [.i32(UInt32(bitPattern: fontDesc))]
            }
        )

        // 12. canvas.new_image(dataPtr: i32, dataLen: i32) -> i32
        imports.define(
            module: "canvas",
            name: "new_image",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidData.rawValue))]
                }
                let dataPtr = Int32(bitPattern: args[0].i32)
                let dataLen = Int32(bitPattern: args[1].i32)
                guard let data = self.readData(from: memory, offset: dataPtr, length: dataLen) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidData.rawValue))]
                }

                guard let image = PlatformImage(data: data) else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidImage.rawValue))]
                }

                let imageDesc = self.resourceStore.storeObject(image)
                return [.i32(UInt32(bitPattern: imageDesc))]
            }
        )

        // 13. canvas.get_image_data(imageRef: i32) -> i32
        imports.define(
            module: "canvas",
            name: "get_image_data",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: CanvasResult.invalidImagePointer.rawValue))] }
                let imageRef = Int32(bitPattern: args[0].i32)

                let stored = self.resourceStore.fetch(imageRef)
                if let stored {
                    let desc = self.resourceStore.store(stored)
                    return [.i32(UInt32(bitPattern: desc))]
                }

                guard let image: PlatformImage = self.resourceStore.fetchObject(imageRef) else {
                    if let rawData: Data = self.resourceStore.fetchObject(imageRef) {
                        let desc = self.resourceStore.store(rawData)
                        return [.i32(UInt32(bitPattern: desc))]
                    }
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidImagePointer.rawValue))]
                }

                guard let pngData = image.pngData() else {
                    return [.i32(UInt32(bitPattern: CanvasResult.invalidImage.rawValue))]
                }

                let desc = self.resourceStore.store(pngData)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 14. canvas.get_image_width(imageRef: i32) -> f32
        imports.define(
            module: "canvas",
            name: "get_image_width",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.f32])) {
                [weak self] _, args in
                guard let self else {
                    let err = Float(CanvasResult.invalidImagePointer.rawValue)
                    return [.f32(err.bitPattern)]
                }
                let imageRef = Int32(bitPattern: args[0].i32)
                guard let image = self.resourceStore.fetchImage(imageRef) else {
                    let err = Float(CanvasResult.invalidImagePointer.rawValue)
                    return [.f32(err.bitPattern)]
                }
                let width = Float(image.size.width)
                return [.f32(width.bitPattern)]
            }
        )

        // 15. canvas.get_image_height(imageRef: i32) -> f32
        imports.define(
            module: "canvas",
            name: "get_image_height",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.f32])) {
                [weak self] _, args in
                guard let self else {
                    let err = Float(CanvasResult.invalidImagePointer.rawValue)
                    return [.f32(err.bitPattern)]
                }
                let imageRef = Int32(bitPattern: args[0].i32)
                guard let image = self.resourceStore.fetchImage(imageRef) else {
                    let err = Float(CanvasResult.invalidImagePointer.rawValue)
                    return [.f32(err.bitPattern)]
                }
                let height = Float(image.size.height)
                return [.f32(height.bitPattern)]
            }
        )
    }

    /// Creates and returns a populated `Imports` instance containing the `canvas` module.
    public func makeImports(store: Store) -> Imports {
        var imports = Imports()
        register(into: &imports, store: store)
        return imports
    }
}

// MARK: - Canvas Context

public final class CanvasContext: @unchecked Sendable {
    public let context: CGContext
    public let width: Int
    public let height: Int

    public init?(width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard
            let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            return nil
        }
        self.context = ctx
        self.context.saveGState()
    }

    public func setTransform(
        translateX: Float,
        translateY: Float,
        scaleX: Float,
        scaleY: Float,
        rotateAngle: Float
    ) {
        context.restoreGState()
        context.saveGState()

        context.translateBy(x: CGFloat(translateX), y: CGFloat(translateY))
        context.scaleBy(x: CGFloat(scaleX), y: CGFloat(scaleY))
        context.rotate(by: CGFloat(rotateAngle))
    }

    public func drawImage(
        image: PlatformImage,
        dstX: Float,
        dstY: Float,
        dstW: Float,
        dstH: Float
    ) -> CanvasImports.CanvasResult {
        guard let cgImage = image.cgImage else {
            return .invalidImage
        }
        let dstRect = CGRect(x: CGFloat(dstX), y: CGFloat(dstY), width: CGFloat(dstW), height: CGFloat(dstH))
        context.saveGState()
        context.flipVertically()
        context.draw(
            cgImage,
            in: dstRect.adjustForFlippedCoordinates(imageHeight: CGFloat(context.height))
        )
        context.restoreGState()
        return .success
    }

    public func copyImage(
        image: PlatformImage,
        srcX: Float,
        srcY: Float,
        srcW: Float,
        srcH: Float,
        dstX: Float,
        dstY: Float,
        dstW: Float,
        dstH: Float
    ) -> CanvasImports.CanvasResult {
        guard let cgImage = image.cgImage else {
            return .invalidImage
        }
        let srcRect = CGRect(x: CGFloat(srcX), y: CGFloat(srcY), width: CGFloat(srcW), height: CGFloat(srcH))
        let dstRect = CGRect(x: CGFloat(dstX), y: CGFloat(dstY), width: CGFloat(dstW), height: CGFloat(dstH))

        guard let cropped = cgImage.cropping(to: srcRect) else {
            return .invalidSrcRect
        }

        context.saveGState()
        context.flipVertically()
        context.draw(
            cropped,
            in: dstRect.adjustForFlippedCoordinates(imageHeight: CGFloat(context.height))
        )
        context.restoreGState()
        return .success
    }

    public func fill(path: CanvasPath, color: CanvasColor) {
        context.saveGState()
        path.draw(in: context)
        context.setFillColor(color.into())
        context.fillPath()
        context.restoreGState()
    }

    public func stroke(path: CanvasPath, style: CanvasStrokeStyle) {
        context.saveGState()
        path.draw(in: context)
        style.addTo(context: context)
        context.strokePath()
        context.restoreGState()
    }

    public func drawText(
        string: String,
        font: PlatformFont,
        size: Float,
        x: Float,
        y: Float,
        color: CanvasColor
    ) {
        context.saveGState()
        context.flipVertically()

        let attributed = NSAttributedString(
            string: string,
            attributes: [
                .foregroundColor: color.into(),
                .font: font.withSize(CGFloat(size)),
            ])
        let line = CTLineCreateWithAttributedString(attributed)
        let stringRect = CTLineGetImageBounds(line, context)
        context.textPosition = CGPoint(
            x: CGFloat(x),
            y: CGFloat(context.height) - CGFloat(y) - stringRect.height
        )
        CTLineDraw(line, context)

        context.restoreGState()
    }

    public func makeImage() -> PlatformImage? {
        guard let cgImage = context.makeImage() else { return nil }
        #if canImport(UIKit)
            return UIImage(cgImage: cgImage)
        #else
            return NSImageFixed(NSImage(cgImage: cgImage, size: CGSize(width: width, height: height)))
        #endif
    }
}

// MARK: - Canvas Models

public struct CanvasPoint: Codable {
    public let x: Float32
    public let y: Float32

    public init(x: Float32, y: Float32) {
        self.x = x
        self.y = y
    }

    public func into() -> CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

public enum CanvasPathOp {
    case moveTo(CanvasPoint)
    case lineTo(CanvasPoint)
    case quadTo(CanvasPoint, CanvasPoint)
    case cubicTo(CanvasPoint, CanvasPoint, CanvasPoint)
    case arc(CanvasPoint, Float32, Float32, Float32)
    case close
}

extension CanvasPathOp: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(UInt8.self, forKey: .type)

        switch type {
            case 0:
                let point = try container.decode(CanvasPoint.self, forKey: .moveTo)
                self = .moveTo(point)
            case 1:
                let point = try container.decode(CanvasPoint.self, forKey: .lineTo)
                self = .lineTo(point)
            case 2:
                let point1 = try container.decode(CanvasPoint.self, forKey: .quadTo)
                let point2 = try container.decode(CanvasPoint.self, forKey: .quadTo)
                self = .quadTo(point1, point2)
            case 3:
                let point1 = try container.decode(CanvasPoint.self, forKey: .cubicTo)
                let point2 = try container.decode(CanvasPoint.self, forKey: .cubicTo)
                let point3 = try container.decode(CanvasPoint.self, forKey: .cubicTo)
                self = .cubicTo(point1, point2, point3)
            case 4:
                let point = try container.decode(CanvasPoint.self, forKey: .arc)
                let radius = try container.decode(Float32.self, forKey: .arc)
                let startAngle = try container.decode(Float32.self, forKey: .arc)
                let endAngle = try container.decode(Float32.self, forKey: .arc)
                self = .arc(point, radius, startAngle, endAngle)
            case 5:
                self = .close
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Invalid PathOp type \(type)"
                )
        }
    }

    private enum CodingKeys: CodingKey {
        case type
        case moveTo
        case lineTo
        case quadTo
        case cubicTo
        case arc
        case close
    }
}

public struct CanvasPath: Decodable {
    public let ops: [CanvasPathOp]

    public init(ops: [CanvasPathOp]) {
        self.ops = ops
    }

    public func draw(in context: CGContext) {
        var pathOpen = false
        for op in ops {
            if !pathOpen {
                context.beginPath()
                pathOpen = true
            }
            switch op {
                case .moveTo(let point):
                    context.move(to: point.into())
                case .lineTo(let point):
                    context.addLine(to: point.into())
                case .quadTo(let point1, let point2):
                    context.addQuadCurve(to: point1.into(), control: point2.into())
                case .cubicTo(let point1, let point2, let point3):
                    context.addCurve(
                        to: point1.into(),
                        control1: point2.into(),
                        control2: point3.into()
                    )
                case .arc(let center, let radius, let startAngle, let sweepAngle):
                    context.addArc(
                        center: center.into(),
                        radius: CGFloat(radius),
                        startAngle: CGFloat(startAngle),
                        endAngle: CGFloat(abs(sweepAngle)),
                        clockwise: sweepAngle >= 0
                    )
                case .close:
                    context.closePath()
                    pathOpen = false
            }
        }
    }
}

public enum CanvasLineCap: UInt8, Codable {
    case round = 0
    case square = 1
    case butt = 2
}

public enum CanvasLineJoin: UInt8, Codable {
    case round = 0
    case bevel = 1
    case miter = 2
}

public struct CanvasColor: Codable {
    public let red: Float32
    public let green: Float32
    public let blue: Float32
    public let alpha: Float32

    public init(red: Float32, green: Float32, blue: Float32, alpha: Float32) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public func into() -> CGColor {
        CGColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}

public struct CanvasStrokeStyle: Codable {
    public let color: CanvasColor
    public let width: Float32
    public let cap: CanvasLineCap
    public let join: CanvasLineJoin
    public let miterLimit: Float32
    public let dashArray: [Float32]
    public let dashOffset: Float32

    public init(
        color: CanvasColor,
        width: Float32,
        cap: CanvasLineCap,
        join: CanvasLineJoin,
        miterLimit: Float32,
        dashArray: [Float32],
        dashOffset: Float32
    ) {
        self.color = color
        self.width = width
        self.cap = cap
        self.join = join
        self.miterLimit = miterLimit
        self.dashArray = dashArray
        self.dashOffset = dashOffset
    }

    public func addTo(context: CGContext) {
        context.setStrokeColor(color.into())
        context.setLineWidth(CGFloat(width))
        switch cap {
            case .round:
                context.setLineCap(.round)
            case .square:
                context.setLineCap(.square)
            case .butt:
                context.setLineCap(.butt)
        }
        switch join {
            case .round:
                context.setLineJoin(.round)
            case .bevel:
                context.setLineJoin(.bevel)
            case .miter:
                context.setLineJoin(.miter)
        }
        context.setMiterLimit(CGFloat(miterLimit))
        if !dashArray.isEmpty {
            context.setLineDash(phase: CGFloat(dashOffset), lengths: dashArray.map { CGFloat($0) })
        }
    }
}

public enum CanvasFontWeight: UInt8 {
    case ultraLight = 0
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    public var platformWeight: PlatformFont.Weight {
        switch self {
            case .ultraLight: .ultraLight
            case .thin: .thin
            case .light: .light
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            case .heavy: .heavy
            case .black: .black
        }
    }
}

// MARK: - CoreGraphics Helpers

extension CGContext {
    fileprivate func flipVertically() {
        translateBy(x: 0, y: CGFloat(height))
        scaleBy(x: 1, y: -1)
    }
}

extension CGRect {
    fileprivate func adjustForFlippedCoordinates(imageHeight: CGFloat) -> CGRect {
        .init(
            x: origin.x,
            y: imageHeight - origin.y - size.height,
            width: size.width,
            height: size.height
        )
    }
}

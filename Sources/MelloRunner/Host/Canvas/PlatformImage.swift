import CoreGraphics
import Foundation

#if canImport(UIKit)
    import UIKit

    public typealias PlatformImage = UIImage
    public typealias PlatformFont = UIFont

    extension UIImage {
        public var image: UIImage { self }
    }

#elseif canImport(AppKit)
    import AppKit

    public typealias PlatformFont = NSFont

    /// Cross-platform image wrapper on macOS providing unified access to image representations and byte buffers.
    public struct NSImageFixed: @unchecked Sendable, Hashable {
        public let image: NSImage

        public var size: CGSize {
            image.size
        }

        public init(_ image: NSImage) {
            self.image = image
        }

        public init?(data: Data) {
            guard let image = NSImage(data: data) else { return nil }
            self.image = image
        }

        public var cgImage: CGImage? {
            guard
                let data = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: data)
            else {
                return nil
            }
            return bitmap.cgImage
        }

        public func pngData() -> Data? {
            guard
                let data = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: data)
            else {
                return nil
            }
            return bitmap.representation(using: .png, properties: [:])
        }
    }

    public typealias PlatformImage = NSImageFixed
#endif

extension ResourceStore {
    /// Retrieves a `PlatformImage` from either a stored image object or stored raw image bytes.
    public func fetchImage(_ descriptor: Int32) -> PlatformImage? {
        if let image: PlatformImage = fetchObject(descriptor) {
            return image
        }
        if let data = fetch(descriptor), let image = PlatformImage(data: data) {
            return image
        }
        if let data: Data = fetchObject(descriptor), let image = PlatformImage(data: data) {
            return image
        }
        return nil
    }
}

import Foundation
import MelloRunner
import SwiftSoup
import Testing

@Suite("Real-World Asura Scans & Nano Machine Tests")
struct RealWorldNanoMachineTests {
    private func resolvePath(_ relativePath: String) -> URL {
        let candidates = [
            relativePath,
            "../" + relativePath,
            "../../" + relativePath,
        ]
        let found = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
        return URL(fileURLWithPath: found)
    }

    @Test("Parse real-world 475KB Nano Machine HTML layout")
    func parseRealWorldNanoMachineHTML() throws {
        let htmlURL = resolvePath("Reference/NanoMachine/nano-machine.html")
        guard FileManager.default.fileExists(atPath: htmlURL.path) else { return }

        let htmlString = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(htmlString.count > 100_000)

        let doc = try SwiftSoup.parse(htmlString)

        // Verify title contains Nano Machine
        let titleElement = try doc.select("h1").first()
        let titleText = try titleElement?.text() ?? ""
        #expect(titleText.localizedCaseInsensitiveContains("Nano Machine"))

        // Verify chapter links (over 300 chapters present)
        let chapterLinks = try doc.select("a[href*=/chapter/]")
        #expect(chapterLinks.size() >= 300)

        // Verify cover image present
        let coverElement = try doc.select("img[src*=covers/nano-machine]").first()
        let coverUrl = try coverElement?.attr("src")
        #expect(coverUrl != nil && !coverUrl!.isEmpty)
    }

    @Test("Parse real-world Nano Machine Chapter 1 page HTML")
    func parseRealWorldChapter1HTML() throws {
        let htmlURL = resolvePath("Reference/NanoMachine/nano-machine-chapter-1.html")
        guard FileManager.default.fileExists(atPath: htmlURL.path) else { return }

        let htmlString = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(htmlString.count > 50_000)

        let doc = try SwiftSoup.parse(htmlString)

        // Verify chapter page images or JSON state
        let html = try doc.html()
        #expect(html.contains("nano-machine/1/001.webp"))
        #expect(html.contains("chapterNumber"))
    }

    @Test("Instantiate real-world 220KB Asura Scans Wasm extension and query listings")
    func instantiateAsuraScansExtension() async throws {
        let wasmURL = resolvePath("Reference/NanoMachine/main.wasm")
        guard FileManager.default.fileExists(atPath: wasmURL.path) else { return }

        let wasmBytes = try Data(contentsOf: wasmURL)
        #expect(wasmBytes.count > 200_000)

        let bridge = try HostBridge(wasmBytes: wasmBytes)

        // Extensions require start() before other calls
        _ = try await bridge.invoke("start")

        // Query get_listings - Asura Scans defines listings statically in source.json, so Wasm returns []
        let listings = try await bridge.invokeAndDecode([Listing].self, export: "get_listings")
        #expect(listings.isEmpty)
    }
}

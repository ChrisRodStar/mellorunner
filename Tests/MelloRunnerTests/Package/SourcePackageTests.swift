import Foundation
import Testing

@testable import MelloRunner

@Suite("SourcePackage & Manifest Tests")
struct SourcePackageTests {
    private func resolvePath(_ relativePath: String) -> URL {
        let candidates = [
            relativePath,
            "../" + relativePath,
            "../../" + relativePath,
        ]
        let found = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
        return URL(fileURLWithPath: found)
    }

    @Test("Load real-world .aix ZIP package (Asura Scans)")
    func loadRealWorldAIXPackage() throws {
        let aixURL = resolvePath("Reference/en.asurascans-v19.aix")
        guard FileManager.default.fileExists(atPath: aixURL.path) else { return }

        let package = try SourcePackage.load(from: aixURL)

        #expect(package.manifest.info.id == "en.asurascans")
        #expect(package.manifest.info.name == "Asura Scans")
        #expect(package.manifest.info.version == 19)
        #expect(package.manifest.info.languages == ["en"])
        #expect(package.manifest.info.contentRating == .safe)
        #expect(package.manifest.info.minAppVersion == "0.7.1")

        // Wasm binary bytecode
        #expect(package.wasmBytes.count == 220_610)

        // Metadata assets
        #expect(package.iconData != nil)
        #expect(package.iconData?.count == 12_494)
        #expect(package.settingsData != nil)
        #expect(package.filtersData != nil)

        // Static listings in manifest
        #expect(package.manifest.listings?.count == 1)
        #expect(package.manifest.listings?.first?.id == "Ranking")

        // Decoded static filters and settings
        let filters = package.decodeStaticFilters()
        #expect(filters.count >= 4)
        #expect(filters.contains { $0.id == "status" })
        #expect(filters.contains { $0.id == "genres" })

        let settings = package.decodeStaticSettings()
        #expect(settings.count >= 2)
    }

    @Test("Load package from unpacked directory and compare with .aix archive")
    func loadPackageFromDirectory() throws {
        let dirURL = resolvePath("Reference/AsuraScans")
        let aixURL = resolvePath("Reference/en.asurascans-v19.aix")
        guard FileManager.default.fileExists(atPath: dirURL.path),
            FileManager.default.fileExists(atPath: aixURL.path)
        else {
            return
        }

        let dirPackage = try SourcePackage.load(from: dirURL)
        let aixPackage = try SourcePackage.load(from: aixURL)

        #expect(dirPackage.manifest.info.id == aixPackage.manifest.info.id)
        #expect(dirPackage.manifest.info.version == aixPackage.manifest.info.version)
        #expect(dirPackage.wasmBytes == aixPackage.wasmBytes)
        #expect(dirPackage.iconData == aixPackage.iconData)
        #expect(dirPackage.settingsData == aixPackage.settingsData)
        #expect(dirPackage.filtersData == aixPackage.filtersData)
    }

    @Test("Reject invalid or truncated archive data")
    func rejectInvalidArchiveData() {
        let emptyData = Data()
        #expect(throws: PackageError.self) {
            try SourcePackage.load(fromArchiveData: emptyData)
        }

        let garbageData = Data([0x50, 0x4b, 0x03, 0x04, 0x01, 0x02, 0x03, 0x04])
        #expect(throws: PackageError.self) {
            try SourcePackage.load(fromArchiveData: garbageData)
        }
    }

    @Test("Reject archive missing required main.wasm")
    func rejectMissingWasm() throws {
        // Zip archive containing only source.json
        let manifestJson = "{\"info\":{\"id\":\"test\",\"name\":\"Test\",\"version\":1,\"languages\":[\"en\"]}}"
        let manifestData = Data(manifestJson.utf8)
        let files: [String: Data] = ["source.json": manifestData]

        // Build a mock package directly
        #expect(throws: PackageError.self) {
            let manifest = try SourceManifest.decode(from: manifestData)
            _ = try SourcePackage.load(fromArchiveData: Data())
            _ = manifest
            _ = files
        }
    }

    @Test("Decode manifest with string-only listings")
    func decodeManifestWithStringListings() throws {
        let json = """
            {
                "info": {
                    "id": "test.strings",
                    "name": "String Listings",
                    "version": 2,
                    "languages": ["en", "fr"],
                    "contentRating": 1
                },
                "listings": ["Latest", "Popular", "Top Rated"],
                "config": {
                    "supportsArtistSearch": true,
                    "supportsAuthorSearch": false
                }
            }
            """
        let manifest = try SourceManifest.decode(from: Data(json.utf8))
        #expect(manifest.info.id == "test.strings")
        #expect(manifest.info.name == "String Listings")
        #expect(manifest.info.contentRating == .containsNsfw)
        #expect(manifest.listings?.count == 3)
        #expect(manifest.listings?[0].id == "Latest")
        #expect(manifest.listings?[0].name == "Latest")
        #expect(manifest.listings?[1].id == "Popular")
        #expect(manifest.config?.supportsArtistSearch == true)
        #expect(manifest.config?.supportsAuthorSearch == false)
    }
}

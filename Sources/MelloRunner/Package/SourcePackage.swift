import Foundation

/// Represents an immutable source extension bundle containing its manifest, WebAssembly bytecode,
/// and optional static metadata assets (icons, static filters, static settings).
public struct SourcePackage: Sendable {
    /// Parsed metadata manifest (`source.json`).
    public let manifest: SourceManifest

    /// Compiled WebAssembly executable bytecode (`main.wasm`).
    public let wasmBytes: Data

    /// Optional raw icon image bytes (`icon.png`).
    public let iconData: Data?

    /// Optional raw static settings JSON bytes (`settings.json`).
    public let settingsData: Data?

    /// Optional raw static search filters JSON bytes (`filters.json`).
    public let filtersData: Data?

    /// Original filesystem location if loaded from a file or directory.
    public let rootURL: URL?

    public init(
        manifest: SourceManifest,
        wasmBytes: Data,
        iconData: Data? = nil,
        settingsData: Data? = nil,
        filtersData: Data? = nil,
        rootURL: URL? = nil
    ) {
        self.manifest = manifest
        self.wasmBytes = wasmBytes
        self.iconData = iconData
        self.settingsData = settingsData
        self.filtersData = filtersData
        self.rootURL = rootURL
    }

    /// Loads a package from a local `.aix` archive file or an unpacked directory.
    ///
    /// - Parameter url: Filesystem URL pointing to either a `.aix` archive file or a directory.
    /// - Returns: Fully parsed `SourcePackage`.
    public static func load(from url: URL) throws(PackageError) -> SourcePackage {
        guard url.isFileURL else {
            throw PackageError.invalidURL(url.absoluteString)
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw PackageError.invalidURL("File does not exist at: \(url.path)")
        }

        if isDir.boolValue {
            return try load(fromDirectory: url)
        } else {
            do {
                let data = try Data(contentsOf: url)
                return try load(fromArchiveData: data, rootURL: url)
            } catch let error as PackageError {
                throw error
            } catch {
                throw PackageError.invalidArchive("Failed to read file at \(url.path): \(error)")
            }
        }
    }

    /// Loads a package from in-memory ZIP or `.aix` archive data.
    ///
    /// - Parameters:
    ///   - data: Raw bytes of the ZIP or `.aix` archive.
    ///   - rootURL: Optional origin URL to associate with the loaded package.
    /// - Returns: Fully parsed `SourcePackage`.
    public static func load(fromArchiveData data: Data, rootURL: URL? = nil) throws(PackageError) -> SourcePackage {
        let files = try AIXPackageReader.unpack(data: data)

        guard let manifestData = files["source.json"] else {
            throw PackageError.missingRequiredFile("source.json")
        }

        guard let wasmBytes = files["main.wasm"] else {
            throw PackageError.missingRequiredFile("main.wasm")
        }

        let manifest: SourceManifest
        do {
            manifest = try SourceManifest.decode(from: manifestData)
        } catch {
            throw PackageError.manifestDecodingFailed(String(describing: error))
        }

        return SourcePackage(
            manifest: manifest,
            wasmBytes: wasmBytes,
            iconData: files["icon.png"],
            settingsData: files["settings.json"],
            filtersData: files["filters.json"],
            rootURL: rootURL
        )
    }

    /// Loads a package from an unpacked directory containing `source.json` and `main.wasm`.
    ///
    /// - Parameter directoryURL: Filesystem URL pointing to the directory.
    /// - Returns: Fully parsed `SourcePackage`.
    public static func load(fromDirectory directoryURL: URL) throws(PackageError) -> SourcePackage {
        func resolveFile(_ name: String) -> URL? {
            let candidates = [
                directoryURL.appendingPathComponent(name),
                directoryURL.appendingPathComponent("Payload").appendingPathComponent(name),
            ]
            return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
        }

        guard let manifestURL = resolveFile("source.json") else {
            throw PackageError.missingRequiredFile("source.json at \(directoryURL.path)")
        }

        guard let wasmURL = resolveFile("main.wasm") else {
            throw PackageError.missingRequiredFile("main.wasm at \(directoryURL.path)")
        }

        let manifestData: Data
        let wasmBytes: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
            wasmBytes = try Data(contentsOf: wasmURL)
        } catch {
            throw PackageError.missingRequiredFile("Failed to read package files: \(error)")
        }

        let manifest: SourceManifest
        do {
            manifest = try SourceManifest.decode(from: manifestData)
        } catch {
            throw PackageError.manifestDecodingFailed(String(describing: error))
        }

        let iconData = resolveFile("icon.png").flatMap { try? Data(contentsOf: $0) }
        let settingsData = resolveFile("settings.json").flatMap { try? Data(contentsOf: $0) }
        let filtersData = resolveFile("filters.json").flatMap { try? Data(contentsOf: $0) }

        return SourcePackage(
            manifest: manifest,
            wasmBytes: wasmBytes,
            iconData: iconData,
            settingsData: settingsData,
            filtersData: filtersData,
            rootURL: directoryURL
        )
    }

    /// Decodes the static search filters defined in `filters.json` (if present).
    public func decodeStaticFilters() -> [Filter] {
        guard let filtersData else { return [] }
        return (try? JSONDecoder().decode([Filter].self, from: filtersData)) ?? []
    }

    /// Decodes the static in-app settings defined in `settings.json` (if present).
    public func decodeStaticSettings() -> [Setting] {
        guard let settingsData else { return [] }
        return (try? JSONDecoder().decode([Setting].self, from: settingsData)) ?? []
    }
}

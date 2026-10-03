import Foundation
import ZipMello

/// High-performance ZIP and `.aix` extension package reader powered by ZipMello.
public enum AIXPackageReader {
    /// Extracts all files contained in a ZIP or `.aix` archive payload.
    ///
    /// Path prefixes such as `Payload/` or `./Payload/` are stripped so filenames are normalized to
    /// canonical relative basenames (e.g. `main.wasm`, `source.json`, `icon.png`).
    ///
    /// - Parameter data: Raw bytes of the ZIP or `.aix` archive.
    /// - Returns: Dictionary mapping normalized file paths to uncompressed byte data.
    public static func unpack(data: Data) throws(PackageError) -> [String: Data] {
        let reader: ArchiveMemoryReader
        do {
            reader = try ArchiveMemoryReader(
                data: data,
                limits: .init(),
                tuning: .smallEntries,
                lookup: .compatible
            )
        } catch {
            throw PackageError.invalidArchive("Failed to parse archive with ZipMello: \(error)")
        }

        var results: [String: Data] = [:]
        for member in reader.listing() {
            guard !member.isDirectory else { continue }
            if member.path.contains("__MACOSX") || member.path.hasSuffix(".DS_Store") {
                continue
            }

            var normalizedName = member.path
            if normalizedName.hasPrefix("Payload/") {
                normalizedName.removeFirst("Payload/".count)
            } else if normalizedName.hasPrefix("./Payload/") {
                normalizedName.removeFirst("./Payload/".count)
            }

            do {
                let entryData = try reader.read(member.path)
                results[normalizedName] = entryData
            } catch {
                throw PackageError.decompressionFailed("\(member.path): \(error)")
            }
        }

        return results
    }
}

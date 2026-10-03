import Foundation

/// Discriminator indicating whether an identifier key refers to a Manga or a Chapter.
public enum KeyKind: Int, Sendable, Codable, CaseIterable {
    case manga = 0
    case chapter = 1
}

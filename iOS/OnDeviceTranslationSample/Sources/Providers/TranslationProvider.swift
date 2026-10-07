import Foundation

enum ProviderKind: String, CaseIterable {
    case coreML
    case apple
    case mlKit

    /// Engines shown on this device. Apple Translation is used only on iOS 26+.
    static func available(isAppleAvailable: Bool) -> [ProviderKind] {
        isAppleAvailable ? [.coreML, .apple, .mlKit] : [.coreML, .mlKit]
    }
}

enum LanguagePackStatus: Equatable {
    case installed
    case notInstalled
    case downloading
    case unsupported
    case failed(String)
}

/// A Korean-to-target translation engine. Downloading language packs is engine specific
/// and handled by `LanguagePackStore`, not by this protocol.
protocol TranslationProvider: AnyObject {
    var kind: ProviderKind { get }
    var displayName: String { get }
    func supports(_ target: TargetLanguage) -> Bool
    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus
    func translate(_ text: String, to target: TargetLanguage) async throws -> String
}

import Foundation

enum ProviderKind: String, CaseIterable {
    /// Apple Translation with the system-chosen model (iOS 26.0–26.3).
    case apple
    /// Apple Translation with the Apple Intelligence model (iOS 26.4+, `.highFidelity`).
    case appleIntelligence
    /// Apple Translation with the downloadable standard model (iOS 26.4+, `.lowLatency`).
    case appleStandard
    case mlKit

    var isApple: Bool {
        switch self {
        case .apple, .appleIntelligence, .appleStandard: return true
        case .mlKit: return false
        }
    }

    /// Engines shown on this device.
    static func available(apple: AppleTranslationSupport) -> [ProviderKind] {
        switch apple {
        case .none: return [.mlKit]
        case .basic: return [.apple, .mlKit]
        case .strategies: return [.appleIntelligence, .appleStandard, .mlKit]
        }
    }
}

/// How much of Apple's Translation framework this OS offers.
enum AppleTranslationSupport {
    /// Before iOS 26: no installed-language sessions.
    case none
    /// iOS 26.0–26.3: one system-chosen model.
    case basic
    /// iOS 26.4+: the model can be chosen per session (`TranslationSession.Strategy`).
    case strategies

    static var current: AppleTranslationSupport {
        if #available(iOS 26.4, *) { return .strategies }
        if #available(iOS 26.0, *) { return .basic }
        return .none
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

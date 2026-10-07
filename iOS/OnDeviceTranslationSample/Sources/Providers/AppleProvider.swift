import Foundation
import Translation

/// Apple's on-device Translation framework. Translation requires the language pair to be installed;
/// downloads are requested through `AppleDownloadHost`.
@available(iOS 26.0, *)
final class AppleProvider: TranslationProvider {
    /// Which Apple model to use. `highFidelity` / `lowLatency` require iOS 26.4.
    enum Mode {
        /// Let the system choose (the only option before iOS 26.4).
        case systemDefault
        /// Apple Intelligence model; no language download needed when Apple Intelligence is on.
        case highFidelity
        /// Standard downloadable model.
        case lowLatency
    }

    let mode: Mode

    static let source = Locale.Language(identifier: SourceLanguage.appleLanguageCode)

    static func language(for target: TargetLanguage) -> Locale.Language {
        Locale.Language(identifier: target.appleLanguageCode)
    }

    init(mode: Mode) {
        self.mode = mode
    }

    var kind: ProviderKind {
        switch mode {
        case .systemDefault: return .apple
        case .highFidelity: return .appleIntelligence
        case .lowLatency: return .appleStandard
        }
    }

    var displayName: String {
        switch mode {
        case .systemDefault: return "Apple Translation"
        case .highFidelity: return "Apple Intelligence"
        case .lowLatency: return "Apple 기본 모델"
        }
    }

    /// Actual support is reported by `packStatus` (`.unsupported`), not hard-coded here.
    func supports(_ target: TargetLanguage) -> Bool { true }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus {
        let status = await makeAvailability().status(from: Self.source, to: Self.language(for: target))
        switch status {
        case .installed: return .installed
        case .supported: return .notInstalled
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        try await makeSession(target: target).translate(text).targetText
    }

    /// Configuration for the download prompt in `AppleDownloadHost`.
    func downloadConfiguration(for target: TargetLanguage) -> TranslationSession.Configuration {
        if #available(iOS 26.4, *), let strategy = strategy {
            return TranslationSession.Configuration(source: Self.source, target: Self.language(for: target), preferredStrategy: strategy)
        }
        return TranslationSession.Configuration(source: Self.source, target: Self.language(for: target))
    }

    @available(iOS 26.4, *)
    private var strategy: TranslationSession.Strategy? {
        switch mode {
        case .systemDefault: return nil
        case .highFidelity: return .highFidelity
        case .lowLatency: return .lowLatency
        }
    }

    private func makeAvailability() -> LanguageAvailability {
        if #available(iOS 26.4, *), let strategy = strategy {
            return LanguageAvailability(preferredStrategy: strategy)
        }
        return LanguageAvailability()
    }

    private func makeSession(target: TargetLanguage) -> TranslationSession {
        if #available(iOS 26.4, *), let strategy = strategy {
            return TranslationSession(installedSource: Self.source, target: Self.language(for: target), preferredStrategy: strategy)
        }
        return TranslationSession(installedSource: Self.source, target: Self.language(for: target))
    }
}

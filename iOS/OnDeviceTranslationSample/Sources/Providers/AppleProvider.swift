import Foundation
import Translation

/// Apple's on-device Translation framework. Translation requires the language pair to be installed;
/// downloads are requested through `AppleDownloadHost`.
@available(iOS 26.0, *)
final class AppleProvider: TranslationProvider {
    let kind = ProviderKind.apple
    let displayName = "Apple Translation"

    static let source = Locale.Language(identifier: SourceLanguage.appleLanguageCode)

    static func language(for target: TargetLanguage) -> Locale.Language {
        Locale.Language(identifier: target.appleLanguageCode)
    }

    private let availability = LanguageAvailability()

    /// Actual support is reported by `packStatus` (`.unsupported`), not hard-coded here.
    func supports(_ target: TargetLanguage) -> Bool { true }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus {
        let status = await availability.status(from: Self.source, to: Self.language(for: target))
        switch status {
        case .installed: return .installed
        case .supported: return .notInstalled
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        let session = TranslationSession(installedSource: Self.source, target: Self.language(for: target))
        return try await session.translate(text).targetText
    }
}

import Foundation

/// What a result card shows for one engine.
enum CardState: Equatable {
    case idle
    case translating
    case unsupported
    case needsDownload
    case result(text: String, seconds: Double)
    case error(String)

    /// Card state before translating, derived from the language pack status.
    init(packStatus: LanguagePackStatus) {
        switch packStatus {
        case .installed: self = .idle
        case .unsupported: self = .unsupported
        case .notInstalled, .downloading, .failed: self = .needsDownload
        }
    }

    /// Whether a language pack status refresh may replace this state.
    /// Results and errors of a finished translation are kept.
    var isReplaceableByStatus: Bool {
        switch self {
        case .idle, .unsupported, .needsDownload: return true
        case .translating, .result, .error: return false
        }
    }
}

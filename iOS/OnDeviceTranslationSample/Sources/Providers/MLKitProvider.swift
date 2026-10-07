import Foundation
import MLKitTranslate

/// Model download/delete operations used by `LanguagePackStore` (abstracted for tests).
protocol MLKitPackManaging: AnyObject {
    func isDownloaded(_ language: PackLanguage) -> Bool
    /// Starts a download. Completion is reported through ML Kit download notifications.
    func download(_ language: PackLanguage)
    func delete(_ language: PackLanguage) async throws
}

final class MLKitProvider: TranslationProvider, MLKitPackManaging {
    let kind = ProviderKind.mlKit
    let displayName = "ML Kit"

    private let modelManager = ModelManager.modelManager()
    private let lock = NSLock()
    /// Translators are retained so in-flight translations are not deallocated.
    private var translators: [TargetLanguage: Translator] = [:]

    func supports(_ target: TargetLanguage) -> Bool { true }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus {
        isDownloaded(.korean) && isDownloaded(target.packLanguage) ? .installed : .notInstalled
    }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        let translator = translator(for: target)
        return try await withCheckedThrowingContinuation { continuation in
            translator.translate(text) { result, error in
                if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: error ?? MLKitProviderError.emptyResult)
                }
            }
        }
    }

    func isDownloaded(_ language: PackLanguage) -> Bool {
        modelManager.isModelDownloaded(Self.remoteModel(language))
    }

    func download(_ language: PackLanguage) {
        let conditions = ModelDownloadConditions(allowsCellularAccess: true, allowsBackgroundDownloading: true)
        _ = modelManager.download(Self.remoteModel(language), conditions: conditions)
    }

    func delete(_ language: PackLanguage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            modelManager.deleteDownloadedModel(Self.remoteModel(language)) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    static func remoteModel(_ language: PackLanguage) -> TranslateRemoteModel {
        TranslateRemoteModel.translateRemoteModel(language: language.mlKitLanguage)
    }

    private func translator(for target: TargetLanguage) -> Translator {
        lock.lock()
        defer { lock.unlock() }
        if let translator = translators[target] {
            return translator
        }
        let options = TranslatorOptions(sourceLanguage: .korean, targetLanguage: target.packLanguage.mlKitLanguage)
        let translator = Translator.translator(options: options)
        translators[target] = translator
        return translator
    }
}

extension PackLanguage {
    var mlKitLanguage: TranslateLanguage {
        switch self {
        case .korean: return .korean
        case .english: return .english
        case .vietnamese: return .vietnamese
        case .indonesian: return .indonesian
        case .japanese: return .japanese
        case .chineseSimplified: return .chinese
        }
    }

    init?(mlKitLanguage: TranslateLanguage) {
        guard let match = PackLanguage.allCases.first(where: { $0.mlKitLanguage == mlKitLanguage }) else {
            return nil
        }
        self = match
    }
}

enum MLKitProviderError: LocalizedError {
    case emptyResult
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .emptyResult: return "ML Kit이 빈 결과를 반환했습니다."
        case .downloadFailed: return "언어팩 다운로드에 실패했습니다."
        }
    }
}

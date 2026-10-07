import CoreML
import Foundation
import OnDeviceTranslationEngine

/// Wraps the bundled opus-mt-ko-en Core ML engine (Korean → English only).
final class CoreMLProvider: TranslationProvider {
    let kind = ProviderKind.coreML
    let displayName = "Core ML (opus-mt)"

    private let engineTask: Task<OnDeviceTranslationEngine, Error>

    init(loadEngine: @escaping () throws -> OnDeviceTranslationEngine = CoreMLProvider.loadBundledEngine) {
        // Model compilation is slow, so start loading immediately in the background.
        engineTask = Task.detached(priority: .userInitiated) { try loadEngine() }
    }

    func supports(_ target: TargetLanguage) -> Bool { target == .english }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus {
        supports(target) ? .installed : .unsupported
    }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        guard supports(target) else { throw CoreMLProviderError.unsupportedTarget }
        let engine = try await engineTask.value
        return try await Task.detached(priority: .userInitiated) { try engine.translate(text) }.value
    }

    static func loadBundledEngine() throws -> OnDeviceTranslationEngine {
        let bundle = Bundle.main
        guard let encoderURL = bundle.url(forResource: "encoder", withExtension: "mlmodelc") ?? bundle.url(forResource: "encoder", withExtension: "mlpackage"),
              let decoderURL = bundle.url(forResource: "decoder", withExtension: "mlmodelc") ?? bundle.url(forResource: "decoder", withExtension: "mlpackage"),
              let tokenizerPath = bundle.path(forResource: "source", ofType: "spm"),
              let sourceMapURL = bundle.url(forResource: "source_id_to_vocab_id", withExtension: "json"),
              let targetMapURL = bundle.url(forResource: "target_vocab_id_to_piece", withExtension: "json") else {
            throw CoreMLProviderError.missingResources
        }
        // The GPU (MPS) path fails on the decoder's dynamic shapes on iOS, so skip the GPU.
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        return try OnDeviceTranslationEngine(
            encoderModelURL: encoderURL,
            decoderModelURL: decoderURL,
            tokenizerModelPath: tokenizerPath,
            sourceMapURL: sourceMapURL,
            targetMapURL: targetMapURL,
            configuration: configuration
        )
    }
}

enum CoreMLProviderError: LocalizedError {
    case unsupportedTarget
    case missingResources

    var errorDescription: String? {
        switch self {
        case .unsupportedTarget: return "Core ML 모델은 영어만 지원합니다."
        case .missingResources: return "앱 번들에서 Core ML 모델 또는 매핑 파일을 찾을 수 없습니다."
        }
    }
}

import Foundation

/// Builds the engines for this OS version and the objects shared by the screens.
@MainActor
struct AppDependencies {
    let viewModel: ComparisonViewModel
    let packStore: LanguagePackStore
    let sampleStore: SampleTextStore

    static let sampleText = "안녕하세요. 오늘 날씨가 아주 좋네요. 만나서 반갑습니다."

    static func make() -> AppDependencies {
        let mlKit = MLKitProvider()
        let support = AppleTranslationSupport.current
        var apple: [TranslationProvider] = []
        if #available(iOS 26.0, *) {
            switch support {
            case .none: break
            case .basic: apple = [AppleProvider(mode: .systemDefault)]
            case .strategies: apple = [AppleProvider(mode: .highFidelity), AppleProvider(mode: .lowLatency)]
            }
        }

        var byKind: [ProviderKind: TranslationProvider] = [.mlKit: mlKit]
        for provider in apple {
            byKind[provider.kind] = provider
        }
        let providers = ProviderKind.available(apple: support).compactMap { byKind[$0] }

        return AppDependencies(
            viewModel: ComparisonViewModel(providers: providers, inputText: sampleText),
            packStore: LanguagePackStore(mlKit: mlKit, apple: apple),
            sampleStore: SampleTextStore()
        )
    }
}

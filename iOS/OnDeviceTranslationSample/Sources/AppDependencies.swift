import Foundation

/// Builds the engines for this OS version and the objects shared by the screens.
@MainActor
struct AppDependencies {
    let viewModel: ComparisonViewModel
    let packStore: LanguagePackStore

    static let sampleText = "안녕하세요. 오늘 날씨가 아주 좋네요. 만나서 반갑습니다."

    static func make() -> AppDependencies {
        let mlKit = MLKitProvider()
        var apple: TranslationProvider?
        if #available(iOS 26.0, *) {
            apple = AppleProvider()
        }

        var byKind: [ProviderKind: TranslationProvider] = [.coreML: CoreMLProvider(), .mlKit: mlKit]
        byKind[.apple] = apple
        let providers = ProviderKind.available(isAppleAvailable: apple != nil).compactMap { byKind[$0] }

        return AppDependencies(
            viewModel: ComparisonViewModel(providers: providers, inputText: sampleText),
            packStore: LanguagePackStore(mlKit: mlKit, apple: apple)
        )
    }
}

import SwiftUI

@main
struct OnDeviceTranslationSampleApp: App {
    @StateObject private var viewModel: ComparisonViewModel
    @StateObject private var packStore: LanguagePackStore
    @StateObject private var sampleStore: SampleTextStore

    init() {
        let dependencies = AppDependencies.make()
        _viewModel = StateObject(wrappedValue: dependencies.viewModel)
        _packStore = StateObject(wrappedValue: dependencies.packStore)
        _sampleStore = StateObject(wrappedValue: dependencies.sampleStore)
    }

    var body: some Scene {
        WindowGroup {
            ComparisonView(viewModel: viewModel, packStore: packStore, sampleStore: sampleStore)
        }
    }
}

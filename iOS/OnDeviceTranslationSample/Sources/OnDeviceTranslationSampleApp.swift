import SwiftUI

@main
struct OnDeviceTranslationSampleApp: App {
    @StateObject private var viewModel: ComparisonViewModel
    @StateObject private var packStore: LanguagePackStore

    init() {
        let dependencies = AppDependencies.make()
        _viewModel = StateObject(wrappedValue: dependencies.viewModel)
        _packStore = StateObject(wrappedValue: dependencies.packStore)
    }

    var body: some Scene {
        WindowGroup {
            ComparisonView(viewModel: viewModel, packStore: packStore)
        }
    }
}

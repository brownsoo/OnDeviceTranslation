import SwiftUI
import Translation

/// Shows Apple's language download prompt for `LanguagePackStore.appleDownloadRequest`.
/// Only one host may be active at a time: the comparison screen deactivates its host
/// while the language pack sheet (which has its own host) is presented.
struct AppleDownloadHost: ViewModifier {
    @ObservedObject var store: LanguagePackStore
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.modifier(AppleDownloadTask(store: store, isActive: isActive))
        } else {
            content
        }
    }
}

@available(iOS 26.0, *)
private struct AppleDownloadTask: ViewModifier {
    @ObservedObject var store: LanguagePackStore
    let isActive: Bool

    func body(content: Content) -> some View {
        content.translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
                await store.appleDownloadDidFinish(error: nil)
            } catch {
                await store.appleDownloadDidFinish(error: error)
            }
        }
    }

    /// A new non-nil configuration triggers the task; it returns to nil when the request finishes.
    private var configuration: TranslationSession.Configuration? {
        guard isActive, let request = store.appleDownloadRequest else { return nil }
        return TranslationSession.Configuration(source: AppleProvider.source, target: AppleProvider.language(for: request.target))
    }
}

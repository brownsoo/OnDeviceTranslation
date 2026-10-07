import SwiftUI
import Translation

/// Shows Apple's language download prompt for `LanguagePackStore.appleDownloadRequest`.
/// Each screen has its own host; only the host matching the request's origin runs it.
struct AppleDownloadHost: ViewModifier {
    @ObservedObject var store: LanguagePackStore
    let origin: AppleDownloadOrigin

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.modifier(AppleDownloadTask(store: store, origin: origin))
        } else {
            content
        }
    }
}

@available(iOS 26.0, *)
private struct AppleDownloadTask: ViewModifier {
    @ObservedObject var store: LanguagePackStore
    let origin: AppleDownloadOrigin

    func body(content: Content) -> some View {
        content.translationTask(configuration) { session in
            guard let requestID = await store.appleDownloadRequest?.id else { return }
            do {
                try await session.prepareTranslation()
                await store.appleDownloadDidFinish(requestID: requestID, error: nil)
            } catch {
                await store.appleDownloadDidFinish(requestID: requestID, error: error)
            }
        }
    }

    /// A new non-nil configuration triggers the task; it returns to nil when the request finishes.
    private var configuration: TranslationSession.Configuration? {
        guard let request = store.appleDownloadRequest, request.origin == origin else { return nil }
        return TranslationSession.Configuration(source: AppleProvider.source, target: AppleProvider.language(for: request.target))
    }
}

import Foundation
import MLKitTranslate

/// The screen whose `AppleDownloadHost` owns a request. The owner keeps running the prompt
/// even while the other screen is shown, so opening or closing the sheet never restarts it.
enum AppleDownloadOrigin: Equatable {
    case comparison
    case languagePacks
}

struct AppleDownloadRequest: Equatable {
    let id = UUID()
    /// The Apple engine (model) whose language is requested.
    let kind: ProviderKind
    let target: TargetLanguage
    let origin: AppleDownloadOrigin
}

/// Language pack status for every engine, shared by the comparison and language pack screens.
@MainActor
final class LanguagePackStore: ObservableObject {
    @Published private(set) var mlKitStatuses: [PackLanguage: LanguagePackStatus] = [:]
    @Published private(set) var appleStatuses: [ProviderKind: [TargetLanguage: LanguagePackStatus]] = [:]
    @Published private(set) var appleDownloadRequest: AppleDownloadRequest?
    @Published private(set) var appleDownloadError: String?
    /// Bumped whenever any status changes so the comparison screen can re-check its cards.
    @Published private(set) var revision = 0

    private let mlKit: MLKitPackManaging
    private let apple: [TranslationProvider]
    private var observers: [NSObjectProtocol] = []

    var isAppleAvailable: Bool { !apple.isEmpty }

    /// Apple engines in display order.
    var appleKinds: [ProviderKind] { apple.map(\.kind) }

    init(mlKit: MLKitPackManaging, apple: [TranslationProvider], notificationCenter: NotificationCenter = .default) {
        self.mlKit = mlKit
        self.apple = apple
        observers = [
            notificationCenter.addObserver(forName: .mlkitModelDownloadDidSucceed, object: nil, queue: .main) { [weak self] notification in
                let language = Self.packLanguage(from: notification)
                Task { @MainActor in self?.handleDownloadResult(language: language, error: nil) }
            },
            notificationCenter.addObserver(forName: .mlkitModelDownloadDidFail, object: nil, queue: .main) { [weak self] notification in
                let language = Self.packLanguage(from: notification)
                let error = notification.userInfo?[ModelDownloadUserInfoKey.error.rawValue] as? Error
                Task { @MainActor in self?.handleDownloadResult(language: language, error: error ?? MLKitProviderError.downloadFailed) }
            },
        ]
    }

    func mlKitStatus(_ language: PackLanguage) -> LanguagePackStatus {
        mlKitStatuses[language] ?? .notInstalled
    }

    func appleStatus(_ kind: ProviderKind, _ target: TargetLanguage) -> LanguagePackStatus {
        appleStatuses[kind]?[target] ?? .notInstalled
    }

    func appleProvider(_ kind: ProviderKind) -> TranslationProvider? {
        apple.first { $0.kind == kind }
    }

    func isDownloading(_ kind: ProviderKind, _ target: TargetLanguage) -> Bool {
        switch kind {
        case .mlKit:
            return mlKitStatus(.korean) == .downloading || mlKitStatus(target.packLanguage) == .downloading
        case .apple, .appleIntelligence, .appleStandard:
            return appleDownloadRequest?.kind == kind && appleDownloadRequest?.target == target
        case .coreML:
            return false
        }
    }

    func refresh() async {
        for language in PackLanguage.allCases {
            let current = mlKitStatus(language)
            if current == .downloading { continue }
            if mlKit.isDownloaded(language) {
                mlKitStatuses[language] = .installed
            } else if case .failed = current {
                continue // keep the failure visible until the model is actually downloaded
            } else {
                mlKitStatuses[language] = .notInstalled
            }
        }
        for provider in apple {
            for target in TargetLanguage.allCases {
                appleStatuses[provider.kind, default: [:]][target] = await provider.packStatus(for: target)
            }
        }
        revision += 1
    }

    func downloadMLKit(_ language: PackLanguage) {
        switch mlKitStatus(language) {
        case .downloading, .installed:
            return
        case .notInstalled, .unsupported, .failed:
            break
        }
        mlKitStatuses[language] = .downloading
        mlKit.download(language)
        revision += 1
    }

    func deleteMLKit(_ language: PackLanguage) async {
        do {
            try await mlKit.delete(language)
            mlKitStatuses[language] = .notInstalled
        } catch {
            mlKitStatuses[language] = .failed(error.localizedDescription)
        }
        revision += 1
    }

    /// Download request from a result card: ML Kit needs both the Korean and the target model.
    func requestDownload(_ kind: ProviderKind, for target: TargetLanguage) {
        switch kind {
        case .mlKit:
            downloadMLKit(.korean)
            downloadMLKit(target.packLanguage)
        case .apple, .appleIntelligence, .appleStandard:
            requestAppleDownload(kind, target, origin: .comparison)
        case .coreML:
            break
        }
    }

    /// Asks `AppleDownloadHost` to show the system download prompt. One request at a time.
    func requestAppleDownload(_ kind: ProviderKind, _ target: TargetLanguage, origin: AppleDownloadOrigin) {
        guard appleProvider(kind) != nil, appleDownloadRequest == nil else { return }
        appleDownloadError = nil
        appleDownloadRequest = AppleDownloadRequest(kind: kind, target: target, origin: origin)
        revision += 1
    }

    /// Completion of the prompt for `requestID`. Results for an older request are ignored, and a
    /// cancellation (the owning screen went away) clears the request without reporting an error.
    func appleDownloadDidFinish(requestID: UUID, error: Error?) async {
        guard appleDownloadRequest?.id == requestID else { return }
        appleDownloadRequest = nil
        appleDownloadError = error is CancellationError ? nil : error?.localizedDescription
        await refresh()
    }

    func handleDownloadResult(language: PackLanguage?, error: Error?) {
        guard let language = language else { return }
        if let error = error {
            mlKitStatuses[language] = .failed(error.localizedDescription)
        } else {
            mlKitStatuses[language] = .installed
        }
        revision += 1
    }

    nonisolated private static func packLanguage(from notification: Notification) -> PackLanguage? {
        guard let model = notification.userInfo?[ModelDownloadUserInfoKey.remoteModel.rawValue] as? TranslateRemoteModel else {
            return nil
        }
        return PackLanguage(mlKitLanguage: model.language)
    }
}

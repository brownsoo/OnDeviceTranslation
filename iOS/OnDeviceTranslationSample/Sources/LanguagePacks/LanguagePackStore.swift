import Foundation
import MLKitTranslate

struct AppleDownloadRequest: Equatable {
    let id = UUID()
    let target: TargetLanguage
}

/// Language pack status for every engine, shared by the comparison and language pack screens.
@MainActor
final class LanguagePackStore: ObservableObject {
    @Published private(set) var mlKitStatuses: [PackLanguage: LanguagePackStatus] = [:]
    @Published private(set) var appleStatuses: [TargetLanguage: LanguagePackStatus] = [:]
    @Published private(set) var appleDownloadRequest: AppleDownloadRequest?
    @Published private(set) var appleDownloadError: String?
    /// Bumped whenever any status changes so the comparison screen can re-check its cards.
    @Published private(set) var revision = 0

    private let mlKit: MLKitPackManaging
    private let apple: TranslationProvider?
    private var observers: [NSObjectProtocol] = []

    var isAppleAvailable: Bool { apple != nil }

    init(mlKit: MLKitPackManaging, apple: TranslationProvider?, notificationCenter: NotificationCenter = .default) {
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

    func appleStatus(_ target: TargetLanguage) -> LanguagePackStatus {
        appleStatuses[target] ?? .notInstalled
    }

    func isDownloading(_ kind: ProviderKind, _ target: TargetLanguage) -> Bool {
        switch kind {
        case .mlKit:
            return mlKitStatus(.korean) == .downloading || mlKitStatus(target.packLanguage) == .downloading
        case .apple:
            return appleDownloadRequest?.target == target
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
        if let apple = apple {
            for target in TargetLanguage.allCases {
                appleStatuses[target] = await apple.packStatus(for: target)
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
        case .apple:
            requestAppleDownload(target)
        case .coreML:
            break
        }
    }

    /// Asks `AppleDownloadHost` to show the system download prompt. One request at a time.
    func requestAppleDownload(_ target: TargetLanguage) {
        guard isAppleAvailable, appleDownloadRequest == nil else { return }
        appleDownloadError = nil
        appleDownloadRequest = AppleDownloadRequest(target: target)
        revision += 1
    }

    func appleDownloadDidFinish(error: Error?) async {
        appleDownloadRequest = nil
        appleDownloadError = error?.localizedDescription
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

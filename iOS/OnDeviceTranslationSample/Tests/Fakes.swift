import Foundation
@testable import OnDeviceTranslationSample

struct FakeError: LocalizedError {
    var errorDescription: String? { "fake failure" }
}

final class FakeProvider: TranslationProvider {
    let kind: ProviderKind
    let displayName: String
    var supportedTargets: Set<TargetLanguage>
    var status: LanguagePackStatus
    var result: Result<String, Error>
    var delayNanoseconds: UInt64
    private(set) var translateCallCount = 0
    private(set) var receivedTexts: [String] = []

    init(
        kind: ProviderKind,
        supportedTargets: Set<TargetLanguage> = Set(TargetLanguage.allCases),
        status: LanguagePackStatus = .installed,
        result: Result<String, Error> = .success("translated"),
        delayNanoseconds: UInt64 = 0
    ) {
        self.kind = kind
        self.displayName = kind.rawValue
        self.supportedTargets = supportedTargets
        self.status = status
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func supports(_ target: TargetLanguage) -> Bool { supportedTargets.contains(target) }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus { status }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        translateCallCount += 1
        receivedTexts.append(text)
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try result.get()
    }
}

/// Polls `condition` on the main actor until it is true or the timeout expires.
@MainActor
func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

final class FakeMLKitManager: MLKitPackManaging {
    var downloaded: Set<PackLanguage> = []
    var deleteError: Error?
    private(set) var downloadRequests: [PackLanguage] = []

    func isDownloaded(_ language: PackLanguage) -> Bool { downloaded.contains(language) }

    func download(_ language: PackLanguage) { downloadRequests.append(language) }

    func delete(_ language: PackLanguage) async throws {
        if let deleteError = deleteError { throw deleteError }
        downloaded.remove(language)
    }
}

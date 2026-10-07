import XCTest
import MLKitTranslate
@testable import OnDeviceTranslationSample

@MainActor
final class LanguagePackStoreTests: XCTestCase {
    private var mlKit: FakeMLKitManager!
    private var center: NotificationCenter!

    override func setUp() {
        super.setUp()
        mlKit = FakeMLKitManager()
        center = NotificationCenter()
    }

    private func makeStore(apple: TranslationProvider? = nil) -> LanguagePackStore {
        LanguagePackStore(mlKit: mlKit, apple: apple, notificationCenter: center)
    }

    func test_refresh_readsMLKitModels() async {
        mlKit.downloaded = [.korean, .english]
        let store = makeStore()

        await store.refresh()

        XCTAssertEqual(store.mlKitStatus(.korean), .installed)
        XCTAssertEqual(store.mlKitStatus(.english), .installed)
        XCTAssertEqual(store.mlKitStatus(.japanese), .notInstalled)
        XCTAssertFalse(store.isAppleAvailable)
    }

    func test_requestDownload_skipsInstalledAndInFlight() async {
        mlKit.downloaded = [.korean]
        let store = makeStore()
        await store.refresh()

        store.requestDownload(.mlKit, for: .japanese)
        store.requestDownload(.mlKit, for: .japanese)

        XCTAssertEqual(mlKit.downloadRequests, [.japanese])
        XCTAssertEqual(store.mlKitStatus(.japanese), .downloading)
        XCTAssertTrue(store.isDownloading(.mlKit, .japanese))
    }

    func test_handleDownloadResult_marksInstalledOrFailed() async {
        let store = makeStore()
        await store.refresh()
        store.downloadMLKit(.japanese)
        store.downloadMLKit(.vietnamese)

        store.handleDownloadResult(language: .japanese, error: nil)
        store.handleDownloadResult(language: .vietnamese, error: FakeError())

        XCTAssertEqual(store.mlKitStatus(.japanese), .installed)
        XCTAssertEqual(store.mlKitStatus(.vietnamese), .failed("fake failure"))
    }

    func test_refresh_keepsFailureUntilDownloaded() async {
        let store = makeStore()
        store.downloadMLKit(.vietnamese)
        store.handleDownloadResult(language: .vietnamese, error: FakeError())

        await store.refresh()
        XCTAssertEqual(store.mlKitStatus(.vietnamese), .failed("fake failure"))

        mlKit.downloaded = [.vietnamese]
        await store.refresh()
        XCTAssertEqual(store.mlKitStatus(.vietnamese), .installed)
    }

    func test_downloadNotification_updatesStatus() async {
        let store = makeStore()
        store.downloadMLKit(.japanese)

        center.post(name: .mlkitModelDownloadDidSucceed, object: nil,
                    userInfo: [ModelDownloadUserInfoKey.remoteModel.rawValue: MLKitProvider.remoteModel(.japanese)])
        await waitUntil { store.mlKitStatus(.japanese) == .installed }

        XCTAssertEqual(store.mlKitStatus(.japanese), .installed)
    }

    func test_deleteMLKit_successAndFailure() async {
        mlKit.downloaded = [.japanese, .english]
        let store = makeStore()
        await store.refresh()

        await store.deleteMLKit(.japanese)
        XCTAssertEqual(store.mlKitStatus(.japanese), .notInstalled)

        mlKit.deleteError = FakeError()
        await store.deleteMLKit(.english)
        XCTAssertEqual(store.mlKitStatus(.english), .failed("fake failure"))
    }

    func test_appleDownloadRequest_isSingleAndClearedOnFinish() async {
        let apple = FakeProvider(kind: .apple, status: .notInstalled)
        let store = makeStore(apple: apple)
        await store.refresh()
        XCTAssertTrue(store.isAppleAvailable)
        XCTAssertEqual(store.appleStatus(.japanese), .notInstalled)

        store.requestDownload(.apple, for: .japanese)
        store.requestAppleDownload(.vietnamese)
        XCTAssertEqual(store.appleDownloadRequest?.target, .japanese)
        XCTAssertTrue(store.isDownloading(.apple, .japanese))

        apple.status = .installed
        await store.appleDownloadDidFinish(error: nil)
        XCTAssertNil(store.appleDownloadRequest)
        XCTAssertNil(store.appleDownloadError)
        XCTAssertEqual(store.appleStatus(.japanese), .installed)
    }

    func test_appleDownloadFailure_isReported() async {
        let store = makeStore(apple: FakeProvider(kind: .apple, status: .notInstalled))
        store.requestAppleDownload(.japanese)

        await store.appleDownloadDidFinish(error: FakeError())

        XCTAssertNil(store.appleDownloadRequest)
        XCTAssertEqual(store.appleDownloadError, "fake failure")
    }
}

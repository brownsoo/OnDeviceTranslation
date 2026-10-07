import XCTest
@testable import OnDeviceTranslationSample

final class ProviderTests: XCTestCase {
    func test_availableKinds_dependOnAppleTranslationSupport() {
        XCTAssertEqual(ProviderKind.available(apple: .strategies), [.coreML, .appleIntelligence, .appleStandard, .mlKit])
        XCTAssertEqual(ProviderKind.available(apple: .basic), [.coreML, .apple, .mlKit])
        XCTAssertEqual(ProviderKind.available(apple: .none), [.coreML, .mlKit])
    }

    func test_appleKinds() {
        XCTAssertEqual(ProviderKind.allCases.filter(\.isApple), [.apple, .appleIntelligence, .appleStandard])
    }

    func test_appleProvider_kindAndNamePerMode() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Apple Translation requires iOS 26") }
        XCTAssertEqual(AppleProvider(mode: .systemDefault).kind, .apple)
        XCTAssertEqual(AppleProvider(mode: .highFidelity).kind, .appleIntelligence)
        XCTAssertEqual(AppleProvider(mode: .lowLatency).kind, .appleStandard)
        XCTAssertEqual(AppleProvider(mode: .highFidelity).displayName, "Apple Intelligence")
        XCTAssertEqual(AppleProvider(mode: .lowLatency).displayName, "Apple 기본 모델")
    }

    func test_coreML_supportsEnglishOnly() async {
        let provider = CoreMLProvider(loadEngine: { throw FakeError() })

        XCTAssertTrue(provider.supports(.english))
        for target in TargetLanguage.allCases where target != .english {
            XCTAssertFalse(provider.supports(target))
            let status = await provider.packStatus(for: target)
            XCTAssertEqual(status, .unsupported)
        }
        let englishStatus = await provider.packStatus(for: .english)
        XCTAssertEqual(englishStatus, .installed)
    }

    func test_coreML_translateSurfacesEngineLoadFailure() async {
        let provider = CoreMLProvider(loadEngine: { throw FakeError() })

        do {
            _ = try await provider.translate("안녕하세요.", to: .english)
            XCTFail("Expected load failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "fake failure")
        }
    }

    func test_coreML_translatesWithBundledModels() async throws {
        let provider = CoreMLProvider()

        let result = try await provider.translate("안녕하세요.", to: .english)

        XCTAssertTrue(result.lowercased().contains("hello") || result.lowercased().contains("hi"), result)
    }
}

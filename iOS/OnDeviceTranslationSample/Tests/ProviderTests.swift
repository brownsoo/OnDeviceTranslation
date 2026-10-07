import XCTest
@testable import OnDeviceTranslationSample

final class ProviderTests: XCTestCase {
    func test_availableKinds_dependOnAppleAvailability() {
        XCTAssertEqual(ProviderKind.available(isAppleAvailable: true), [.coreML, .apple, .mlKit])
        XCTAssertEqual(ProviderKind.available(isAppleAvailable: false), [.coreML, .mlKit])
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

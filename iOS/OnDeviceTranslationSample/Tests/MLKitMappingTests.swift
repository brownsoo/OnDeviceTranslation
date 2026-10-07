import XCTest
import MLKitTranslate
@testable import OnDeviceTranslationSample

final class MLKitMappingTests: XCTestCase {
    func test_packLanguages_mapToMLKitLanguages() {
        XCTAssertEqual(PackLanguage.allCases.map(\.mlKitLanguage),
                       [.korean, .english, .vietnamese, .indonesian, .japanese, .chinese])
    }

    func test_mlKitLanguage_roundTrips() {
        for language in PackLanguage.allCases {
            XCTAssertEqual(PackLanguage(mlKitLanguage: language.mlKitLanguage), language)
        }
        XCTAssertNil(PackLanguage(mlKitLanguage: .german))
    }

    func test_remoteModel_usesMappedLanguage() {
        XCTAssertEqual(MLKitProvider.remoteModel(.japanese).language, .japanese)
    }

    func test_mlKit_supportsAllTargets() {
        let provider = MLKitProvider()
        XCTAssertTrue(TargetLanguage.allCases.allSatisfy(provider.supports))
    }

    func test_appleLanguages() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Apple Translation requires iOS 26") }
        XCTAssertEqual(AppleProvider.source.languageCode?.identifier, "ko")
        let chinese = AppleProvider.language(for: .chineseSimplified)
        XCTAssertEqual(chinese.languageCode?.identifier, "zh")
        XCTAssertEqual(chinese.script?.identifier, "Hans")
        XCTAssertEqual(AppleProvider.language(for: .vietnamese).languageCode?.identifier, "vi")
    }
}

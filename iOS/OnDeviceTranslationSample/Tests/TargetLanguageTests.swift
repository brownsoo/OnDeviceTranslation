import XCTest
@testable import OnDeviceTranslationSample

final class TargetLanguageTests: XCTestCase {
    func test_targetLanguages_areTheFiveRequestedInOrder() {
        XCTAssertEqual(TargetLanguage.allCases, [.english, .vietnamese, .indonesian, .japanese, .chineseSimplified])
        XCTAssertEqual(TargetLanguage.allCases.map(\.shortLabel), ["EN", "VI", "ID", "JA", "ZH"])
    }

    func test_appleLanguageCodes() {
        XCTAssertEqual(SourceLanguage.appleLanguageCode, "ko")
        XCTAssertEqual(TargetLanguage.allCases.map(\.appleLanguageCode), ["en", "vi", "id", "ja", "zh-Hans"])
    }

    func test_packLanguages_startWithKoreanSourceAndMapBackToTargets() {
        XCTAssertEqual(PackLanguage.allCases.first, .korean)
        XCTAssertNil(PackLanguage.korean.targetLanguage)
        for target in TargetLanguage.allCases {
            XCTAssertEqual(target.packLanguage.targetLanguage, target)
            XCTAssertEqual(target.displayName, target.packLanguage.displayName)
        }
    }
}

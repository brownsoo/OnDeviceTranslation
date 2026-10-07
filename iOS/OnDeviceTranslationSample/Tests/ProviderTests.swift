import XCTest
@testable import OnDeviceTranslationSample

final class ProviderTests: XCTestCase {
    func test_availableKinds_dependOnAppleTranslationSupport() {
        XCTAssertEqual(ProviderKind.available(apple: .strategies), [.appleIntelligence, .appleStandard, .mlKit])
        XCTAssertEqual(ProviderKind.available(apple: .basic), [.apple, .mlKit])
        XCTAssertEqual(ProviderKind.available(apple: .none), [.mlKit])
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
}

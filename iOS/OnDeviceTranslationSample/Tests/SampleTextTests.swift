import XCTest
@testable import OnDeviceTranslationSample

final class SampleTextsTests: XCTestCase {
    func test_defaults_haveTwoSamplesPerCategory() {
        for category in SampleCategory.allCases {
            XCTAssertEqual(SampleTexts.defaults.filter { $0.category == category }.count, 2, "\(category)")
        }
        XCTAssertEqual(SampleCategory.allCases.map(\.displayName), ["가정통신문", "급식", "학교공지"])
    }

    func test_defaults_haveUniqueIDsAndNonEmptyText() {
        let ids = SampleTexts.defaults.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for sample in SampleTexts.defaults {
            XCTAssertFalse(sample.title.isEmpty, sample.id)
            XCTAssertFalse(sample.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, sample.id)
        }
    }

    func test_defaults_containNoLinksOrPhoneNumbers() {
        let phone = try! NSRegularExpression(pattern: #"\d{2,4}[)-]\d{3,4}-\d{4}"#)
        for sample in SampleTexts.defaults {
            XCTAssertFalse(sample.body.contains("http"), sample.id)
            XCTAssertFalse(sample.body.contains("www."), sample.id)
            let range = NSRange(sample.body.startIndex..., in: sample.body)
            XCTAssertNil(phone.firstMatch(in: sample.body, range: range), sample.id)
        }
    }
}

@MainActor
final class SampleTextStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SampleTextStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let defaultSamples = [
        SampleText(id: "a", category: .homeLetter, title: "A", body: "기본 A"),
        SampleText(id: "b", category: .meal, title: "B", body: "기본 B"),
    ]

    private func makeStore() -> SampleTextStore {
        SampleTextStore(userDefaults: userDefaults, defaultSamples: defaultSamples)
    }

    func test_startsWithDefaults() {
        let store = makeStore()

        XCTAssertEqual(store.samples, defaultSamples)
        XCTAssertEqual(store.samples(in: .meal).map(\.id), ["b"])
        XCTAssertFalse(store.isEdited("a"))
    }

    func test_savedBody_persistsAcrossStores() {
        makeStore().save(body: "고친 A", for: "a")

        let reloaded = makeStore()

        XCTAssertEqual(reloaded.sample(id: "a")?.body, "고친 A")
        XCTAssertTrue(reloaded.isEdited("a"))
        XCTAssertEqual(reloaded.sample(id: "b")?.body, "기본 B")
        XCTAssertFalse(reloaded.isEdited("b"))
    }

    func test_resetToDefault_restoresAndForgetsEdit() {
        let store = makeStore()
        store.save(body: "고친 A", for: "a")

        store.resetToDefault("a")

        XCTAssertEqual(store.sample(id: "a")?.body, "기본 A")
        XCTAssertFalse(store.isEdited("a"))
        XCTAssertFalse(makeStore().isEdited("a"))
    }

    func test_savingDefaultBody_isNotAnEdit() {
        let store = makeStore()
        store.save(body: "고친 A", for: "a")

        store.save(body: "기본 A", for: "a")

        XCTAssertFalse(store.isEdited("a"))
    }

    func test_editForUnknownID_isIgnored() {
        userDefaults.set(["gone": "옛 예시"], forKey: SampleTextStore.editsKey)

        let store = makeStore()

        XCTAssertEqual(store.samples, defaultSamples)
    }
}

@MainActor
final class ComparisonViewModelSampleTests: XCTestCase {
    func test_loadSample_fillsInput() {
        let viewModel = ComparisonViewModel(providers: [], inputText: "이전 입력")

        viewModel.loadSample(SampleText(id: "a", category: .meal, title: "A", body: "오늘의 급식"))

        XCTAssertEqual(viewModel.inputText, "오늘의 급식")
    }
}

import XCTest
@testable import OnDeviceTranslationSample

@MainActor
final class ComparisonViewModelTests: XCTestCase {
    private func resultText(_ state: CardState) -> String? {
        if case let .result(text, _) = state { return text }
        return nil
    }

    func test_cardState_fromPackStatus() {
        XCTAssertEqual(CardState(packStatus: .installed), .idle)
        XCTAssertEqual(CardState(packStatus: .unsupported), .unsupported)
        XCTAssertEqual(CardState(packStatus: .notInstalled), .needsDownload)
        XCTAssertEqual(CardState(packStatus: .downloading), .needsDownload)
        XCTAssertEqual(CardState(packStatus: .failed("x")), .needsDownload)
    }

    func test_translate_fillsResultForEachProvider() async {
        let apple = FakeProvider(kind: .apple, result: .success("A"))
        let mlKit = FakeProvider(kind: .mlKit, result: .success("B"))
        let viewModel = ComparisonViewModel(providers: [apple, mlKit], inputText: "안녕하세요")

        await viewModel.translate()?.value

        XCTAssertEqual(resultText(viewModel.state(for: .apple)), "A")
        XCTAssertEqual(resultText(viewModel.state(for: .mlKit)), "B")
    }

    func test_translate_marksUnsupportedWithoutCallingProvider() async {
        let apple = FakeProvider(kind: .apple, supportedTargets: [.english])
        let viewModel = ComparisonViewModel(providers: [apple], inputText: "안녕하세요")
        await viewModel.select(.japanese).value

        await viewModel.translate()?.value

        XCTAssertEqual(viewModel.state(for: .apple), .unsupported)
        XCTAssertEqual(apple.translateCallCount, 0)
    }

    func test_translate_needsDownloadWhenPackMissing() async {
        let mlKit = FakeProvider(kind: .mlKit, status: .notInstalled)
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")

        await viewModel.translate()?.value

        XCTAssertEqual(viewModel.state(for: .mlKit), .needsDownload)
        XCTAssertEqual(mlKit.translateCallCount, 0)
    }

    func test_translate_oneFailureDoesNotAffectOthers() async {
        let apple = FakeProvider(kind: .apple, result: .failure(FakeError()))
        let mlKit = FakeProvider(kind: .mlKit, result: .success("B"))
        let viewModel = ComparisonViewModel(providers: [apple, mlKit], inputText: "안녕하세요")

        await viewModel.translate()?.value

        XCTAssertEqual(viewModel.state(for: .apple), .error("fake failure"))
        XCTAssertEqual(resultText(viewModel.state(for: .mlKit)), "B")
    }

    func test_translate_whitespaceOnlyInput_doesNothing() {
        let apple = FakeProvider(kind: .apple)
        let viewModel = ComparisonViewModel(providers: [apple], inputText: "  \n\t ")

        XCTAssertFalse(viewModel.canTranslate)
        XCTAssertNil(viewModel.translate())
        XCTAssertEqual(apple.translateCallCount, 0)
        XCTAssertEqual(viewModel.state(for: .apple), .idle)
    }

    func test_selectDuringTranslation_discardsStaleResult() async {
        let mlKit = FakeProvider(kind: .mlKit, result: .success("stale"), delayNanoseconds: 300_000_000)
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")

        let translation = viewModel.translate()
        await waitUntil { viewModel.state(for: .mlKit) == .translating }
        await viewModel.select(.japanese).value
        await translation?.value

        XCTAssertEqual(viewModel.target, .japanese)
        XCTAssertEqual(viewModel.state(for: .mlKit), .idle)
    }

    func test_refreshStatuses_keepsFinishedResult() async {
        let mlKit = FakeProvider(kind: .mlKit, result: .success("B"))
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")
        await viewModel.translate()?.value

        mlKit.status = .notInstalled
        await viewModel.refreshStatuses()

        XCTAssertEqual(resultText(viewModel.state(for: .mlKit)), "B")
    }

    func test_refreshStatuses_updatesNeedsDownloadAfterInstall() async {
        let mlKit = FakeProvider(kind: .mlKit, status: .notInstalled)
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")

        await viewModel.refreshStatuses()
        XCTAssertEqual(viewModel.state(for: .mlKit), .needsDownload)

        mlKit.status = .installed
        await viewModel.refreshStatuses()
        XCTAssertEqual(viewModel.state(for: .mlKit), .idle)
    }
}

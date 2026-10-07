import XCTest
@testable import OnDeviceTranslationSample

final class TranslationPreprocessorTests: XCTestCase {
    func test_normalize_replacesKoreanListMarkersAtLineStart() {
        let text = "안내입니다.\n\n가. 행사명: 테스트\n나. 일시: 내일\n다. 장소: 강당\n하. 기타"

        XCTAssertEqual(TranslationPreprocessor.normalize(text),
                       "안내입니다.\n\nA. 행사명: 테스트\nB. 일시: 내일\nC. 장소: 강당\nN. 기타")
    }

    func test_normalize_keepsMarkerLikeTextInsideSentences() {
        let text = "참가 신청은 가. 나. 순서로 받습니다."

        XCTAssertEqual(TranslationPreprocessor.normalize(text), text)
    }

    func test_normalize_expandsWeekdayAbbreviations() {
        let text = "2026. 10. 1.(목) ~ 2026. 10. 7.(수), 10. 9.(금) (토) (일) (월) (화)"

        XCTAssertEqual(TranslationPreprocessor.normalize(text),
                       "2026. 10. 1.(목요일) ~ 2026. 10. 7.(수요일), 10. 9.(금요일) (토요일) (일요일) (월요일) (화요일)")
    }

    func test_segments_replaceAllergyLegendWithFixedText() {
        let text = """
        문어톳밥
        사과 (13)

        알레르기 정보
        1.난류 2.우유 3.메밀 4.땅콩 5.대두 6.밀 7.고등어 8.게 9.새우 10.돼지고기 11.복숭아 12.토마토 13.아황산류 14.호두 15.닭고기 16.쇠고기 17.오징어 18.조개류(굴,전복,홍합 포함) 19.잣

        ※ 식단은 학교 사정에 의해서 변경될 수 있습니다.
        """

        XCTAssertEqual(TranslationPreprocessor.segments(text, target: .english), [
            .translate("문어톳밥\n사과 (13)"),
            .fixed(AllergyLegend.text(for: .english)),
            .translate("※ 식단은 학교 사정에 의해서 변경될 수 있습니다."),
        ])
    }

    func test_segments_withoutLegend_isOneNormalizedSegment() {
        XCTAssertEqual(TranslationPreprocessor.segments("가. 일시: 10. 9.(금)", target: .japanese),
                       [.translate("A. 일시: 10. 9.(금요일)")])
    }

    func test_segments_legendWithoutHeaderOrTrailingText() {
        let text = "사과 (13)\n1. 난류 2.우유 19.잣"

        XCTAssertEqual(TranslationPreprocessor.segments(text, target: .vietnamese), [
            .translate("사과 (13)"),
            .fixed(AllergyLegend.text(for: .vietnamese)),
        ])
    }

    func test_join_separatesPartsWithBlankLine() {
        XCTAssertEqual(TranslationPreprocessor.join(["A", "B", "C"]), "A\n\nB\n\nC")
    }

    func test_allergyLegends_listAllNineteenItemsInEveryLanguage() {
        for target in TargetLanguage.allCases {
            let legend = AllergyLegend.text(for: target)
            for number in 1...19 {
                XCTAssertTrue(legend.contains("\(number)."), "\(target) is missing item \(number)")
            }
        }
        XCTAssertTrue(AllergyLegend.text(for: .english).contains("1.Eggs"))
    }
}

@MainActor
final class ComparisonViewModelPreprocessingTests: XCTestCase {
    private let mealText = "사과 (13)\n\n알레르기 정보\n1.난류 2.우유 19.잣\n\n※ 식단은 변경될 수 있습니다."

    func test_translate_withPreprocessing_translatesPartsAndInsertsLegend() async {
        let provider = FakeProvider(kind: .mlKit, result: .success("T"))
        let viewModel = ComparisonViewModel(providers: [provider], inputText: mealText)

        await viewModel.translate()?.value

        XCTAssertEqual(provider.receivedTexts, ["사과 (13)", "※ 식단은 변경될 수 있습니다."])
        guard case let .result(text, _) = viewModel.state(for: .mlKit) else { return XCTFail("no result") }
        XCTAssertEqual(text, "T\n\n" + AllergyLegend.text(for: .english) + "\n\nT")
    }

    func test_translate_withoutPreprocessing_sendsOriginalText() async {
        let provider = FakeProvider(kind: .mlKit, result: .success("T"))
        let viewModel = ComparisonViewModel(providers: [provider], inputText: mealText)
        viewModel.usesPreprocessing = false

        await viewModel.translate()?.value

        XCTAssertEqual(provider.receivedTexts, [mealText])
        guard case let .result(text, _) = viewModel.state(for: .mlKit) else { return XCTFail("no result") }
        XCTAssertEqual(text, "T")
    }

    func test_preprocessing_isOnByDefault() {
        XCTAssertTrue(ComparisonViewModel(providers: []).usesPreprocessing)
    }
}

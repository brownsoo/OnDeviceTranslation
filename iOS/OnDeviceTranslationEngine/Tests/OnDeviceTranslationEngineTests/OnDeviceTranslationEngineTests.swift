import XCTest
@testable import OnDeviceTranslationEngine

final class OnDeviceTranslationEngineTests: XCTestCase {
    private let basePath = "/Users/brownsoo/Workspace/OnDeviceTranslation"

    func testDecodeSkipsPadToken() throws {
        let tokenizer = try SentencePieceTokenizer(
            modelPath: "\(basePath)/tokenizer_files/source.spm",
            sourceMapURL: URL(fileURLWithPath: "\(basePath)/models/source_id_to_vocab_id.json"),
            targetMapURL: URL(fileURLWithPath: "\(basePath)/models/target_vocab_id_to_piece.json")
        )

        // Marian decoder output starts with the PAD token (65000 in opus-mt-ko-en) and ends with EOS (0).
        // 3306 = "▁Hello"
        let decoded = tokenizer.decode(tokenIds: [65000, 3306, 0])

        XCTAssertEqual(decoded, "Hello")
    }

    func testTranslation() throws {
        let encoderURL = URL(fileURLWithPath: "\(basePath)/models/encoder.mlpackage")
        let decoderURL = URL(fileURLWithPath: "\(basePath)/models/decoder.mlpackage")
        let sourceMapURL = URL(fileURLWithPath: "\(basePath)/models/source_id_to_vocab_id.json")
        let targetMapURL = URL(fileURLWithPath: "\(basePath)/models/target_vocab_id_to_piece.json")
        let tokenizerPath = "\(basePath)/tokenizer_files/source.spm"
        
        let engine = try OnDeviceTranslationEngine(
            encoderModelURL: encoderURL,
            decoderModelURL: decoderURL,
            tokenizerModelPath: tokenizerPath,
            sourceMapURL: sourceMapURL,
            targetMapURL: targetMapURL
        )
        
        let inputText = "안녕하세요. 오늘 날씨가 아주 좋네요."
        let translation = try engine.translate(inputText)
        
        print("\n==============================")
        print("Input: \(inputText)")
        print("Translation: \(translation)")
        print("==============================\n")
        
        XCTAssertFalse(translation.isEmpty)
        XCTAssertTrue(translation.lowercased().contains("hello") || translation.lowercased().contains("lovely") || translation.lowercased().contains("nice"))
    }
}

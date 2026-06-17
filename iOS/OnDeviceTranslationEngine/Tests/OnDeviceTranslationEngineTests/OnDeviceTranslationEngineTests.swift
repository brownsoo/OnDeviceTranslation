import XCTest
@testable import OnDeviceTranslationEngine

final class OnDeviceTranslationEngineTests: XCTestCase {
    func testTranslation() throws {
        let basePath = "/Users/brownsoo/Workspace/OnDeviceTranslation"
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

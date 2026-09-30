import Foundation
import SentencepieceTokenizer

public class SentencePieceTokenizer {
    private let tokenizer: SentencepieceTokenizer
    private let sourceIdToVocabId: [Int]
    private let targetVocabIdToPiece: [String]
    private let unkTokenId: Int
    let padTokenId: Int
    let eosTokenId: Int
    
    public init(
        modelPath: String, 
        sourceMapURL: URL, 
        targetMapURL: URL, 
        unkTokenId: Int = 1, 
        padTokenId: Int = 65000, 
        eosTokenId: Int = 0
    ) throws {
        self.tokenizer = try SentencepieceTokenizer(modelPath: modelPath, tokenOffset: 0)
        
        let sourceMapData = try Data(contentsOf: sourceMapURL)
        self.sourceIdToVocabId = try JSONDecoder().decode([Int].self, from: sourceMapData)
        
        let targetMapData = try Data(contentsOf: targetMapURL)
        self.targetVocabIdToPiece = try JSONDecoder().decode([String].self, from: targetMapData)
        
        self.unkTokenId = unkTokenId
        self.padTokenId = padTokenId
        self.eosTokenId = eosTokenId
    }
    
    /// Encodes Korean source text to CoreML vocabulary input IDs and attention mask.
    public func encode(text: String) throws -> (inputIds: [Int32], attentionMask: [Int32]) {
        let rawIds = try tokenizer.encode(text)
        
        // Map raw SP IDs to Model Vocabulary IDs
        var vocabIds = rawIds.map { rawId -> Int32 in
            if rawId >= 0 && rawId < sourceIdToVocabId.count {
                return Int32(sourceIdToVocabId[rawId])
            }
            return Int32(unkTokenId)
        }
        
        // Append EOS token
        vocabIds.append(Int32(eosTokenId))
        
        // Attention mask is 1s for all inputs
        let attentionMask = Array(repeating: Int32(1), count: vocabIds.count)
        
        return (vocabIds, attentionMask)
    }
    
    /// Decodes predicted vocabulary token IDs from CoreML Decoder to English text.
    public func decode(tokenIds: [Int]) -> String {
        var pieces: [String] = []
        for id in tokenIds {
            if id == padTokenId || id == eosTokenId {
                continue
            }
            if id >= 0 && id < targetVocabIdToPiece.count {
                pieces.append(targetVocabIdToPiece[id])
            }
        }
        
        let joined = pieces.joined()
        // Replace U+2581 (Lower one-eighth block) with a standard space
        let decoded = joined.replacingOccurrences(of: "\u{2581}", with: " ")
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation
import CoreML

public class OnDeviceTranslationEngine {
    private let encoderModel: MLModel
    private let decoderModel: MLModel
    private let tokenizer: SentencePieceTokenizer
    
    private let encoderOutputKey = "var_444"
    private let decoderOutputKey = "var_862"
    
    public init(
        encoderModelURL: URL, 
        decoderModelURL: URL, 
        tokenizerModelPath: String, 
        sourceMapURL: URL, 
        targetMapURL: URL
    ) throws {
        // Compile models dynamically if they are not already compiled (i.e. if they are .mlpackage or .mlmodel)
        let compiledEncoderURL = try Self.compileIfNeeded(at: encoderModelURL)
        let compiledDecoderURL = try Self.compileIfNeeded(at: decoderModelURL)
        
        self.encoderModel = try MLModel(contentsOf: compiledEncoderURL)
        self.decoderModel = try MLModel(contentsOf: compiledDecoderURL)
        
        self.tokenizer = try SentencePieceTokenizer(
            modelPath: tokenizerModelPath, 
            sourceMapURL: sourceMapURL, 
            targetMapURL: targetMapURL
        )
    }
    
    private static func compileIfNeeded(at url: URL) throws -> URL {
        if url.pathExtension == "mlmodelc" {
            return url
        }
        print("Compiling CoreML model at \(url.lastPathComponent)...")
        return try MLModel.compileModel(at: url)
    }
    
    public func translate(_ text: String, maxLength: Int = 50) throws -> String {
        // 1. Tokenize input text to get vocab IDs and attention mask
        let (inputIds, attentionMask) = try tokenizer.encode(text: text)
        
        // Convert to MLMultiArray
        let inputIdsMultiArray = try toMultiArray(inputIds)
        let attentionMaskMultiArray = try toMultiArray(attentionMask)
        
        // 2. Run Encoder
        let encoderInputs = CustomMLFeatureProvider(features: [
            "input_ids": MLFeatureValue(multiArray: inputIdsMultiArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskMultiArray)
        ])
        
        let encoderOutputs = try encoderModel.prediction(from: encoderInputs)
        guard let encoderHiddenStates = encoderOutputs.featureValue(for: encoderOutputKey)?.multiArrayValue else {
            throw NSError(domain: "OnDeviceTranslation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get encoder hidden states"])
        }
        
        // 3. Decoder Loop (Greedy Search)
        // Marian uses the PAD token as decoder_start_token_id
        let padTokenId = Int32(tokenizer.padTokenId)
        let eosTokenId = Int32(tokenizer.eosTokenId)
        var decIds = [padTokenId]
        
        for _ in 0..<maxLength {
            let decInputMultiArray = try toMultiArray(decIds)
            
            // Run Decoder
            let decoderInputs = CustomMLFeatureProvider(features: [
                "decoder_input_ids": MLFeatureValue(multiArray: decInputMultiArray),
                "encoder_hidden_states": MLFeatureValue(multiArray: encoderHiddenStates),
                "encoder_attention_mask": MLFeatureValue(multiArray: attentionMaskMultiArray)
            ])
            
            let decoderOutputs = try decoderModel.prediction(from: decoderInputs)
            guard let logits = decoderOutputs.featureValue(for: decoderOutputKey)?.multiArrayValue else {
                throw NSError(domain: "OnDeviceTranslation", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get decoder logits"])
            }
            
            // ArgMax to find the next token (PAD is never generated, matching bad_words_ids in the HF config)
            let nextToken = argmax(logits, excluding: padTokenId)
            decIds.append(Int32(nextToken))
            
            if nextToken == eosTokenId {
                break
            }
        }
        
        // 4. Decode generated tokens to string
        let tokenIds = decIds.map { Int($0) }
        return tokenizer.decode(tokenIds: tokenIds)
    }
    
    private func toMultiArray(_ array: [Int32]) throws -> MLMultiArray {
        let shape = [1, NSNumber(value: array.count)]
        let multiArray = try MLMultiArray(shape: shape, dataType: .int32)
        for i in 0..<array.count {
            multiArray[[0, i] as [NSNumber]] = NSNumber(value: array[i])
        }
        return multiArray
    }
    
    private func argmax(_ multiArray: MLMultiArray, excluding excludedIndex: Int32) -> Int32 {
        let count = multiArray.count
        var maxVal: Float = -Float.greatestFiniteMagnitude
        var maxIndex: Int32 = 0
        
        for i in 0..<count where i != Int(excludedIndex) {
            let val = multiArray[i].floatValue
            if val > maxVal {
                maxVal = val
                maxIndex = Int32(i)
            }
        }
        return maxIndex
    }
}

// Helper class to dynamically pass features to MLModel
class CustomMLFeatureProvider: MLFeatureProvider {
    let features: [String: MLFeatureValue]
    var featureNames: Set<String> {
        return Set(features.keys)
    }
    
    init(features: [String: MLFeatureValue]) {
        self.features = features
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return features[featureName]
    }
}

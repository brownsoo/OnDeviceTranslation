import os
import torch
import numpy as np
import coremltools as ct
from transformers import MarianTokenizer

def main():
    tokenizer_dir = "./tokenizer_files"
    encoder_path = "./models/encoder.mlpackage"
    decoder_path = "./models/decoder.mlpackage"
    
    if not os.path.exists(encoder_path) or not os.path.exists(decoder_path):
        print("Error: Converted CoreML models not found. Please run convert_marian_to_coreml.py first.")
        return

    print("Loading tokenizer...")
    tokenizer = MarianTokenizer.from_pretrained(tokenizer_dir)

    print("Loading CoreML models...")
    encoder_model = ct.models.MLModel(encoder_path)
    decoder_model = ct.models.MLModel(decoder_path)

    # Print inputs and outputs to verify names
    print("\n--- Encoder Info ---")
    print("Inputs:", list(encoder_model.input_description))
    print("Outputs:", list(encoder_model.output_description))
    encoder_output_key = list(encoder_model.output_description)[0]

    print("\n--- Decoder Info ---")
    print("Inputs:", list(decoder_model.input_description))
    print("Outputs:", list(decoder_model.output_description))
    decoder_output_key = list(decoder_model.output_description)[0]

    # Test text
    test_text = "안녕하세요. 오늘 날씨가 아주 좋네요."
    print(f"\nTest input: {test_text}")

    # Tokenize input
    inputs = tokenizer(test_text)
    input_ids = np.array([inputs["input_ids"]], dtype=np.int32)
    attention_mask = np.array([inputs["attention_mask"]], dtype=np.int32)

    # 1. Run Encoder
    print("Running Encoder...")
    encoder_outputs = encoder_model.predict({
        "input_ids": input_ids,
        "attention_mask": attention_mask
    })
    encoder_hidden_states = encoder_outputs[encoder_output_key]
    
    # 2. Autoregressive Decoder Loop (Greedy Search)
    print("Running Decoder Loop...")
    # MarianMT uses the PAD token (65000 in opus-mt-ko-en) as decoder_start_token_id
    pad_token_id = tokenizer.pad_token_id if tokenizer.pad_token_id is not None else 65000
    eos_token_id = tokenizer.eos_token_id if tokenizer.eos_token_id is not None else 0
    
    # Start sequence with PAD token
    dec_ids = [pad_token_id]
    max_length = 50

    for step in range(max_length):
        dec_input = np.array([dec_ids], dtype=np.int32)
        
        # Run Decoder
        decoder_outputs = decoder_model.predict({
            "decoder_input_ids": dec_input,
            "encoder_hidden_states": encoder_hidden_states,
            "encoder_attention_mask": attention_mask
        })
        
        logits = decoder_outputs[decoder_output_key] # Shape: [1, vocab_size]
        
        # Get token with highest probability (greedy); PAD is never generated (bad_words_ids in HF config)
        next_logits = logits[0].copy()
        next_logits[pad_token_id] = -np.inf
        next_token = int(np.argmax(next_logits))
        dec_ids.append(next_token)
        
        # Stop if EOS is predicted
        if next_token == eos_token_id:
            break

    # Decode translation
    translated_text = tokenizer.decode(dec_ids, skip_special_tokens=True)
    print(f"CoreML Translation: {translated_text}")

if __name__ == "__main__":
    main()

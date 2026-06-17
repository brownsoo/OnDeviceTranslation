import os
import torch
import torch.nn as nn
import numpy as np
import coremltools as ct
from transformers import MarianMTModel, MarianTokenizer
from coremltools.converters.mil import Builder as mb
from coremltools.converters.mil.frontend.torch.torch_op_registry import register_torch_op
from coremltools.converters.mil.frontend.torch.ops import _get_inputs, logical_and

@register_torch_op
def new_ones(context, node):
    inputs = _get_inputs(context, node)
    shape = inputs[1]
    if isinstance(shape, list):
        shape = mb.concat(values=shape, axis=0)
    # Cast shape to int32 to satisfy CoreML's requirement
    shape = mb.cast(x=shape, dtype="int32")
    context.add(mb.fill(shape=shape, value=1., name=node.name))

@register_torch_op(torch_alias=["and"], override=True)
def bitwise_and(context, node):
    logical_and(context, node)

def main():
    model_name = "Helsinki-NLP/opus-mt-ko-en"
    print(f"Loading model and tokenizer for {model_name}...")
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name)
    model.eval()

    # Test sentence translation
    test_text = "안녕하세요. 오늘 날씨가 아주 좋네요."
    print(f"Test input: {test_text}")
    inputs = tokenizer(test_text, return_tensors="pt")
    with torch.no_grad():
        translated_tokens = model.generate(**inputs)
        translated_text = tokenizer.decode(translated_tokens[0], skip_special_tokens=True)
    print(f"PyTorch Translation: {translated_text}")

    # Create directories for outputs
    os.makedirs("./models", exist_ok=True)
    os.makedirs("./tokenizer_files", exist_ok=True)

    # Save tokenizer files
    tokenizer.save_pretrained("./tokenizer_files")
    print("Tokenizer files saved to ./tokenizer_files")

    # Define wrappers for CoreML conversion
    class MarianEncoderWrapper(nn.Module):
        def __init__(self, encoder):
            super().__init__()
            self.encoder = encoder

        def forward(self, input_ids, attention_mask):
            outputs = self.encoder(input_ids=input_ids, attention_mask=attention_mask)
            return outputs.last_hidden_state

    class MarianDecoderWrapper(nn.Module):
        def __init__(self, decoder, lm_head):
            super().__init__()
            self.decoder = decoder
            self.lm_head = lm_head

        def forward(self, decoder_input_ids, encoder_hidden_states, encoder_attention_mask):
            outputs = self.decoder(
                input_ids=decoder_input_ids,
                encoder_hidden_states=encoder_hidden_states,
                encoder_attention_mask=encoder_attention_mask
            )
            logits = self.lm_head(outputs.last_hidden_state)
            # Predict only for the last token position
            return logits[:, -1, :]

    # Instantiate wrappers
    encoder_wrapper = MarianEncoderWrapper(model.model.encoder)
    decoder_wrapper = MarianDecoderWrapper(model.model.decoder, model.lm_head)
    encoder_wrapper.eval()
    decoder_wrapper.eval()

    # Tracing shapes
    enc_seq_len = 10
    dec_seq_len = 5
    hidden_dim = model.config.d_model # 512

    dummy_input_ids = torch.ones(1, enc_seq_len, dtype=torch.long)
    dummy_attention_mask = torch.ones(1, enc_seq_len, dtype=torch.long)

    dummy_dec_input_ids = torch.ones(1, dec_seq_len, dtype=torch.long)
    dummy_enc_hidden_states = torch.zeros(1, enc_seq_len, hidden_dim, dtype=torch.float)
    dummy_enc_attention_mask = torch.ones(1, enc_seq_len, dtype=torch.long)

    # Trace models
    print("Tracing Encoder...")
    traced_encoder = torch.jit.trace(encoder_wrapper, (dummy_input_ids, dummy_attention_mask))

    print("Tracing Decoder...")
    # Using strict=False helps ignore non-tensor attributes or tracer warnings
    traced_decoder = torch.jit.trace(decoder_wrapper, (dummy_dec_input_ids, dummy_enc_hidden_states, dummy_enc_attention_mask), strict=False)

    # Conversion to CoreML (mlprogram)
    input_ids_shape = ct.Shape(shape=(1, ct.RangeDim(1, 512)))
    attention_mask_shape = ct.Shape(shape=(1, ct.RangeDim(1, 512)))

    print("Converting Encoder to CoreML...")
    encoder_mlmodel = ct.convert(
        traced_encoder,
        inputs=[
            ct.TensorType(name="input_ids", shape=input_ids_shape, dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=attention_mask_shape, dtype=np.int32)
        ],
        convert_to="mlprogram"
    )
    encoder_mlmodel.save("./models/encoder.mlpackage")
    print("Encoder saved to ./models/encoder.mlpackage")

    # For Decoder:
    dec_input_ids_shape = ct.Shape(shape=(1, ct.RangeDim(1, 512)))
    enc_hidden_states_shape = ct.Shape(shape=(1, ct.RangeDim(1, 512), hidden_dim))
    enc_attention_mask_shape = ct.Shape(shape=(1, ct.RangeDim(1, 512)))

    print("Converting Decoder to CoreML...")
    decoder_mlmodel = ct.convert(
        traced_decoder,
        inputs=[
            ct.TensorType(name="decoder_input_ids", shape=dec_input_ids_shape, dtype=np.int32),
            ct.TensorType(name="encoder_hidden_states", shape=enc_hidden_states_shape, dtype=np.float32),
            ct.TensorType(name="encoder_attention_mask", shape=enc_attention_mask_shape, dtype=np.int32)
        ],
        convert_to="mlprogram"
    )
    decoder_mlmodel.save("./models/decoder.mlpackage")
    print("Decoder saved to ./models/decoder.mlpackage")

    # Generate and save tokenizer mapping files
    import json
    import sentencepiece as spm

    print("Generating mapping files...")
    # 1. Source (Korean) raw SentencePiece ID -> Model vocab ID
    vocab_path = "./tokenizer_files/vocab.json"
    with open(vocab_path, "r", encoding="utf-8") as f:
        vocab = json.load(f)

    sp_source = spm.SentencePieceProcessor(model_file="./tokenizer_files/source.spm")
    source_mapping = []
    unk_id = vocab.get("<unk>", 1)
    for i in range(sp_source.get_piece_size()):
        piece = sp_source.id_to_piece(i)
        source_mapping.append(vocab.get(piece, unk_id))

    with open("./models/source_id_to_vocab_id.json", "w", encoding="utf-8") as f:
        json.dump(source_mapping, f)
    print("Saved ./models/source_id_to_vocab_id.json")

    # 2. Target (English) Model vocab ID -> English piece string
    vocab_size = max(vocab.values()) + 1
    target_mapping = ["<unk>"] * vocab_size
    for piece, idx in vocab.items():
        if idx < vocab_size:
            target_mapping[idx] = piece

    with open("./models/target_vocab_id_to_piece.json", "w", encoding="utf-8") as f:
        json.dump(target_mapping, f, ensure_ascii=False)
    print("Saved ./models/target_vocab_id_to_piece.json")


if __name__ == "__main__":
    main()

import SwiftUI
import OnDeviceTranslationEngine

struct ContentView: View {
    @State private var inputText = "안녕하세요. 오늘 날씨가 아주 좋네요. 만나서 반갑습니다."
    @State private var translatedText = ""
    @State private var statusMessage = "Initializing Engine..."
    @State private var isTranslating = false
    @State private var isEngineReady = false
    @State private var inferenceTime: Double? = nil
    
    @State private var engine: OnDeviceTranslationEngine? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Korean (Source)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $inputText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .disabled(!isEngineReady)
                }
                .padding(.horizontal)
                
                // Translate Button
                Button(action: runTranslation) {
                    HStack {
                        if isTranslating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        } else {
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        }
                        Text(isTranslating ? "Translating..." : "Translate to English")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isEngineReady && !inputText.isEmpty ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(!isEngineReady || inputText.isEmpty || isTranslating)
                
                // Output Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("English (Target)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !translatedText.isEmpty {
                            Button(action: copyToClipboard) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    ScrollView {
                        Text(translatedText.isEmpty ? "Translation will appear here..." : translatedText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(translatedText.isEmpty ? .secondary : .primary)
                            .padding()
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Status / Metrics Footer
                VStack(spacing: 4) {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundColor(isEngineReady ? .green : .orange)
                        .multilineTextAlignment(.center)
                    
                    if let elapsed = inferenceTime {
                        Text(String(format: "Inference time: %.2fs", elapsed))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("On-Device Translator")
            .onAppear(perform: initializeEngine)
        }
    }
    
    private func initializeEngine() {
        guard engine == nil else { return }
        
        statusMessage = "Loading & compiling models on device..."
        
        Task.detached(priority: .userInitiated) {
            do {
                // Retrieve bundle URLs
                guard let encoderURL = Bundle.main.url(forResource: "encoder", withExtension: "mlpackage") ?? Bundle.main.url(forResource: "encoder", withExtension: "mlmodelc"),
                      let decoderURL = Bundle.main.url(forResource: "decoder", withExtension: "mlpackage") ?? Bundle.main.url(forResource: "decoder", withExtension: "mlmodelc"),
                      let tokenizerPath = Bundle.main.path(forResource: "source", ofType: "spm"),
                      let sourceMapURL = Bundle.main.url(forResource: "source_id_to_vocab_id", withExtension: "json"),
                      let targetMapURL = Bundle.main.url(forResource: "target_vocab_id_to_piece", withExtension: "json") else {
                    throw NSError(domain: "SampleApp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Required model/mapping files not found in app bundle."])
                }
                
                let initStart = Date()
                let loadedEngine = try OnDeviceTranslationEngine(
                    encoderModelURL: encoderURL,
                    decoderModelURL: decoderURL,
                    tokenizerModelPath: tokenizerPath,
                    sourceMapURL: sourceMapURL,
                    targetMapURL: targetMapURL
                )
                let duration = Date().timeIntervalSince(initStart)
                
                await MainActor.run {
                    self.engine = loadedEngine
                    self.isEngineReady = true
                    self.statusMessage = String(format: "Engine Ready (Initialized in %.2fs)", duration)
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Initialization Failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func runTranslation() {
        guard let engine = engine, !isTranslating else { return }
        
        isTranslating = true
        statusMessage = "Translating..."
        
        let startTime = Date()
        
        Task {
            do {
                let textToTranslate = inputText
                let result = try await Task.detached(priority: .userInitiated) {
                    return try engine.translate(textToTranslate)
                }.value
                
                let elapsed = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    self.translatedText = result
                    self.isTranslating = false
                    self.inferenceTime = elapsed
                    self.statusMessage = "Translation complete"
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Translation error: \(error.localizedDescription)"
                    self.isTranslating = false
                }
            }
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = translatedText
        statusMessage = "Copied to clipboard!"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

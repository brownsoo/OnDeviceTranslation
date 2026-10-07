import Foundation

/// Example texts with the user's saved edits applied. Edits are stored per sample id.
@MainActor
final class SampleTextStore: ObservableObject {
    static let editsKey = "sampleTextEdits"

    @Published private(set) var samples: [SampleText]

    private let userDefaults: UserDefaults
    private let defaultSamples: [SampleText]
    private var edits: [String: String]

    init(userDefaults: UserDefaults = .standard, defaultSamples: [SampleText] = SampleTexts.defaults) {
        self.userDefaults = userDefaults
        self.defaultSamples = defaultSamples
        self.edits = userDefaults.dictionary(forKey: Self.editsKey) as? [String: String] ?? [:]
        self.samples = defaultSamples
        applyEdits()
    }

    func samples(in category: SampleCategory) -> [SampleText] {
        samples.filter { $0.category == category }
    }

    func sample(id: String) -> SampleText? {
        samples.first { $0.id == id }
    }

    func isEdited(_ id: String) -> Bool {
        edits[id] != nil
    }

    /// Saves `body` for the sample. Saving the default text removes the edit.
    func save(body: String, for id: String) {
        guard let original = defaultSamples.first(where: { $0.id == id }) else { return }
        edits[id] = body == original.body ? nil : body
        persist()
    }

    func resetToDefault(_ id: String) {
        edits[id] = nil
        persist()
    }

    private func persist() {
        userDefaults.set(edits, forKey: Self.editsKey)
        applyEdits()
    }

    private func applyEdits() {
        samples = defaultSamples.map { sample in
            var sample = sample
            if let body = edits[sample.id] {
                sample.body = body
            }
            return sample
        }
    }
}

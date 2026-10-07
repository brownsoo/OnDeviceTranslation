import Foundation

@MainActor
final class ComparisonViewModel: ObservableObject {
    @Published var inputText: String
    @Published private(set) var target: TargetLanguage = .english
    @Published private(set) var cards: [ProviderKind: CardState] = [:]
    /// Rewrites list markers and weekdays and uses the fixed allergy legend before translating.
    @Published var usesPreprocessing = true

    let providers: [TranslationProvider]

    /// Bumped on every new translation or target change so results of older requests are dropped.
    private var generation = 0
    private var translationTask: Task<Void, Never>?

    init(providers: [TranslationProvider], inputText: String = "") {
        self.providers = providers
        self.inputText = inputText
        for provider in providers {
            cards[provider.kind] = .idle
        }
    }

    var canTranslate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadSample(_ sample: SampleText) {
        inputText = sample.body
    }

    func state(for kind: ProviderKind) -> CardState {
        cards[kind] ?? .idle
    }

    /// Changes the target language, cancelling any in-flight translation and clearing results.
    @discardableResult
    func select(_ newTarget: TargetLanguage) -> Task<Void, Never> {
        cancelInFlight()
        target = newTarget
        for provider in providers {
            cards[provider.kind] = .idle
        }
        return Task { await refreshStatuses() }
    }

    /// Re-reads language pack status for the current target. Finished results and errors are kept.
    func refreshStatuses() async {
        let generation = self.generation
        let target = self.target
        for provider in providers {
            let newState: CardState
            if provider.supports(target) {
                newState = CardState(packStatus: await provider.packStatus(for: target))
            } else {
                newState = .unsupported
            }
            guard generation == self.generation else { return }
            if state(for: provider.kind).isReplaceableByStatus {
                cards[provider.kind] = newState
            }
        }
    }

    /// Runs every engine concurrently on the current input. Returns nil when the input is blank.
    @discardableResult
    func translate() -> Task<Void, Never>? {
        guard canTranslate else { return nil }
        cancelInFlight()
        let generation = self.generation
        let text = inputText
        let target = self.target
        let providers = self.providers
        let segments: [TranslationSegment] = usesPreprocessing
            ? TranslationPreprocessor.segments(text, target: target)
            : [.translate(text)]
        let task = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                for provider in providers {
                    group.addTask {
                        await self?.run(provider, segments: segments, target: target, generation: generation)
                    }
                }
            }
        }
        translationTask = task
        return task
    }

    private func run(_ provider: TranslationProvider, segments: [TranslationSegment], target: TargetLanguage, generation: Int) async {
        guard provider.supports(target) else {
            update(provider.kind, .unsupported, generation: generation)
            return
        }
        let status = await provider.packStatus(for: target)
        guard status == .installed else {
            update(provider.kind, CardState(packStatus: status), generation: generation)
            return
        }
        update(provider.kind, .translating, generation: generation)
        let start = Date()
        do {
            var parts: [String] = []
            for segment in segments {
                switch segment {
                case .translate(let text): parts.append(try await provider.translate(text, to: target))
                case .fixed(let text): parts.append(text)
                }
            }
            let result = TranslationPreprocessor.join(parts)
            update(provider.kind, .result(text: result, seconds: Date().timeIntervalSince(start)), generation: generation)
        } catch {
            update(provider.kind, .error(error.localizedDescription), generation: generation)
        }
    }

    private func update(_ kind: ProviderKind, _ state: CardState, generation: Int) {
        guard generation == self.generation, !Task.isCancelled else { return }
        cards[kind] = state
    }

    private func cancelInFlight() {
        translationTask?.cancel()
        translationTask = nil
        generation += 1
    }
}

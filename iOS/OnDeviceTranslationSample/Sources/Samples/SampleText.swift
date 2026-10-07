import Foundation

enum SampleCategory: String, CaseIterable, Identifiable {
    case homeLetter
    case meal
    case schoolNotice

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homeLetter: return "가정통신문"
        case .meal: return "급식"
        case .schoolNotice: return "학교공지"
        }
    }
}

/// A Korean example text to translate. `id` is stable so user edits can be stored per sample.
struct SampleText: Identifiable, Equatable {
    let id: String
    let category: SampleCategory
    let title: String
    var body: String
}

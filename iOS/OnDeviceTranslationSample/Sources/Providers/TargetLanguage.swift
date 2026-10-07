import Foundation

/// The source language is fixed to Korean.
enum SourceLanguage {
    static let appleLanguageCode = "ko"
}

/// Languages the user can translate Korean into.
enum TargetLanguage: String, CaseIterable, Identifiable {
    case english
    case vietnamese
    case indonesian
    case japanese
    case chineseSimplified

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .english: return "EN"
        case .vietnamese: return "VI"
        case .indonesian: return "ID"
        case .japanese: return "JA"
        case .chineseSimplified: return "ZH"
        }
    }

    var displayName: String { packLanguage.displayName }

    /// Locale identifier used by Apple's Translation framework.
    var appleLanguageCode: String {
        switch self {
        case .english: return "en"
        case .vietnamese: return "vi"
        case .indonesian: return "id"
        case .japanese: return "ja"
        case .chineseSimplified: return "zh-Hans"
        }
    }

    var packLanguage: PackLanguage {
        switch self {
        case .english: return .english
        case .vietnamese: return .vietnamese
        case .indonesian: return .indonesian
        case .japanese: return .japanese
        case .chineseSimplified: return .chineseSimplified
        }
    }
}

/// A single downloadable language. ML Kit models are per language, including the Korean source.
enum PackLanguage: String, CaseIterable, Identifiable {
    case korean
    case english
    case vietnamese
    case indonesian
    case japanese
    case chineseSimplified

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: return "한국어 (원문)"
        case .english: return "영어"
        case .vietnamese: return "베트남어"
        case .indonesian: return "인도네시아어"
        case .japanese: return "일본어"
        case .chineseSimplified: return "중국어 (간체)"
        }
    }

    var targetLanguage: TargetLanguage? {
        switch self {
        case .korean: return nil
        case .english: return .english
        case .vietnamese: return .vietnamese
        case .indonesian: return .indonesian
        case .japanese: return .japanese
        case .chineseSimplified: return .chineseSimplified
        }
    }
}

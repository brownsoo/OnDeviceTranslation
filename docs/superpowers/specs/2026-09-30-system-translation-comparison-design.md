# 시스템 번역 엔진 추가 및 비교 화면 설계

- 작성일: 2026-09-30
- 대상: `iOS/OnDeviceTranslationSample` (샘플 앱)

## 1. 목적

기존 Core ML(opus-mt-ko-en) 번역 외에 OS 제공/서드파티 온디바이스 번역 엔진을 추가하고, 같은 한국어 문장을 엔진별로 나란히 비교할 수 있는 테스트 앱을 만든다. 배포용 앱이 아니라 엔진 품질·속도·언어팩 흐름을 검증하는 도구다.

## 2. 요구사항

### 사용자가 정한 것
- iOS 26 이상: Apple Translation 프레임워크, iOS 26 미만: Google ML Kit Translation.
- 대상 언어: 영어, 베트남어, 인도네시아어, 일본어, 중국어(간체).
- 언어팩 다운로드 처리.
- 앱에서 같은 문장의 엔진별 결과 비교.
- iOS 26 이상에서는 Core ML · Apple · ML Kit 세 결과를 모두 비교한다. iOS 26 미만은 Core ML · ML Kit.
- 언어팩은 별도 관리 화면 + 결과 카드 안내로 처리한다.
- Xcode 프로젝트는 XcodeGen으로 생성한다.
- 서명 팀: hyonsoo han (`TB576F3KJ6`), 번들 ID `com.brownsoo.OnDeviceTranslationSample`.

### 가정
- 원문 언어는 한국어 고정.
- Core ML 엔진은 한→영만 지원하므로 다른 대상 언어에서는 "지원 안 함"으로 표시한다.

### 확인된 제약
- ML Kit은 CocoaPods로만 공식 배포된다 (`GoogleMLKit/Translate` 9.0.0 → `MLKitTranslate` 8.0.0). 최소 iOS 15.5.
- ML Kit은 Apple Silicon 시뮬레이터 지원에 문제가 알려져 있어 실제 기기에서 검증한다.
- `TranslationSession`, `LanguageAvailability`, `prepareTranslation()`은 iOS 18+. `TranslationSession(installedSource:target:)`은 iOS 26+이며 언어가 설치되어 있지 않으면 번역 시 오류를 던진다.
- Apple 언어팩 다운로드 동의는 SwiftUI `.translationTask`가 제공하는 세션의 `prepareTranslation()`으로만 요청할 수 있다. 앱에서 Apple 언어팩을 삭제할 수는 없다 (설정 앱에서 삭제).
- 검증 기기: iPhone 17 (iOS 27.0). iOS 26 미만 기기는 연결되어 있지 않다.

## 3. 구조

```
OnDeviceTranslationEngine (SPM, 수정 없음)        ← Core ML 한→영
        ▲
OnDeviceTranslationSample (앱, XcodeGen + CocoaPods)
 ├─ TargetLanguage        대상 언어 5개 + 엔진별 언어 코드 매핑
 ├─ TranslationProvider   공통 프로토콜
 ├─ CoreMLProvider        기존 엔진 래핑, 영어만, 언어팩 항상 설치됨
 ├─ MLKitProvider         한국어·대상 언어 모델 다운로드/삭제/번역
 └─ AppleProvider         iOS 26+ 전용, LanguageAvailability 상태 조회 + installedSource 세션 번역
```

엔진 구현은 ML Kit이 CocoaPods 전용이라 SPM 패키지가 아닌 앱 타겟에 둔다.

### TranslationProvider

```swift
enum ProviderKind { case coreML, apple, mlKit }

enum LanguagePackStatus: Equatable {
    case installed
    case notInstalled
    case downloading
    case unsupported
    case failed(String)
}

protocol TranslationProvider: AnyObject {
    var kind: ProviderKind { get }
    var displayName: String { get }
    func supports(_ target: TargetLanguage) -> Bool
    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus
    func translate(_ text: String, to target: TargetLanguage) async throws -> String
}
```

- 다운로드는 엔진마다 방식이 달라 프로토콜에 넣지 않는다. ML Kit 다운로드/삭제는 `MLKitProvider`의 메서드, Apple 다운로드는 뷰의 `.translationTask`가 담당한다.
- 엔진 목록은 OS 버전으로 결정한다: iOS 26+ `[coreML, apple, mlKit]`, 미만 `[coreML, mlKit]`.

### TargetLanguage 매핑

| TargetLanguage | Apple `Locale.Language` | ML Kit `TranslateLanguage` |
|---|---|---|
| english | `en` | `.english` |
| vietnamese | `vi` | `.vietnamese` |
| indonesian | `id` | `.indonesian` |
| japanese | `ja` | `.japanese` |
| chineseSimplified | `zh-Hans` | `.chinese` |
| (원문) korean | `ko` | `.korean` |

Apple의 실제 지원 여부는 하드코딩하지 않고 `LanguageAvailability.status(from:to:)`로 조회해 `unsupported`를 표시한다.

## 4. 화면과 데이터 흐름

### 비교 화면 (메인)
- 한국어 입력(TextEditor), 대상 언어 세그먼트(EN/VI/ID/JA/ZH), [번역] 버튼, 엔진별 결과 카드, 툴바의 [언어팩] 버튼.
- [번역]: 해당 언어를 지원하는 엔진들을 동시에 실행하고, 완료되는 대로 카드에 결과와 소요 시간을 표시한다.
- 카드 상태: `idle`, `translating`, `result(text, seconds)`, `unsupported`, `needsDownload`, `error(message)`.
- 대상 언어 변경 시 결과를 비우고 언어팩 상태를 다시 조회한다.
- `needsDownload` 카드의 [다운로드]는 언어팩 화면과 같은 다운로드 동작을 호출한다.

### 언어팩 화면
- 행: 한국어(원문) + 대상 언어 5개. 열: Apple(iOS 26+에서만), ML Kit.
- ML Kit: [받기] / 다운로드 중 / 설치됨 [삭제] / 실패 [다시 받기]. 다운로드 조건은 셀룰러 허용, 백그라운드 허용. `.mlkitModelDownloadDidSucceed` / `.mlkitModelDownloadDidFail` 알림으로 상태 갱신.
- Apple: [받기] → `.translationTask` 구성을 설정 → 전달된 세션에서 `prepareTranslation()` 호출 → 시스템 동의 시트 → 종료 후 상태 재조회. "Apple 언어팩 삭제는 설정 앱에서" 안내 문구.

### 상태 관리
- `ComparisonViewModel` (@MainActor, ObservableObject): 엔진 목록, 입력 텍스트, 선택 언어, 카드 상태.
- `LanguagePackStore` (@MainActor, ObservableObject, 두 화면이 공유): 엔진×언어 언어팩 상태, ML Kit 다운로드/삭제, Apple 다운로드 요청 상태.
- iOS 15.5 최소 지원이므로 `@Observable` 대신 `ObservableObject`를 사용한다.

## 5. 오류 처리

- 엔진별로 독립 처리하며 한 엔진의 실패가 다른 카드에 영향을 주지 않는다.
- Apple 번역에서 언어 미설치 오류가 나면 카드를 `needsDownload`로 바꾼다. 그 밖의 오류는 설명 문구를 표시한다.
- ML Kit 다운로드 실패는 알림의 오류를 표시하고 [다시 받기]를 제공한다.
- Core ML 모델 초기화 실패 시 Core ML 카드에 초기화 실패를 표시하고 다른 엔진은 정상 동작한다.
- 번역 중 대상 언어를 바꾸거나 다시 번역하면 진행 중 작업을 취소하고, 이전 요청의 결과가 새 상태를 덮어쓰지 않도록 한다.

## 6. 테스트

| 대상 | 방법 |
|---|---|
| TargetLanguage 매핑, 엔진별 지원 언어, OS 버전별 엔진 목록, ViewModel 카드 상태 전환·취소 | 앱 테스트 타겟 단위 테스트 (가짜 Provider 주입) |
| Core ML 엔진 | 기존 SPM 테스트 유지 |
| Apple, ML Kit 실동작 | iPhone 17 (iOS 27)에서 수동/기기 조작 도구로 검증: 3개 카드 번역, ML Kit 받기·삭제·재다운로드, Apple 다운로드 동의 시트 |

- 단위 테스트는 ML Kit 시뮬레이터 제약 때문에 기기에서 실행한다.
- iOS 26 미만 경로는 기기 검증이 불가하므로 엔진 목록 결정 로직만 단위 테스트로 확인한다.
- Apple 동의 시트는 시스템 UI이므로 기기 조작 도구로 시도하고, 불가하면 사용자에게 해당 탭만 요청한다.

## 7. 프로젝트 구성

```
iOS/OnDeviceTranslationSample/
 ├─ project.yml                        XcodeGen 정의 (커밋)
 ├─ Podfile, Podfile.lock              GoogleMLKit/Translate (커밋)
 ├─ OnDeviceTranslationSample.xcodeproj / .xcworkspace   생성물 커밋
 ├─ Pods/                              .gitignore
 ├─ Configs/Local.xcconfig             DEVELOPMENT_TEAM, 번들 ID (.gitignore)
 ├─ Configs/Local.example.xcconfig     템플릿 (커밋)
 ├─ Sources/
 │   ├─ OnDeviceTranslationSampleApp.swift
 │   ├─ Comparison/     ComparisonView, ComparisonViewModel, ResultCard
 │   ├─ LanguagePacks/  LanguagePacksView, LanguagePackStore
 │   └─ Providers/      TranslationProvider, TargetLanguage, CoreMLProvider, MLKitProvider, AppleProvider
 ├─ Resources/                         기존 모델·매핑 파일 그대로
 ├─ Tests/                             앱 단위 테스트
 └─ README.md                          xcodegen → pod install → 실행 절차로 갱신
```

- 기존 `ContentView.swift`는 비교 화면으로 대체되어 삭제한다.
- 로컬 SPM 패키지 `../OnDeviceTranslationEngine`을 참조한다.
- 배포 대상 iOS 15.5.
- 필요한 도구: XcodeGen(brew 설치), CocoaPods 1.16.2(설치됨), Xcode 26.6.

## 8. 범위 밖

- Core ML 엔진 개선(KV cache, 한글 토큰 혼입 문제), Hy-MT2 등 다른 엔진 추가.
- `Resources/`와 `models/`의 모델 파일 중복 정리.
- 원문 언어 선택, 번역 기록 저장.

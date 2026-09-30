# 시스템 번역 엔진 비교 앱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 샘플 앱에 Apple Translation(iOS 26+)과 ML Kit 번역을 추가하고, 같은 한국어 문장을 Core ML·Apple·ML Kit 결과로 나란히 비교하며 언어팩을 관리할 수 있게 한다.

**Architecture:** 기존 `OnDeviceTranslationEngine` SPM 패키지는 수정하지 않는다. 앱 타겟 안에 `TranslationProvider` 프로토콜과 구현 3개(CoreML/MLKit/Apple)를 두고, `ComparisonViewModel`이 엔진들을 동시에 실행해 카드 상태를 관리한다. 언어팩 상태·다운로드는 `LanguagePackStore`가 맡고, Apple 다운로드 동의는 SwiftUI `.translationTask` 모디파이어(`AppleDownloadHost`)가 처리한다. Xcode 프로젝트는 XcodeGen으로 생성하고 ML Kit은 CocoaPods로 설치한다.

**Tech Stack:** Swift 5 모드, SwiftUI (iOS 15.5+), Core ML, Apple Translation framework, Google ML Kit Translate (CocoaPods `GoogleMLKit/Translate` 9.0.0), XcodeGen, CocoaPods 1.16.2, Xcode 26.6, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-30-system-translation-comparison-design.md`

## Global Constraints

- 배포 대상: iOS 15.5 (ML Kit 최소 버전).
- Apple Translation 경로는 iOS 26.0 이상에서만 사용 (`@available(iOS 26.0, *)` / `if #available(iOS 26.0, *)`). `Translation` 프레임워크는 weak link (`-weak_framework Translation`).
- iOS 26+ 엔진 목록: `[coreML, apple, mlKit]`, iOS 26 미만: `[coreML, mlKit]`.
- 원문 언어: 한국어 고정. 대상 언어: 영어(`en`), 베트남어(`vi`), 인도네시아어(`id`), 일본어(`ja`), 중국어 간체(`zh-Hans`).
- ML Kit 의존성: `pod 'GoogleMLKit/Translate', '9.0.0'`. 다운로드 조건: 셀룰러 허용, 백그라운드 허용.
- Core ML 엔진은 영어만 지원한다.
- 상태 관리는 `ObservableObject` (iOS 15.5 지원을 위해 `@Observable` 사용 안 함).
- 서명: `DEVELOPMENT_TEAM = TB576F3KJ6`, 번들 ID `com.brownsoo.OnDeviceTranslationSample` — 커밋하지 않는 `Configs/Local.xcconfig`에만 기록.
- `OnDeviceTranslationEngine` SPM 패키지 소스는 수정하지 않는다.
- UI 문구는 한국어.
- 모든 앱 테스트는 연결된 iPhone 17 (iOS 27.0)에서 실행한다 (ML Kit 시뮬레이터 제약).
  - xcodebuild destination: `platform=iOS,id=00008150-000E40492128C01C`
  - devicectl device: `DA312C82-BD17-5691-B4EC-3DCA4E039104`
- 소스 파일을 추가/삭제한 뒤에는 반드시 `./generate.sh` (XcodeGen 재생성 + `pod install`)를 실행한다.

## Review Focus

1. **공백만 있는 입력으로 번역** → 번역 버튼 비활성, 어떤 엔진도 호출되지 않아야 한다. (Task 3 `test_translate_whitespaceOnlyInput_doesNothing`)
2. **번역 중 대상 언어 변경** → 이전 요청의 결과가 새 언어의 카드에 나타나면 안 된다. (Task 3 `test_selectDuringTranslation_discardsStaleResult`)
3. **결과가 표시된 상태에서 언어팩 상태 갱신**(다운로드 완료 알림 등) → 이미 나온 결과가 지워지면 안 된다. (Task 3 `test_refreshStatuses_keepsFinishedResult`)
4. **다운로드 버튼 연타 / 한국어 팩이 이미 설치된 상태에서 다운로드** → 중복 다운로드 요청이 나가면 안 된다. (Task 5 `test_requestDownload_skipsInstalledAndInFlight`)
5. **ML Kit 다운로드 실패 후 화면 새로고침** → 실패 메시지와 [다시 받기]가 유지되어야 한다. (Task 5 `test_refresh_keepsFailureUntilDownloaded`)

---

## File Structure

```
.gitignore                                                    (수정) Pods, Local.xcconfig, build, xcuserdata
iOS/OnDeviceTranslationSample/
 ├─ generate.sh                     xcodegen generate + pod install
 ├─ project.yml                     XcodeGen 정의
 ├─ Podfile / Podfile.lock          ML Kit
 ├─ OnDeviceTranslationSample.xcodeproj, .xcworkspace   (생성물, 커밋)
 ├─ Configs/Base.xcconfig           공통 설정 + Local.xcconfig 선택적 include
 ├─ Configs/Local.example.xcconfig  서명 템플릿
 ├─ Configs/Local.xcconfig          (gitignore) 실제 팀/번들 ID
 ├─ Configs/Info.plist              (XcodeGen 생성)
 ├─ Sources/
 │   ├─ OnDeviceTranslationSampleApp.swift     앱 진입점 (Task 1 이동, Task 6 수정)
 │   ├─ AppDependencies.swift                  엔진/스토어/뷰모델 조립 (Task 6)
 │   ├─ Providers/
 │   │   ├─ TargetLanguage.swift              TargetLanguage, PackLanguage, SourceLanguage (Task 1)
 │   │   ├─ TranslationProvider.swift         프로토콜, ProviderKind, LanguagePackStatus (Task 2)
 │   │   ├─ CoreMLProvider.swift              (Task 2)
 │   │   ├─ MLKitProvider.swift               MLKitPackManaging, MLKitProvider, 매핑 (Task 4)
 │   │   └─ AppleProvider.swift               (Task 4)
 │   ├─ Comparison/
 │   │   ├─ CardState.swift                   (Task 3)
 │   │   ├─ ComparisonViewModel.swift         (Task 3)
 │   │   ├─ ResultCard.swift                  (Task 6)
 │   │   └─ ComparisonView.swift              (Task 6)
 │   └─ LanguagePacks/
 │       ├─ LanguagePackStore.swift           (Task 5)
 │       ├─ PackStatusControl.swift           (Task 5)
 │       ├─ AppleDownloadHost.swift           (Task 5)
 │       └─ LanguagePacksView.swift           (Task 5)
 ├─ Resources/                      기존 모델·매핑 (변경 없음)
 ├─ Tests/
 │   ├─ Fakes.swift                 FakeError, FakeProvider, FakeMLKitManager, waitUntil
 │   ├─ TargetLanguageTests.swift
 │   ├─ ProviderTests.swift
 │   ├─ ComparisonViewModelTests.swift
 │   ├─ MLKitMappingTests.swift
 │   └─ LanguagePackStoreTests.swift
 └─ README.md                       (Task 7 재작성)
삭제: iOS/OnDeviceTranslationSample/ContentView.swift (Task 1에서 Sources/로 이동 후 Task 6에서 삭제)
```

---

### Task 1: XcodeGen·CocoaPods 프로젝트 구성 + 언어 모델 타입

**Files:**
- Modify: `.gitignore`
- Create: `iOS/OnDeviceTranslationSample/generate.sh`, `project.yml`, `Podfile`, `Configs/Base.xcconfig`, `Configs/Local.example.xcconfig`, `Configs/Local.xcconfig`(ignored)
- Move: `iOS/OnDeviceTranslationSample/ContentView.swift` → `Sources/ContentView.swift`, `OnDeviceTranslationSampleApp.swift` → `Sources/OnDeviceTranslationSampleApp.swift`
- Create: `Sources/Providers/TargetLanguage.swift`
- Test: `Tests/TargetLanguageTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `enum SourceLanguage { static let appleLanguageCode: String }` (= `"ko"`)
  - `enum TargetLanguage: String, CaseIterable, Identifiable { english, vietnamese, indonesian, japanese, chineseSimplified }` — `shortLabel: String`, `displayName: String`, `appleLanguageCode: String`, `packLanguage: PackLanguage`
  - `enum PackLanguage: String, CaseIterable, Identifiable { korean, english, vietnamese, indonesian, japanese, chineseSimplified }` — `displayName: String`, `targetLanguage: TargetLanguage?`
  - `./generate.sh`, 앱 타겟 `OnDeviceTranslationSample`, 테스트 타겟 `OnDeviceTranslationSampleTests`, 스킴 `OnDeviceTranslationSample`

- [ ] **Step 1: XcodeGen 설치 확인**

Run: `brew install xcodegen && xcodegen --version`
Expected: `Version: 2.x.x`

- [ ] **Step 2: .gitignore에 생성물·로컬 설정 추가**

`.gitignore` 끝에 추가:

```gitignore

# iOS sample app
iOS/OnDeviceTranslationSample/Pods/
iOS/OnDeviceTranslationSample/build/
iOS/OnDeviceTranslationSample/Configs/Local.xcconfig
xcuserdata/
```

- [ ] **Step 3: 기존 소스를 Sources/로 이동**

```bash
cd iOS/OnDeviceTranslationSample
mkdir -p Sources/Providers Sources/Comparison Sources/LanguagePacks Tests Configs
git mv ContentView.swift Sources/ContentView.swift
git mv OnDeviceTranslationSampleApp.swift Sources/OnDeviceTranslationSampleApp.swift
```

- [ ] **Step 4: xcconfig 작성**

`Configs/Base.xcconfig`:

```
// Shared build settings. Signing values come from Local.xcconfig (not committed).
APP_BUNDLE_ID = com.example.OnDeviceTranslationSample
DEVELOPMENT_TEAM =

#include? "Local.xcconfig"
```

`Configs/Local.example.xcconfig`:

```
// Copy to Local.xcconfig and fill in your signing team and bundle id.
DEVELOPMENT_TEAM = YOUR_TEAM_ID
APP_BUNDLE_ID = com.yourcompany.OnDeviceTranslationSample
```

`Configs/Local.xcconfig` (gitignore 대상):

```
DEVELOPMENT_TEAM = TB576F3KJ6
APP_BUNDLE_ID = com.brownsoo.OnDeviceTranslationSample
```

- [ ] **Step 5: project.yml 작성**

`project.yml`:

```yaml
name: OnDeviceTranslationSample
options:
  deploymentTarget:
    iOS: "15.5"
  createIntermediateGroups: true
configFiles:
  Debug: Configs/Base.xcconfig
  Release: Configs/Base.xcconfig
settings:
  base:
    SWIFT_VERSION: "5.0"
    ENABLE_USER_SCRIPT_SANDBOXING: NO
    COREML_CODEGEN_LANGUAGE: None
packages:
  OnDeviceTranslationEngine:
    path: ../OnDeviceTranslationEngine
targets:
  OnDeviceTranslationSample:
    type: application
    platform: iOS
    sources:
      - Sources
      - Resources
    dependencies:
      - package: OnDeviceTranslationEngine
    info:
      path: Configs/Info.plist
      properties:
        CFBundleDisplayName: On-Device Translator
        UILaunchScreen: {}
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID)
        CODE_SIGN_STYLE: Automatic
        TARGETED_DEVICE_FAMILY: "1,2"
        OTHER_LDFLAGS: ["$(inherited)", "-weak_framework", "Translation"]
  OnDeviceTranslationSampleTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - Tests
    dependencies:
      - target: OnDeviceTranslationSample
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID).tests
        CODE_SIGN_STYLE: Automatic
        GENERATE_INFOPLIST_FILE: YES
schemes:
  OnDeviceTranslationSample:
    build:
      targets:
        OnDeviceTranslationSample: all
    test:
      targets:
        - OnDeviceTranslationSampleTests
```

- [ ] **Step 6: Podfile과 generate.sh 작성**

`Podfile`:

```ruby
platform :ios, '15.5'
project 'OnDeviceTranslationSample.xcodeproj'

target 'OnDeviceTranslationSample' do
  pod 'GoogleMLKit/Translate', '9.0.0'

  target 'OnDeviceTranslationSampleTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'
    end
  end
end
```

`generate.sh`:

```bash
#!/bin/sh
# Regenerates the Xcode project and re-integrates CocoaPods. Run after adding or removing files.
set -e
cd "$(dirname "$0")"
xcodegen generate
pod install
```

Run: `chmod +x generate.sh`

- [ ] **Step 7: 실패하는 테스트 작성**

`Tests/TargetLanguageTests.swift`:

```swift
import XCTest
@testable import OnDeviceTranslationSample

final class TargetLanguageTests: XCTestCase {
    func test_targetLanguages_areTheFiveRequestedInOrder() {
        XCTAssertEqual(TargetLanguage.allCases, [.english, .vietnamese, .indonesian, .japanese, .chineseSimplified])
        XCTAssertEqual(TargetLanguage.allCases.map(\.shortLabel), ["EN", "VI", "ID", "JA", "ZH"])
    }

    func test_appleLanguageCodes() {
        XCTAssertEqual(SourceLanguage.appleLanguageCode, "ko")
        XCTAssertEqual(TargetLanguage.allCases.map(\.appleLanguageCode), ["en", "vi", "id", "ja", "zh-Hans"])
    }

    func test_packLanguages_startWithKoreanSourceAndMapBackToTargets() {
        XCTAssertEqual(PackLanguage.allCases.first, .korean)
        XCTAssertNil(PackLanguage.korean.targetLanguage)
        for target in TargetLanguage.allCases {
            XCTAssertEqual(target.packLanguage.targetLanguage, target)
            XCTAssertEqual(target.displayName, target.packLanguage.displayName)
        }
    }
}
```

- [ ] **Step 8: 프로젝트 생성 후 테스트가 실패하는지 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/TargetLanguageTests
```
Expected: 컴파일 실패 — `cannot find 'TargetLanguage' in scope`

- [ ] **Step 9: TargetLanguage 구현**

`Sources/Providers/TargetLanguage.swift`:

```swift
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
```

- [ ] **Step 10: 재생성 후 테스트 통과 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/TargetLanguageTests
```
Expected: `** TEST SUCCEEDED **` (3 tests)

- [ ] **Step 11: 앱 빌드·설치 후 Core ML 모델이 컴파일되어 들어갔는지 확인**

Run:
```bash
xcodebuild build -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -derivedDataPath build -allowProvisioningUpdates -quiet
ls build/Build/Products/Debug-iphoneos/OnDeviceTranslationSample.app | grep -E "coder|spm|json"
```
Expected: `decoder.mlmodelc`, `encoder.mlmodelc`, `source.spm`, `source_id_to_vocab_id.json`, `target_vocab_id_to_piece.json`

`encoder.mlmodelc` 대신 `encoder.mlpackage`가 보이거나 모델이 없으면: XcodeGen이 `.mlpackage`를 소스로 인식하지 못한 것이다. `project.yml`의 `Resources` 소스 항목을 아래처럼 바꾸고 `./generate.sh` 후 다시 확인한다.

```yaml
      - path: Resources
        excludes: ["*.mlpackage"]
      - path: Resources/encoder.mlpackage
        type: file
        buildPhase: sources
      - path: Resources/decoder.mlpackage
        type: file
        buildPhase: sources
```

- [ ] **Step 12: 기기에서 기존 화면 동작 확인**

Run:
```bash
xcrun devicectl device install app --device DA312C82-BD17-5691-B4EC-3DCA4E039104 build/Build/Products/Debug-iphoneos/OnDeviceTranslationSample.app
xcrun devicectl device process launch --device DA312C82-BD17-5691-B4EC-3DCA4E039104 com.brownsoo.OnDeviceTranslationSample
```
Expected: 앱이 실행되고 "Engine Ready"가 표시되며 [Translate to English]로 영어 번역이 나온다. (기기 잠금 해제 필요. 처음 설치 시 기기에서 개발자 신뢰 설정이 필요할 수 있다.)

- [ ] **Step 13: Commit**

```bash
cd ../..
git add .gitignore iOS/OnDeviceTranslationSample
git status --short   # Local.xcconfig, Pods/, build/ 가 없는지 확인
git commit -m "build: Generate sample app project with XcodeGen and add ML Kit pod

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: TranslationProvider 프로토콜과 CoreMLProvider

**Files:**
- Create: `Sources/Providers/TranslationProvider.swift`, `Sources/Providers/CoreMLProvider.swift`
- Create: `Tests/Fakes.swift`
- Test: `Tests/ProviderTests.swift`

**Interfaces:**
- Consumes: `TargetLanguage` (Task 1)
- Produces:
  - `enum ProviderKind: String, CaseIterable { coreML, apple, mlKit }` + `static func available(isAppleAvailable: Bool) -> [ProviderKind]`
  - `enum LanguagePackStatus: Equatable { installed, notInstalled, downloading, unsupported, failed(String) }`
  - `protocol TranslationProvider: AnyObject { var kind: ProviderKind { get }; var displayName: String { get }; func supports(_ target: TargetLanguage) -> Bool; func packStatus(for target: TargetLanguage) async -> LanguagePackStatus; func translate(_ text: String, to target: TargetLanguage) async throws -> String }`
  - `final class CoreMLProvider: TranslationProvider` — `init(loadEngine: @escaping () throws -> OnDeviceTranslationEngine = CoreMLProvider.loadBundledEngine)`
  - `enum CoreMLProviderError: LocalizedError { unsupportedTarget, missingResources }`
  - 테스트용: `struct FakeError: LocalizedError` (문구 `"fake failure"`), `final class FakeProvider: TranslationProvider`, `func waitUntil(timeout:_:) async`

- [ ] **Step 1: 테스트 공용 가짜 객체 작성**

`Tests/Fakes.swift`:

```swift
import Foundation
@testable import OnDeviceTranslationSample

struct FakeError: LocalizedError {
    var errorDescription: String? { "fake failure" }
}

final class FakeProvider: TranslationProvider {
    let kind: ProviderKind
    let displayName: String
    var supportedTargets: Set<TargetLanguage>
    var status: LanguagePackStatus
    var result: Result<String, Error>
    var delayNanoseconds: UInt64
    private(set) var translateCallCount = 0

    init(
        kind: ProviderKind,
        supportedTargets: Set<TargetLanguage> = Set(TargetLanguage.allCases),
        status: LanguagePackStatus = .installed,
        result: Result<String, Error> = .success("translated"),
        delayNanoseconds: UInt64 = 0
    ) {
        self.kind = kind
        self.displayName = kind.rawValue
        self.supportedTargets = supportedTargets
        self.status = status
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func supports(_ target: TargetLanguage) -> Bool { supportedTargets.contains(target) }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus { status }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        translateCallCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try result.get()
    }
}

/// Polls `condition` on the main actor until it is true or the timeout expires.
@MainActor
func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`Tests/ProviderTests.swift`:

```swift
import XCTest
@testable import OnDeviceTranslationSample

final class ProviderTests: XCTestCase {
    func test_availableKinds_dependOnAppleAvailability() {
        XCTAssertEqual(ProviderKind.available(isAppleAvailable: true), [.coreML, .apple, .mlKit])
        XCTAssertEqual(ProviderKind.available(isAppleAvailable: false), [.coreML, .mlKit])
    }

    func test_coreML_supportsEnglishOnly() async {
        let provider = CoreMLProvider(loadEngine: { throw FakeError() })

        XCTAssertTrue(provider.supports(.english))
        for target in TargetLanguage.allCases where target != .english {
            XCTAssertFalse(provider.supports(target))
            let status = await provider.packStatus(for: target)
            XCTAssertEqual(status, .unsupported)
        }
        let englishStatus = await provider.packStatus(for: .english)
        XCTAssertEqual(englishStatus, .installed)
    }

    func test_coreML_translateSurfacesEngineLoadFailure() async {
        let provider = CoreMLProvider(loadEngine: { throw FakeError() })

        do {
            _ = try await provider.translate("안녕하세요.", to: .english)
            XCTFail("Expected load failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "fake failure")
        }
    }

    func test_coreML_translatesWithBundledModels() async throws {
        let provider = CoreMLProvider()

        let result = try await provider.translate("안녕하세요.", to: .english)

        XCTAssertTrue(result.lowercased().contains("hello") || result.lowercased().contains("hi"), result)
    }
}
```

- [ ] **Step 3: 재생성 후 실패 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/ProviderTests
```
Expected: 컴파일 실패 — `cannot find type 'TranslationProvider' in scope`

- [ ] **Step 4: 프로토콜 구현**

`Sources/Providers/TranslationProvider.swift`:

```swift
import Foundation

enum ProviderKind: String, CaseIterable {
    case coreML
    case apple
    case mlKit

    /// Engines shown on this device. Apple Translation is used only on iOS 26+.
    static func available(isAppleAvailable: Bool) -> [ProviderKind] {
        isAppleAvailable ? [.coreML, .apple, .mlKit] : [.coreML, .mlKit]
    }
}

enum LanguagePackStatus: Equatable {
    case installed
    case notInstalled
    case downloading
    case unsupported
    case failed(String)
}

/// A Korean-to-target translation engine. Downloading language packs is engine specific
/// and handled by `LanguagePackStore`, not by this protocol.
protocol TranslationProvider: AnyObject {
    var kind: ProviderKind { get }
    var displayName: String { get }
    func supports(_ target: TargetLanguage) -> Bool
    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus
    func translate(_ text: String, to target: TargetLanguage) async throws -> String
}
```

- [ ] **Step 5: CoreMLProvider 구현**

`Sources/Providers/CoreMLProvider.swift`:

```swift
import Foundation
import OnDeviceTranslationEngine

/// Wraps the bundled opus-mt-ko-en Core ML engine (Korean → English only).
final class CoreMLProvider: TranslationProvider {
    let kind = ProviderKind.coreML
    let displayName = "Core ML (opus-mt)"

    private let engineTask: Task<OnDeviceTranslationEngine, Error>

    init(loadEngine: @escaping () throws -> OnDeviceTranslationEngine = CoreMLProvider.loadBundledEngine) {
        // Model compilation is slow, so start loading immediately in the background.
        engineTask = Task.detached(priority: .userInitiated) { try loadEngine() }
    }

    func supports(_ target: TargetLanguage) -> Bool { target == .english }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus {
        supports(target) ? .installed : .unsupported
    }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        guard supports(target) else { throw CoreMLProviderError.unsupportedTarget }
        let engine = try await engineTask.value
        return try await Task.detached(priority: .userInitiated) { try engine.translate(text) }.value
    }

    static func loadBundledEngine() throws -> OnDeviceTranslationEngine {
        let bundle = Bundle.main
        guard let encoderURL = bundle.url(forResource: "encoder", withExtension: "mlmodelc") ?? bundle.url(forResource: "encoder", withExtension: "mlpackage"),
              let decoderURL = bundle.url(forResource: "decoder", withExtension: "mlmodelc") ?? bundle.url(forResource: "decoder", withExtension: "mlpackage"),
              let tokenizerPath = bundle.path(forResource: "source", ofType: "spm"),
              let sourceMapURL = bundle.url(forResource: "source_id_to_vocab_id", withExtension: "json"),
              let targetMapURL = bundle.url(forResource: "target_vocab_id_to_piece", withExtension: "json") else {
            throw CoreMLProviderError.missingResources
        }
        return try OnDeviceTranslationEngine(
            encoderModelURL: encoderURL,
            decoderModelURL: decoderURL,
            tokenizerModelPath: tokenizerPath,
            sourceMapURL: sourceMapURL,
            targetMapURL: targetMapURL
        )
    }
}

enum CoreMLProviderError: LocalizedError {
    case unsupportedTarget
    case missingResources

    var errorDescription: String? {
        switch self {
        case .unsupportedTarget: return "Core ML 모델은 영어만 지원합니다."
        case .missingResources: return "앱 번들에서 Core ML 모델 또는 매핑 파일을 찾을 수 없습니다."
        }
    }
}
```

- [ ] **Step 6: 재생성 후 테스트 통과 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/ProviderTests
```
Expected: `** TEST SUCCEEDED **` (4 tests)

- [ ] **Step 7: Commit**

```bash
git add iOS/OnDeviceTranslationSample
git commit -m "feat: Add TranslationProvider protocol and Core ML provider

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: CardState와 ComparisonViewModel

**Files:**
- Create: `Sources/Comparison/CardState.swift`, `Sources/Comparison/ComparisonViewModel.swift`
- Test: `Tests/ComparisonViewModelTests.swift`

**Interfaces:**
- Consumes: `TranslationProvider`, `ProviderKind`, `LanguagePackStatus` (Task 2), `TargetLanguage` (Task 1), `FakeProvider`, `FakeError` (Task 2 테스트)
- Produces:
  - `enum CardState: Equatable { idle, translating, unsupported, needsDownload, result(text: String, seconds: Double), error(String) }` + `init(packStatus: LanguagePackStatus)` + `var isReplaceableByStatus: Bool`
  - `@MainActor final class ComparisonViewModel: ObservableObject`
    - `init(providers: [TranslationProvider], inputText: String = "")`
    - `@Published var inputText: String`, `@Published private(set) var target: TargetLanguage`, `@Published private(set) var cards: [ProviderKind: CardState]`
    - `let providers: [TranslationProvider]`, `var canTranslate: Bool`, `func state(for kind: ProviderKind) -> CardState`
    - `@discardableResult func select(_ newTarget: TargetLanguage) -> Task<Void, Never>`
    - `func refreshStatuses() async`
    - `@discardableResult func translate() -> Task<Void, Never>?`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/ComparisonViewModelTests.swift`:

```swift
import XCTest
@testable import OnDeviceTranslationSample

@MainActor
final class ComparisonViewModelTests: XCTestCase {
    private func resultText(_ state: CardState) -> String? {
        if case let .result(text, _) = state { return text }
        return nil
    }

    func test_cardState_fromPackStatus() {
        XCTAssertEqual(CardState(packStatus: .installed), .idle)
        XCTAssertEqual(CardState(packStatus: .unsupported), .unsupported)
        XCTAssertEqual(CardState(packStatus: .notInstalled), .needsDownload)
        XCTAssertEqual(CardState(packStatus: .downloading), .needsDownload)
        XCTAssertEqual(CardState(packStatus: .failed("x")), .needsDownload)
    }

    func test_translate_fillsResultForEachProvider() async {
        let coreML = FakeProvider(kind: .coreML, result: .success("A"))
        let mlKit = FakeProvider(kind: .mlKit, result: .success("B"))
        let viewModel = ComparisonViewModel(providers: [coreML, mlKit], inputText: "안녕하세요")

        await viewModel.translate()?.value

        XCTAssertEqual(resultText(viewModel.state(for: .coreML)), "A")
        XCTAssertEqual(resultText(viewModel.state(for: .mlKit)), "B")
    }

    func test_translate_marksUnsupportedWithoutCallingProvider() async {
        let coreML = FakeProvider(kind: .coreML, supportedTargets: [.english])
        let viewModel = ComparisonViewModel(providers: [coreML], inputText: "안녕하세요")
        await viewModel.select(.japanese).value

        await viewModel.translate()?.value

        XCTAssertEqual(viewModel.state(for: .coreML), .unsupported)
        XCTAssertEqual(coreML.translateCallCount, 0)
    }

    func test_translate_needsDownloadWhenPackMissing() async {
        let mlKit = FakeProvider(kind: .mlKit, status: .notInstalled)
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")

        await viewModel.translate()?.value

        XCTAssertEqual(viewModel.state(for: .mlKit), .needsDownload)
        XCTAssertEqual(mlKit.translateCallCount, 0)
    }

    func test_translate_oneFailureDoesNotAffectOthers() async {
        let coreML = FakeProvider(kind: .coreML, result: .failure(FakeError()))
        let mlKit = FakeProvider(kind: .mlKit, result: .success("B"))
        let viewModel = ComparisonViewModel(providers: [coreML, mlKit], inputText: "안녕하세요")

        await viewModel.translate()?.value

        XCTAssertEqual(viewModel.state(for: .coreML), .error("fake failure"))
        XCTAssertEqual(resultText(viewModel.state(for: .mlKit)), "B")
    }

    func test_translate_whitespaceOnlyInput_doesNothing() {
        let coreML = FakeProvider(kind: .coreML)
        let viewModel = ComparisonViewModel(providers: [coreML], inputText: "  \n\t ")

        XCTAssertFalse(viewModel.canTranslate)
        XCTAssertNil(viewModel.translate())
        XCTAssertEqual(coreML.translateCallCount, 0)
        XCTAssertEqual(viewModel.state(for: .coreML), .idle)
    }

    func test_selectDuringTranslation_discardsStaleResult() async {
        let mlKit = FakeProvider(kind: .mlKit, result: .success("stale"), delayNanoseconds: 300_000_000)
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")

        let translation = viewModel.translate()
        await waitUntil { viewModel.state(for: .mlKit) == .translating }
        await viewModel.select(.japanese).value
        await translation?.value

        XCTAssertEqual(viewModel.target, .japanese)
        XCTAssertEqual(viewModel.state(for: .mlKit), .idle)
    }

    func test_refreshStatuses_keepsFinishedResult() async {
        let mlKit = FakeProvider(kind: .mlKit, result: .success("B"))
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")
        await viewModel.translate()?.value

        mlKit.status = .notInstalled
        await viewModel.refreshStatuses()

        XCTAssertEqual(resultText(viewModel.state(for: .mlKit)), "B")
    }

    func test_refreshStatuses_updatesNeedsDownloadAfterInstall() async {
        let mlKit = FakeProvider(kind: .mlKit, status: .notInstalled)
        let viewModel = ComparisonViewModel(providers: [mlKit], inputText: "안녕하세요")

        await viewModel.refreshStatuses()
        XCTAssertEqual(viewModel.state(for: .mlKit), .needsDownload)

        mlKit.status = .installed
        await viewModel.refreshStatuses()
        XCTAssertEqual(viewModel.state(for: .mlKit), .idle)
    }
}
```

- [ ] **Step 2: 재생성 후 실패 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/ComparisonViewModelTests
```
Expected: 컴파일 실패 — `cannot find type 'CardState' in scope`

- [ ] **Step 3: CardState 구현**

`Sources/Comparison/CardState.swift`:

```swift
import Foundation

/// What a result card shows for one engine.
enum CardState: Equatable {
    case idle
    case translating
    case unsupported
    case needsDownload
    case result(text: String, seconds: Double)
    case error(String)

    /// Card state before translating, derived from the language pack status.
    init(packStatus: LanguagePackStatus) {
        switch packStatus {
        case .installed: self = .idle
        case .unsupported: self = .unsupported
        case .notInstalled, .downloading, .failed: self = .needsDownload
        }
    }

    /// Whether a language pack status refresh may replace this state.
    /// Results and errors of a finished translation are kept.
    var isReplaceableByStatus: Bool {
        switch self {
        case .idle, .unsupported, .needsDownload: return true
        case .translating, .result, .error: return false
        }
    }
}
```

- [ ] **Step 4: ComparisonViewModel 구현**

`Sources/Comparison/ComparisonViewModel.swift`:

```swift
import Foundation

@MainActor
final class ComparisonViewModel: ObservableObject {
    @Published var inputText: String
    @Published private(set) var target: TargetLanguage = .english
    @Published private(set) var cards: [ProviderKind: CardState] = [:]

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
        let task = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                for provider in providers {
                    group.addTask {
                        await self?.run(provider, text: text, target: target, generation: generation)
                    }
                }
            }
        }
        translationTask = task
        return task
    }

    private func run(_ provider: TranslationProvider, text: String, target: TargetLanguage, generation: Int) async {
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
            let result = try await provider.translate(text, to: target)
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
```

- [ ] **Step 5: 재생성 후 테스트 통과 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/ComparisonViewModelTests
```
Expected: `** TEST SUCCEEDED **` (9 tests)

- [ ] **Step 6: Commit**

```bash
git add iOS/OnDeviceTranslationSample
git commit -m "feat: Add comparison view model running engines concurrently

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: MLKitProvider와 AppleProvider

**Files:**
- Create: `Sources/Providers/MLKitProvider.swift`, `Sources/Providers/AppleProvider.swift`
- Test: `Tests/MLKitMappingTests.swift`

**Interfaces:**
- Consumes: `TranslationProvider`, `ProviderKind`, `LanguagePackStatus` (Task 2), `TargetLanguage`, `PackLanguage`, `SourceLanguage` (Task 1)
- Produces:
  - `protocol MLKitPackManaging: AnyObject { func isDownloaded(_ language: PackLanguage) -> Bool; func download(_ language: PackLanguage); func delete(_ language: PackLanguage) async throws }`
  - `final class MLKitProvider: TranslationProvider, MLKitPackManaging` — `init()`, `static func remoteModel(_ language: PackLanguage) -> TranslateRemoteModel`
  - `extension PackLanguage { var mlKitLanguage: TranslateLanguage; init?(mlKitLanguage: TranslateLanguage) }`
  - `enum MLKitProviderError: LocalizedError { emptyResult, downloadFailed }`
  - `@available(iOS 26.0, *) final class AppleProvider: TranslationProvider` — `init()`, `static let source: Locale.Language`, `static func language(for target: TargetLanguage) -> Locale.Language`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/MLKitMappingTests.swift`:

```swift
import XCTest
import MLKitTranslate
@testable import OnDeviceTranslationSample

final class MLKitMappingTests: XCTestCase {
    func test_packLanguages_mapToMLKitLanguages() {
        XCTAssertEqual(PackLanguage.allCases.map(\.mlKitLanguage),
                       [.korean, .english, .vietnamese, .indonesian, .japanese, .chinese])
    }

    func test_mlKitLanguage_roundTrips() {
        for language in PackLanguage.allCases {
            XCTAssertEqual(PackLanguage(mlKitLanguage: language.mlKitLanguage), language)
        }
        XCTAssertNil(PackLanguage(mlKitLanguage: .german))
    }

    func test_remoteModel_usesMappedLanguage() {
        XCTAssertEqual(MLKitProvider.remoteModel(.japanese).language, .japanese)
    }

    func test_mlKit_supportsAllTargets() {
        let provider = MLKitProvider()
        XCTAssertTrue(TargetLanguage.allCases.allSatisfy(provider.supports))
    }

    func test_appleLanguages() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Apple Translation requires iOS 26") }
        XCTAssertEqual(AppleProvider.source.languageCode?.identifier, "ko")
        let chinese = AppleProvider.language(for: .chineseSimplified)
        XCTAssertEqual(chinese.languageCode?.identifier, "zh")
        XCTAssertEqual(chinese.script?.identifier, "Hans")
        XCTAssertEqual(AppleProvider.language(for: .vietnamese).languageCode?.identifier, "vi")
    }
}
```

- [ ] **Step 2: 재생성 후 실패 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/MLKitMappingTests
```
Expected: 컴파일 실패 — `value of type 'PackLanguage' has no member 'mlKitLanguage'`

- [ ] **Step 3: MLKitProvider 구현**

`Sources/Providers/MLKitProvider.swift`:

```swift
import Foundation
import MLKitTranslate

/// Model download/delete operations used by `LanguagePackStore` (abstracted for tests).
protocol MLKitPackManaging: AnyObject {
    func isDownloaded(_ language: PackLanguage) -> Bool
    /// Starts a download. Completion is reported through ML Kit download notifications.
    func download(_ language: PackLanguage)
    func delete(_ language: PackLanguage) async throws
}

final class MLKitProvider: TranslationProvider, MLKitPackManaging {
    let kind = ProviderKind.mlKit
    let displayName = "ML Kit"

    private let modelManager = ModelManager.modelManager()
    private let lock = NSLock()
    /// Translators are retained so in-flight translations are not deallocated.
    private var translators: [TargetLanguage: Translator] = [:]

    func supports(_ target: TargetLanguage) -> Bool { true }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus {
        isDownloaded(.korean) && isDownloaded(target.packLanguage) ? .installed : .notInstalled
    }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        let translator = translator(for: target)
        return try await withCheckedThrowingContinuation { continuation in
            translator.translate(text) { result, error in
                if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: error ?? MLKitProviderError.emptyResult)
                }
            }
        }
    }

    func isDownloaded(_ language: PackLanguage) -> Bool {
        modelManager.isModelDownloaded(Self.remoteModel(language))
    }

    func download(_ language: PackLanguage) {
        let conditions = ModelDownloadConditions(allowsCellularAccess: true, allowsBackgroundDownloading: true)
        _ = modelManager.download(Self.remoteModel(language), conditions: conditions)
    }

    func delete(_ language: PackLanguage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            modelManager.deleteDownloadedModel(Self.remoteModel(language)) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    static func remoteModel(_ language: PackLanguage) -> TranslateRemoteModel {
        TranslateRemoteModel.translateRemoteModel(language: language.mlKitLanguage)
    }

    private func translator(for target: TargetLanguage) -> Translator {
        lock.lock()
        defer { lock.unlock() }
        if let translator = translators[target] {
            return translator
        }
        let options = TranslatorOptions(sourceLanguage: .korean, targetLanguage: target.packLanguage.mlKitLanguage)
        let translator = Translator.translator(options: options)
        translators[target] = translator
        return translator
    }
}

extension PackLanguage {
    var mlKitLanguage: TranslateLanguage {
        switch self {
        case .korean: return .korean
        case .english: return .english
        case .vietnamese: return .vietnamese
        case .indonesian: return .indonesian
        case .japanese: return .japanese
        case .chineseSimplified: return .chinese
        }
    }

    init?(mlKitLanguage: TranslateLanguage) {
        guard let match = PackLanguage.allCases.first(where: { $0.mlKitLanguage == mlKitLanguage }) else {
            return nil
        }
        self = match
    }
}

enum MLKitProviderError: LocalizedError {
    case emptyResult
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .emptyResult: return "ML Kit이 빈 결과를 반환했습니다."
        case .downloadFailed: return "언어팩 다운로드에 실패했습니다."
        }
    }
}
```

- [ ] **Step 4: AppleProvider 구현**

`Sources/Providers/AppleProvider.swift`:

```swift
import Foundation
import Translation

/// Apple's on-device Translation framework. Translation requires the language pair to be installed;
/// downloads are requested through `AppleDownloadHost`.
@available(iOS 26.0, *)
final class AppleProvider: TranslationProvider {
    let kind = ProviderKind.apple
    let displayName = "Apple Translation"

    static let source = Locale.Language(identifier: SourceLanguage.appleLanguageCode)

    static func language(for target: TargetLanguage) -> Locale.Language {
        Locale.Language(identifier: target.appleLanguageCode)
    }

    private let availability = LanguageAvailability()

    /// Actual support is reported by `packStatus` (`.unsupported`), not hard-coded here.
    func supports(_ target: TargetLanguage) -> Bool { true }

    func packStatus(for target: TargetLanguage) async -> LanguagePackStatus {
        let status = await availability.status(from: Self.source, to: Self.language(for: target))
        switch status {
        case .installed: return .installed
        case .supported: return .notInstalled
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    func translate(_ text: String, to target: TargetLanguage) async throws -> String {
        let session = TranslationSession(installedSource: Self.source, target: Self.language(for: target))
        return try await session.translate(text).targetText
    }
}
```

- [ ] **Step 5: 재생성 후 테스트 통과 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/MLKitMappingTests
```
Expected: `** TEST SUCCEEDED **` (5 tests)

- [ ] **Step 6: Commit**

```bash
git add iOS/OnDeviceTranslationSample
git commit -m "feat: Add ML Kit and Apple Translation providers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: LanguagePackStore와 언어팩 화면

**Files:**
- Create: `Sources/LanguagePacks/LanguagePackStore.swift`, `PackStatusControl.swift`, `AppleDownloadHost.swift`, `LanguagePacksView.swift`
- Modify: `Tests/Fakes.swift` (FakeMLKitManager 추가)
- Test: `Tests/LanguagePackStoreTests.swift`

**Interfaces:**
- Consumes: `MLKitPackManaging`, `MLKitProvider.remoteModel`, `PackLanguage(mlKitLanguage:)`, `MLKitProviderError.downloadFailed`, `AppleProvider.source`, `AppleProvider.language(for:)` (Task 4), `TranslationProvider`, `LanguagePackStatus`, `ProviderKind` (Task 2)
- Produces:
  - `struct AppleDownloadRequest: Equatable { let id: UUID; let target: TargetLanguage }`
  - `@MainActor final class LanguagePackStore: ObservableObject`
    - `init(mlKit: MLKitPackManaging, apple: TranslationProvider?, notificationCenter: NotificationCenter = .default)`
    - `@Published private(set) var appleDownloadRequest: AppleDownloadRequest?`, `appleDownloadError: String?`, `revision: Int`
    - `var isAppleAvailable: Bool`, `func mlKitStatus(_ language: PackLanguage) -> LanguagePackStatus`, `func appleStatus(_ target: TargetLanguage) -> LanguagePackStatus`, `func isDownloading(_ kind: ProviderKind, _ target: TargetLanguage) -> Bool`
    - `func refresh() async`, `func downloadMLKit(_ language: PackLanguage)`, `func deleteMLKit(_ language: PackLanguage) async`, `func requestDownload(_ kind: ProviderKind, for target: TargetLanguage)`, `func requestAppleDownload(_ target: TargetLanguage)`, `func appleDownloadDidFinish(error: Error?) async`, `func handleDownloadResult(language: PackLanguage?, error: Error?)`
  - `struct PackStatusControl: View` — `init(status: LanguagePackStatus, onDownload: (() -> Void)? = nil, onDelete: (() -> Void)? = nil)`
  - `struct AppleDownloadHost: ViewModifier` — `init(store: LanguagePackStore, isActive: Bool)`
  - `struct LanguagePacksView: View` — `init(store: LanguagePackStore)`

- [ ] **Step 1: FakeMLKitManager 추가**

`Tests/Fakes.swift` 끝에 추가:

```swift
final class FakeMLKitManager: MLKitPackManaging {
    var downloaded: Set<PackLanguage> = []
    var deleteError: Error?
    private(set) var downloadRequests: [PackLanguage] = []

    func isDownloaded(_ language: PackLanguage) -> Bool { downloaded.contains(language) }

    func download(_ language: PackLanguage) { downloadRequests.append(language) }

    func delete(_ language: PackLanguage) async throws {
        if let deleteError = deleteError { throw deleteError }
        downloaded.remove(language)
    }
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`Tests/LanguagePackStoreTests.swift`:

```swift
import XCTest
import MLKitTranslate
@testable import OnDeviceTranslationSample

@MainActor
final class LanguagePackStoreTests: XCTestCase {
    private var mlKit: FakeMLKitManager!
    private var center: NotificationCenter!

    override func setUp() {
        super.setUp()
        mlKit = FakeMLKitManager()
        center = NotificationCenter()
    }

    private func makeStore(apple: TranslationProvider? = nil) -> LanguagePackStore {
        LanguagePackStore(mlKit: mlKit, apple: apple, notificationCenter: center)
    }

    func test_refresh_readsMLKitModels() async {
        mlKit.downloaded = [.korean, .english]
        let store = makeStore()

        await store.refresh()

        XCTAssertEqual(store.mlKitStatus(.korean), .installed)
        XCTAssertEqual(store.mlKitStatus(.english), .installed)
        XCTAssertEqual(store.mlKitStatus(.japanese), .notInstalled)
        XCTAssertFalse(store.isAppleAvailable)
    }

    func test_requestDownload_skipsInstalledAndInFlight() async {
        mlKit.downloaded = [.korean]
        let store = makeStore()
        await store.refresh()

        store.requestDownload(.mlKit, for: .japanese)
        store.requestDownload(.mlKit, for: .japanese)

        XCTAssertEqual(mlKit.downloadRequests, [.japanese])
        XCTAssertEqual(store.mlKitStatus(.japanese), .downloading)
        XCTAssertTrue(store.isDownloading(.mlKit, .japanese))
    }

    func test_handleDownloadResult_marksInstalledOrFailed() async {
        let store = makeStore()
        await store.refresh()
        store.downloadMLKit(.japanese)
        store.downloadMLKit(.vietnamese)

        store.handleDownloadResult(language: .japanese, error: nil)
        store.handleDownloadResult(language: .vietnamese, error: FakeError())

        XCTAssertEqual(store.mlKitStatus(.japanese), .installed)
        XCTAssertEqual(store.mlKitStatus(.vietnamese), .failed("fake failure"))
    }

    func test_refresh_keepsFailureUntilDownloaded() async {
        let store = makeStore()
        store.downloadMLKit(.vietnamese)
        store.handleDownloadResult(language: .vietnamese, error: FakeError())

        await store.refresh()
        XCTAssertEqual(store.mlKitStatus(.vietnamese), .failed("fake failure"))

        mlKit.downloaded = [.vietnamese]
        await store.refresh()
        XCTAssertEqual(store.mlKitStatus(.vietnamese), .installed)
    }

    func test_downloadNotification_updatesStatus() async {
        let store = makeStore()
        store.downloadMLKit(.japanese)

        center.post(name: .mlkitModelDownloadDidSucceed, object: nil,
                    userInfo: [ModelDownloadUserInfoKey.remoteModel.rawValue: MLKitProvider.remoteModel(.japanese)])
        await waitUntil { store.mlKitStatus(.japanese) == .installed }

        XCTAssertEqual(store.mlKitStatus(.japanese), .installed)
    }

    func test_deleteMLKit_successAndFailure() async {
        mlKit.downloaded = [.japanese, .english]
        let store = makeStore()
        await store.refresh()

        await store.deleteMLKit(.japanese)
        XCTAssertEqual(store.mlKitStatus(.japanese), .notInstalled)

        mlKit.deleteError = FakeError()
        await store.deleteMLKit(.english)
        XCTAssertEqual(store.mlKitStatus(.english), .failed("fake failure"))
    }

    func test_appleDownloadRequest_isSingleAndClearedOnFinish() async {
        let apple = FakeProvider(kind: .apple, status: .notInstalled)
        let store = makeStore(apple: apple)
        await store.refresh()
        XCTAssertTrue(store.isAppleAvailable)
        XCTAssertEqual(store.appleStatus(.japanese), .notInstalled)

        store.requestDownload(.apple, for: .japanese)
        store.requestAppleDownload(.vietnamese)
        XCTAssertEqual(store.appleDownloadRequest?.target, .japanese)
        XCTAssertTrue(store.isDownloading(.apple, .japanese))

        apple.status = .installed
        await store.appleDownloadDidFinish(error: nil)
        XCTAssertNil(store.appleDownloadRequest)
        XCTAssertNil(store.appleDownloadError)
        XCTAssertEqual(store.appleStatus(.japanese), .installed)
    }

    func test_appleDownloadFailure_isReported() async {
        let store = makeStore(apple: FakeProvider(kind: .apple, status: .notInstalled))
        store.requestAppleDownload(.japanese)

        await store.appleDownloadDidFinish(error: FakeError())

        XCTAssertNil(store.appleDownloadRequest)
        XCTAssertEqual(store.appleDownloadError, "fake failure")
    }
}
```

- [ ] **Step 3: 재생성 후 실패 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/LanguagePackStoreTests
```
Expected: 컴파일 실패 — `cannot find 'LanguagePackStore' in scope`

- [ ] **Step 4: LanguagePackStore 구현**

`Sources/LanguagePacks/LanguagePackStore.swift`:

```swift
import Foundation
import MLKitTranslate

struct AppleDownloadRequest: Equatable {
    let id = UUID()
    let target: TargetLanguage
}

/// Language pack status for every engine, shared by the comparison and language pack screens.
@MainActor
final class LanguagePackStore: ObservableObject {
    @Published private(set) var mlKitStatuses: [PackLanguage: LanguagePackStatus] = [:]
    @Published private(set) var appleStatuses: [TargetLanguage: LanguagePackStatus] = [:]
    @Published private(set) var appleDownloadRequest: AppleDownloadRequest?
    @Published private(set) var appleDownloadError: String?
    /// Bumped whenever any status changes so the comparison screen can re-check its cards.
    @Published private(set) var revision = 0

    private let mlKit: MLKitPackManaging
    private let apple: TranslationProvider?
    private var observers: [NSObjectProtocol] = []

    var isAppleAvailable: Bool { apple != nil }

    init(mlKit: MLKitPackManaging, apple: TranslationProvider?, notificationCenter: NotificationCenter = .default) {
        self.mlKit = mlKit
        self.apple = apple
        observers = [
            notificationCenter.addObserver(forName: .mlkitModelDownloadDidSucceed, object: nil, queue: .main) { [weak self] notification in
                let language = Self.packLanguage(from: notification)
                Task { @MainActor in self?.handleDownloadResult(language: language, error: nil) }
            },
            notificationCenter.addObserver(forName: .mlkitModelDownloadDidFail, object: nil, queue: .main) { [weak self] notification in
                let language = Self.packLanguage(from: notification)
                let error = notification.userInfo?[ModelDownloadUserInfoKey.error.rawValue] as? Error
                Task { @MainActor in self?.handleDownloadResult(language: language, error: error ?? MLKitProviderError.downloadFailed) }
            },
        ]
    }

    func mlKitStatus(_ language: PackLanguage) -> LanguagePackStatus {
        mlKitStatuses[language] ?? .notInstalled
    }

    func appleStatus(_ target: TargetLanguage) -> LanguagePackStatus {
        appleStatuses[target] ?? .notInstalled
    }

    func isDownloading(_ kind: ProviderKind, _ target: TargetLanguage) -> Bool {
        switch kind {
        case .mlKit:
            return mlKitStatus(.korean) == .downloading || mlKitStatus(target.packLanguage) == .downloading
        case .apple:
            return appleDownloadRequest?.target == target
        case .coreML:
            return false
        }
    }

    func refresh() async {
        for language in PackLanguage.allCases {
            let current = mlKitStatus(language)
            if current == .downloading { continue }
            if mlKit.isDownloaded(language) {
                mlKitStatuses[language] = .installed
            } else if case .failed = current {
                continue // keep the failure visible until the model is actually downloaded
            } else {
                mlKitStatuses[language] = .notInstalled
            }
        }
        if let apple = apple {
            for target in TargetLanguage.allCases {
                appleStatuses[target] = await apple.packStatus(for: target)
            }
        }
        revision += 1
    }

    func downloadMLKit(_ language: PackLanguage) {
        switch mlKitStatus(language) {
        case .downloading, .installed:
            return
        case .notInstalled, .unsupported, .failed:
            break
        }
        mlKitStatuses[language] = .downloading
        mlKit.download(language)
        revision += 1
    }

    func deleteMLKit(_ language: PackLanguage) async {
        do {
            try await mlKit.delete(language)
            mlKitStatuses[language] = .notInstalled
        } catch {
            mlKitStatuses[language] = .failed(error.localizedDescription)
        }
        revision += 1
    }

    /// Download request from a result card: ML Kit needs both the Korean and the target model.
    func requestDownload(_ kind: ProviderKind, for target: TargetLanguage) {
        switch kind {
        case .mlKit:
            downloadMLKit(.korean)
            downloadMLKit(target.packLanguage)
        case .apple:
            requestAppleDownload(target)
        case .coreML:
            break
        }
    }

    /// Asks `AppleDownloadHost` to show the system download prompt. One request at a time.
    func requestAppleDownload(_ target: TargetLanguage) {
        guard isAppleAvailable, appleDownloadRequest == nil else { return }
        appleDownloadError = nil
        appleDownloadRequest = AppleDownloadRequest(target: target)
        revision += 1
    }

    func appleDownloadDidFinish(error: Error?) async {
        appleDownloadRequest = nil
        appleDownloadError = error?.localizedDescription
        await refresh()
    }

    func handleDownloadResult(language: PackLanguage?, error: Error?) {
        guard let language = language else { return }
        if let error = error {
            mlKitStatuses[language] = .failed(error.localizedDescription)
        } else {
            mlKitStatuses[language] = .installed
        }
        revision += 1
    }

    nonisolated private static func packLanguage(from notification: Notification) -> PackLanguage? {
        guard let model = notification.userInfo?[ModelDownloadUserInfoKey.remoteModel.rawValue] as? TranslateRemoteModel else {
            return nil
        }
        return PackLanguage(mlKitLanguage: model.language)
    }
}
```

- [ ] **Step 5: 재생성 후 스토어 테스트 통과 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet -only-testing:OnDeviceTranslationSampleTests/LanguagePackStoreTests
```
Expected: `** TEST SUCCEEDED **` (8 tests)

- [ ] **Step 6: 언어팩 상태 컨트롤 작성**

`Sources/LanguagePacks/PackStatusControl.swift`:

```swift
import SwiftUI

/// Status label with download/delete buttons for one engine's language pack.
struct PackStatusControl: View {
    let status: LanguagePackStatus
    var onDownload: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        switch status {
        case .installed:
            HStack(spacing: 8) {
                Label("설치됨", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                if let onDelete = onDelete {
                    Button("삭제", role: .destructive, action: onDelete)
                }
            }
        case .notInstalled:
            if let onDownload = onDownload {
                Button("받기", action: onDownload)
            } else {
                Text("미설치").foregroundColor(.secondary)
            }
        case .downloading:
            HStack(spacing: 6) {
                ProgressView()
                Text("다운로드 중").foregroundColor(.secondary)
            }
        case .unsupported:
            Text("미지원").foregroundColor(.secondary)
        case .failed(let message):
            VStack(alignment: .trailing, spacing: 2) {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
                if let onDownload = onDownload {
                    Button("다시 받기", action: onDownload)
                }
            }
        }
    }
}
```

- [ ] **Step 7: Apple 다운로드 호스트 작성**

`Sources/LanguagePacks/AppleDownloadHost.swift`:

```swift
import SwiftUI
import Translation

/// Shows Apple's language download prompt for `LanguagePackStore.appleDownloadRequest`.
/// Only one host may be active at a time: the comparison screen deactivates its host
/// while the language pack sheet (which has its own host) is presented.
struct AppleDownloadHost: ViewModifier {
    @ObservedObject var store: LanguagePackStore
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.modifier(AppleDownloadTask(store: store, isActive: isActive))
        } else {
            content
        }
    }
}

@available(iOS 26.0, *)
private struct AppleDownloadTask: ViewModifier {
    @ObservedObject var store: LanguagePackStore
    let isActive: Bool

    func body(content: Content) -> some View {
        content.translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
                await store.appleDownloadDidFinish(error: nil)
            } catch {
                await store.appleDownloadDidFinish(error: error)
            }
        }
    }

    /// A new non-nil configuration triggers the task; it returns to nil when the request finishes.
    private var configuration: TranslationSession.Configuration? {
        guard isActive, let request = store.appleDownloadRequest else { return nil }
        return TranslationSession.Configuration(source: AppleProvider.source, target: AppleProvider.language(for: request.target))
    }
}
```

- [ ] **Step 8: 언어팩 화면 작성**

`Sources/LanguagePacks/LanguagePacksView.swift`:

```swift
import SwiftUI

struct LanguagePacksView: View {
    @ObservedObject var store: LanguagePackStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(footer: Text(footerText)) {
                    ForEach(PackLanguage.allCases) { language in
                        row(for: language)
                    }
                }
                if let error = store.appleDownloadError {
                    Section {
                        Text("Apple 언어팩 요청 실패: \(error)").foregroundColor(.red)
                    }
                }
            }
            .refreshable { await store.refresh() }
            .navigationTitle("언어팩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .task { await store.refresh() }
        .modifier(AppleDownloadHost(store: store, isActive: true))
    }

    private func row(for language: PackLanguage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(language.displayName).font(.headline)
            if store.isAppleAvailable {
                HStack {
                    Text("Apple").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if let target = language.targetLanguage {
                        PackStatusControl(
                            status: store.isDownloading(.apple, target) ? .downloading : store.appleStatus(target),
                            onDownload: { store.requestAppleDownload(target) }
                        )
                    } else {
                        // Apple language packs are per pair (Korean → target), shown on the target rows.
                        Text("—").foregroundColor(.secondary)
                    }
                }
            }
            HStack {
                Text("ML Kit").font(.caption).foregroundColor(.secondary)
                Spacer()
                PackStatusControl(
                    status: store.mlKitStatus(language),
                    onDownload: { store.downloadMLKit(language) },
                    onDelete: { Task { await store.deleteMLKit(language) } }
                )
            }
        }
        .buttonStyle(.borderless) // keep each button tappable on its own inside a List row
        .padding(.vertical, 4)
    }

    private var footerText: String {
        let mlKitNote = "ML Kit 언어팩은 언어당 약 30MB이며 셀룰러 데이터로도 받습니다."
        return store.isAppleAvailable ? mlKitNote + " Apple 언어팩 삭제는 설정 앱에서 할 수 있습니다." : mlKitNote
    }
}
```

- [ ] **Step 9: 재생성 후 전체 테스트·빌드 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet
```
Expected: `** TEST SUCCEEDED **` (Task 1~5 테스트 전부)

- [ ] **Step 10: Commit**

```bash
git add iOS/OnDeviceTranslationSample
git commit -m "feat: Add language pack store and management screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 비교 화면과 앱 조립

**Files:**
- Create: `Sources/AppDependencies.swift`, `Sources/Comparison/ResultCard.swift`, `Sources/Comparison/ComparisonView.swift`
- Modify: `Sources/OnDeviceTranslationSampleApp.swift`
- Delete: `Sources/ContentView.swift`

**Interfaces:**
- Consumes: `ComparisonViewModel`, `CardState` (Task 3), `LanguagePackStore`, `AppleDownloadHost`, `LanguagePacksView` (Task 5), `CoreMLProvider` (Task 2), `MLKitProvider`, `AppleProvider` (Task 4), `ProviderKind.available(isAppleAvailable:)` (Task 2)
- Produces:
  - `@MainActor struct AppDependencies { let viewModel: ComparisonViewModel; let packStore: LanguagePackStore; static func make() -> AppDependencies }`
  - `struct ResultCard: View` — `init(title: String, state: CardState, isDownloading: Bool, onDownload: @escaping () -> Void)`
  - `struct ComparisonView: View` — `init(viewModel: ComparisonViewModel, packStore: LanguagePackStore)`

- [ ] **Step 1: 앱 조립 코드 작성**

`Sources/AppDependencies.swift`:

```swift
import Foundation

/// Builds the engines for this OS version and the objects shared by the screens.
@MainActor
struct AppDependencies {
    let viewModel: ComparisonViewModel
    let packStore: LanguagePackStore

    static let sampleText = "안녕하세요. 오늘 날씨가 아주 좋네요. 만나서 반갑습니다."

    static func make() -> AppDependencies {
        let mlKit = MLKitProvider()
        var apple: TranslationProvider?
        if #available(iOS 26.0, *) {
            apple = AppleProvider()
        }

        var byKind: [ProviderKind: TranslationProvider] = [.coreML: CoreMLProvider(), .mlKit: mlKit]
        byKind[.apple] = apple
        let providers = ProviderKind.available(isAppleAvailable: apple != nil).compactMap { byKind[$0] }

        return AppDependencies(
            viewModel: ComparisonViewModel(providers: providers, inputText: sampleText),
            packStore: LanguagePackStore(mlKit: mlKit, apple: apple)
        )
    }
}
```

- [ ] **Step 2: 결과 카드 작성**

`Sources/Comparison/ResultCard.swift`:

```swift
import SwiftUI

struct ResultCard: View {
    let title: String
    let state: CardState
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if case let .result(_, seconds) = state {
                    Text(String(format: "%.2fs", seconds))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Text("번역 결과가 여기에 표시됩니다").foregroundColor(.secondary)
        case .translating:
            HStack(spacing: 8) {
                ProgressView()
                Text("번역 중…").foregroundColor(.secondary)
            }
        case .unsupported:
            Text("이 언어는 지원하지 않습니다").foregroundColor(.secondary)
        case .needsDownload:
            if isDownloading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("언어팩 다운로드 중…").foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("언어팩이 필요합니다").foregroundColor(.orange)
                    Spacer()
                    Button("다운로드", action: onDownload)
                }
            }
        case .result(let text, _):
            Text(text).textSelection(.enabled)
        case .error(let message):
            Text(message).foregroundColor(.red)
        }
    }
}
```

- [ ] **Step 3: 비교 화면 작성**

`Sources/Comparison/ComparisonView.swift`:

```swift
import SwiftUI

struct ComparisonView: View {
    @ObservedObject var viewModel: ComparisonViewModel
    @ObservedObject var packStore: LanguagePackStore
    @State private var showingLanguagePacks = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("한국어 (원문)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    TextEditor(text: $viewModel.inputText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    Picker("대상 언어", selection: targetBinding) {
                        ForEach(TargetLanguage.allCases) { language in
                            Text(language.shortLabel).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.translate()
                    } label: {
                        Text("\(viewModel.target.displayName)로 번역")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canTranslate ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.canTranslate)

                    ForEach(viewModel.providers, id: \.kind) { provider in
                        ResultCard(
                            title: provider.displayName,
                            state: viewModel.state(for: provider.kind),
                            isDownloading: packStore.isDownloading(provider.kind, viewModel.target),
                            onDownload: { packStore.requestDownload(provider.kind, for: viewModel.target) }
                        )
                    }

                    if let error = packStore.appleDownloadError {
                        Text("Apple 언어팩 요청 실패: \(error)")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("On-Device Translator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("언어팩") { showingLanguagePacks = true }
                }
            }
            .sheet(isPresented: $showingLanguagePacks) {
                LanguagePacksView(store: packStore)
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await packStore.refresh()
            await viewModel.refreshStatuses()
        }
        .onChange(of: packStore.revision) { _ in
            Task { await viewModel.refreshStatuses() }
        }
        // The language pack sheet hosts its own prompt while it is shown.
        .modifier(AppleDownloadHost(store: packStore, isActive: !showingLanguagePacks))
    }

    private var targetBinding: Binding<TargetLanguage> {
        Binding(get: { viewModel.target }, set: { viewModel.select($0) })
    }
}
```

- [ ] **Step 4: 앱 진입점 교체와 ContentView 삭제**

`Sources/OnDeviceTranslationSampleApp.swift` 전체를 다음으로 교체:

```swift
import SwiftUI

@main
struct OnDeviceTranslationSampleApp: App {
    @StateObject private var viewModel: ComparisonViewModel
    @StateObject private var packStore: LanguagePackStore

    init() {
        let dependencies = AppDependencies.make()
        _viewModel = StateObject(wrappedValue: dependencies.viewModel)
        _packStore = StateObject(wrappedValue: dependencies.packStore)
    }

    var body: some Scene {
        WindowGroup {
            ComparisonView(viewModel: viewModel, packStore: packStore)
        }
    }
}
```

Run: `git rm iOS/OnDeviceTranslationSample/Sources/ContentView.swift`

- [ ] **Step 5: 재생성 후 전체 테스트 통과 확인**

Run:
```bash
./generate.sh
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: 기기에 설치해 비교 흐름 확인**

Run:
```bash
xcodebuild build -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -derivedDataPath build -allowProvisioningUpdates -quiet
xcrun devicectl device install app --device DA312C82-BD17-5691-B4EC-3DCA4E039104 build/Build/Products/Debug-iphoneos/OnDeviceTranslationSample.app
xcrun devicectl device process launch --device DA312C82-BD17-5691-B4EC-3DCA4E039104 com.brownsoo.OnDeviceTranslationSample
```

기기(iOS 27)에서 확인 (mobile-mcp 도구로 조작하거나, 시스템 동의 시트는 사용자에게 탭을 요청):
1. 카드 3개(Core ML, Apple Translation, ML Kit)가 보인다.
2. EN으로 번역 → Core ML은 결과+시간, Apple/ML Kit은 언어팩이 없으면 "언어팩이 필요합니다 [다운로드]".
3. ML Kit 카드 [다운로드] → "언어팩 다운로드 중…" → 완료 후 [번역] → ML Kit 결과 표시.
4. Apple 카드 [다운로드] → 시스템 다운로드 시트 → 동의 → 상태 갱신 후 [번역] → Apple 결과 표시.
5. JA 선택 → Core ML 카드 "이 언어는 지원하지 않습니다".
6. 번역 중 VI로 전환 → 이전 결과가 나타나지 않는다.
7. [언어팩] → 목록에서 ML Kit 일본어 [받기]/[삭제], Apple 행 [받기] 시 시트가 한 번만 뜬다.

- [ ] **Step 7: Commit**

```bash
git add -A iOS/OnDeviceTranslationSample
git commit -m "feat: Add comparison screen for Core ML, Apple and ML Kit translations

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: README 갱신과 최종 검증

**Files:**
- Modify: `iOS/OnDeviceTranslationSample/README.md` (전체 교체)

**Interfaces:**
- Consumes: Task 1~6 결과물
- Produces: 없음

- [ ] **Step 1: README 교체**

`iOS/OnDeviceTranslationSample/README.md`:

````markdown
# On-Device Translation Sample (iOS 15.5+)

한국어 문장을 여러 온디바이스 번역 엔진으로 번역해 결과를 나란히 비교하는 샘플 앱입니다.

| 엔진 | 지원 OS | 대상 언어 | 언어팩 |
|---|---|---|---|
| Core ML (opus-mt-ko-en) | iOS 15.5+ | 영어 | 앱에 포함 |
| Apple Translation | iOS 26+ | 영어·베트남어·인도네시아어·일본어·중국어(간체) | 시스템 다운로드 (삭제는 설정 앱) |
| Google ML Kit | iOS 15.5+ | 영어·베트남어·인도네시아어·일본어·중국어(간체) | 앱에서 다운로드/삭제 (언어당 약 30MB) |

## 준비

```bash
brew install xcodegen
gem install cocoapods   # 이미 설치되어 있으면 생략
```

## 서명 설정

```bash
cp Configs/Local.example.xcconfig Configs/Local.xcconfig
```

`Configs/Local.xcconfig`에 본인의 `DEVELOPMENT_TEAM`과 `APP_BUNDLE_ID`를 입력합니다. 이 파일은 커밋되지 않습니다.

## 프로젝트 생성

```bash
./generate.sh
open OnDeviceTranslationSample.xcworkspace
```

파일을 추가·삭제한 뒤에는 `./generate.sh`를 다시 실행하세요. `.xcodeproj`가 아니라 `.xcworkspace`를 열어야 ML Kit이 링크됩니다.

## 실행과 테스트

ML Kit은 Apple Silicon 시뮬레이터 지원에 제약이 있으므로 실제 기기에서 실행합니다.

```bash
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=<기기 UDID>' -allowProvisioningUpdates
```

## 사용법

1. 한국어 문장을 입력하고 대상 언어(EN/VI/ID/JA/ZH)를 고른 뒤 [번역]을 누릅니다.
2. 언어팩이 없는 엔진은 카드에 [다운로드] 버튼이 표시됩니다.
3. 툴바의 [언어팩]에서 엔진별 설치 상태를 보고 받거나 지울 수 있습니다.
````

- [ ] **Step 2: 전체 테스트 재실행**

Run:
```bash
cd iOS/OnDeviceTranslationSample
xcodebuild test -workspace OnDeviceTranslationSample.xcworkspace -scheme OnDeviceTranslationSample -destination 'platform=iOS,id=00008150-000E40492128C01C' -allowProvisioningUpdates -quiet
cd ../OnDeviceTranslationEngine && swift test 2>&1 | grep -E "Executed .* tests"
```
Expected: 앱 `** TEST SUCCEEDED **`, 엔진 `Executed 2 tests, with 0 failures`

- [ ] **Step 3: 커밋 대상 점검**

Run: `cd ../.. && git status --short`
Expected: `README.md`만 변경. `Pods/`, `build/`, `Configs/Local.xcconfig`가 목록에 없어야 한다.

- [ ] **Step 4: Commit**

```bash
git add iOS/OnDeviceTranslationSample/README.md
git commit -m "docs: Update sample app README for XcodeGen, CocoaPods and engine comparison

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

# On-Device Translation Sample (iOS 16.0+)

한국어 문장을 여러 온디바이스 번역 엔진으로 번역해 결과를 나란히 비교하는 샘플 앱입니다.

| 엔진 | 지원 OS | 대상 언어 | 언어팩 |
|---|---|---|---|
| Core ML (opus-mt-ko-en) | iOS 16.0+ | 영어 | 앱에 포함 |
| Apple Translation | iOS 26+ | 영어·베트남어·인도네시아어·일본어·중국어(간체) | 시스템 다운로드 (삭제는 설정 앱) |
| Google ML Kit | iOS 16.0+ | 영어·베트남어·인도네시아어·일본어·중국어(간체) | 앱에서 다운로드/삭제 (언어당 약 30MB) |

최소 버전이 iOS 16.0인 이유: 엔진이 사용하는 `swift-sentencepiece`가 iOS 16 이상을 요구합니다.

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

기기가 서명 팀에 등록되어 있지 않다면 `-allowProvisioningDeviceRegistration`을 함께 넘기면 자동 등록됩니다.

## 사용법

1. 한국어 문장을 입력하거나 [예시글] 메뉴에서 가정통신문·급식·학교공지 예시를 고르고, 대상 언어(EN/VI/ID/JA/ZH)를 고른 뒤 [번역]을 누릅니다.
   예시글은 [예시글] > 예시글 편집…에서 고쳐 저장하거나 기본값으로 되돌릴 수 있습니다.
2. 언어팩이 없는 엔진은 카드에 [다운로드] 버튼이 표시됩니다.
3. 툴바의 [언어팩]에서 엔진별 설치 상태를 보고 받거나 지울 수 있습니다.

## 참고

Core ML 모델은 CPU와 Neural Engine에서만 실행합니다. iOS에서 GPU(MPS)로 실행하면 디코더의 가변 길이 입력 처리에서 크래시가 발생합니다.

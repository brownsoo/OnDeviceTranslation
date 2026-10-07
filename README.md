# On-Device Translation

학교 가정통신문·급식·학교공지 같은 한국어 안내문을 **기기 안에서(오프라인으로)** 다국어로 번역할 수 있는지 검증하는 iOS 프로젝트입니다. 같은 문장을 여러 온디바이스 번역 엔진으로 번역해 나란히 비교하고, 품질을 측정한 결과를 함께 정리했습니다.

- **원문:** 한국어
- **대상 언어:** 영어, 베트남어, 인도네시아어, 일본어, 중국어(간체)
- **최소 버전:** iOS 15.5

## 비교하는 엔진

| 엔진 | 지원 OS | 언어팩 |
|---|---|---|
| Apple Intelligence (`TranslationSession` `.highFidelity`) | iOS 26.4 이상, Apple Intelligence 켜짐 | 필요 없음 (Apple Intelligence에 포함) |
| Apple 기본 모델 (`TranslationSession` `.lowLatency`) | iOS 26.4 이상 | 시스템 다운로드 (설정 앱에서 삭제) |
| Apple Translation (시스템이 모델 선택) | iOS 26.0 ~ 26.3 | 시스템 다운로드 |
| Google ML Kit Translate | iOS 15.5 이상 | 앱에서 다운로드·삭제 (언어당 약 30MB) |

## 샘플 앱

[iOS/OnDeviceTranslationSample](iOS/OnDeviceTranslationSample)은 SwiftUI로 만든 비교 앱입니다.

- 한국어 문장을 입력하고 대상 언어를 고르면, OS에서 쓸 수 있는 엔진들이 동시에 번역해 결과와 걸린 시간을 카드로 보여줍니다.
- **[예시글]** 메뉴에 학교 게시판에서 가져온 가정통신문·급식·학교공지 예시 6개가 들어 있고, 앱에서 고쳐 저장하거나 기본값으로 되돌릴 수 있습니다.
- **[언어팩]** 화면에서 엔진별·언어별 설치 상태를 보고 받거나 지울 수 있습니다. Apple 언어팩은 시스템 동의 창으로 받습니다.
- **전처리**(기본값 켜짐): 번역 전에 한국식 목록 기호 `가.·나.`를 `A.·B.`로, 요일 약자 `(금)`을 `(금요일)`로 바꾸고, 급식의 알레르기 정보(1~19번)는 번역기 대신 미리 번역해 둔 언어별 고정 문구로 넣습니다.

설치와 실행 방법은 [샘플 앱 README](iOS/OnDeviceTranslationSample/README.md)를 참고하세요. 프로젝트는 XcodeGen으로 생성하고 ML Kit은 CocoaPods로 설치하며, ML Kit 때문에 실제 기기에서 실행합니다.

## 번역 품질 측정 결과

예시글 6개를 5개 언어로 번역해 원문과 대조하고, MQM 방식으로 오류를 세어 100점 만점으로 채점했습니다. 구글 번역(웹, 클라우드)은 비교 기준으로 함께 측정했습니다.

| | Apple Intelligence | Apple 기본 모델 | ML Kit | Google 번역 (클라우드) |
|---|---|---|---|---|
| 전처리 전 | 75.5 | 83.8 | 52.2 | 97.7 |
| **전처리 후** | **91.1** | **93.6** | 65.8 | — |
| 평균 번역 시간 | 약 5초 | 약 0.8초 | 약 0.2초 | 측정 안 함 |

- **온디바이스 엔진 중에서는 Apple 기본 모델이 가장 안정적**이고, 전처리를 하면 구글 번역과의 차이가 약 4점까지 줄어듭니다.
- **급식 알레르기 정보는 번역기에 맡기면 안 됩니다.** 전처리 전에는 온디바이스 세 엔진 모두 "난류(달걀)"를 "난기류" 등으로 오역했습니다.
- **Apple Intelligence는 문장형 안내문에 강하지만 급식 메뉴의 식재료를 다른 것으로 바꾸는 경향**이 있습니다(문어→오징어, 바지락→새우 등).
- **ML Kit은 학교명 손실, 날짜 깨짐, 줄바꿈 소실이 잦아** 안내문 번역에는 적합하지 않았습니다.

평가자가 한 명(Claude)이고 표본이 6개뿐인 상대 비교입니다. 서비스에 쓰기 전에는 언어별 원어민 검수가 필요하고, 알레르기 고정 표도 공식 다국어 표기와 대조해야 합니다. 전체 결과와 번역 원문은 [품질 비교 보고서](docs/reports/2026-10-07-translation-quality.html)에 있습니다(내려받아 브라우저로 열어보세요).

## 저장소 구조

```
iOS/OnDeviceTranslationSample/     SwiftUI 비교 앱 (XcodeGen + CocoaPods)
 ├─ Sources/Providers/             엔진 구현 (Apple Translation, ML Kit)
 ├─ Sources/Comparison/            비교 화면과 뷰모델
 ├─ Sources/LanguagePacks/         언어팩 상태 관리와 화면
 ├─ Sources/Preprocessing/         원문 전처리와 알레르기 고정 표
 ├─ Sources/Samples/               예시글과 편집 화면
 └─ Tests/                         단위 테스트 (기기에서 실행)
docs/reports/                      번역 품질 비교 보고서
docs/superpowers/                  설계 문서와 구현 계획
```

## 참고

- 초기에는 Helsinki-NLP `opus-mt-ko-en`을 Core ML로 변환한 엔진(한→영 전용)도 비교했으나 저장소에서 제거했습니다. 변환 스크립트와 모델은 git 히스토리에 남아 있습니다.
- 예시글은 공개 학교 게시판의 안내문에서 URL·전화번호·첨부파일 이름을 뺀 것입니다.

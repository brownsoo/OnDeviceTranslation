# On-Device Translation Sample Application (iOS 15.0+)

This sample SwiftUI application demonstrates how to integrate and run the `OnDeviceTranslationEngine` to perform offline, local Korean-to-English machine translation.

---

## Step-by-Step Xcode Integration Guide

### 1. Create a New Xcode Project
1. Open **Xcode** (v14.0 or newer).
2. Select **File > New > Project...**
3. Choose **iOS > App** and click **Next**.
4. Name the project `OnDeviceTranslationSample`.
5. Select **SwiftUI** for the Interface and **Swift** for the Language.
6. Click **Next** and save the project.

---

### 2. Add the Swift Package Dependency
You can add the translation engine library to your Xcode project as a local dependency:
1. In Xcode, select **File > Add Packages...**
2. Click **Add Local...** at the bottom left.
3. Select the folder `iOS/OnDeviceTranslationEngine/` from this repository.
4. Set the Package Product dependency to your target **OnDeviceTranslationSample** and click **Add Package**.

*(Alternatively, once pushed, you can search for your private GitHub repository URL: `https://github.com/brownsoo/OnDeviceTranslation.git` and add it using your credentials.)*

---

### 3. Add Model and Tokenizer Resources to the App Target
The local translation engine requires the Core ML model packages and vocabulary mappings to be bundled with the app.

1. Locate the following files in this project:
   * **CoreML Models:**
     * `models/encoder.mlpackage`
     * `models/decoder.mlpackage`
   * **Tokenizer Model:**
     * `tokenizer_files/source.spm` (Korean SentencePiece model)
   * **Vocabulary Mappings:**
     * `models/source_id_to_vocab_id.json`
     * `models/target_vocab_id_to_piece.json`
2. **Drag and drop** these 5 files/folders into your Xcode Project Navigator.
3. In the dialog that appears, make sure to choose:
   * [x] **Copy items if needed**
   * [x] **Create groups** (not folder references)
   * [x] **Add to targets:** Check **`OnDeviceTranslationSample`**
4. Click **Finish**.

---

### 4. Replace SwiftUI Source Files
Copy the provided sample files into your project:
* Replace the contents of your Xcode project's `ContentView.swift` with [ContentView.swift](file:///Users/brownsoo/Workspace/OnDeviceTranslation/iOS/OnDeviceTranslationSample/ContentView.swift).
* Replace the contents of your Xcode project's `OnDeviceTranslationSampleApp.swift` with [OnDeviceTranslationSampleApp.swift](file:///Users/brownsoo/Workspace/OnDeviceTranslation/iOS/OnDeviceTranslationSample/OnDeviceTranslationSampleApp.swift).

---

### 5. Build and Run
1. Select an iOS simulator or a connected physical iOS device (iOS 15.0+ or macOS 13.0+ for Mac designed apps).
2. Click **Run** (⌘R).
3. The app will launch, compile the Core ML models on-device, and become ready to translate Korean to English fully offline.

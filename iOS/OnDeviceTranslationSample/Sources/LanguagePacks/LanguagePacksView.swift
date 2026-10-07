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
        .modifier(AppleDownloadHost(store: store, origin: .languagePacks))
    }

    private func row(for language: PackLanguage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(language.displayName).font(.headline)
            if let target = language.targetLanguage {
                ForEach(store.appleKinds, id: \.self) { kind in
                    HStack {
                        Text(store.appleProvider(kind)?.displayName ?? "Apple").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        appleControl(kind, target)
                    }
                }
            } else if store.isAppleAvailable {
                HStack {
                    Text("Apple").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    // Apple language packs are per pair (Korean → target), shown on the target rows.
                    Text("—").foregroundColor(.secondary)
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

    @ViewBuilder
    private func appleControl(_ kind: ProviderKind, _ target: TargetLanguage) -> some View {
        let status = store.isDownloading(kind, target) ? .downloading : store.appleStatus(kind, target)
        if kind == .appleIntelligence && status == .installed {
            // The Apple Intelligence model ships with Apple Intelligence; there is nothing to download.
            Text("Apple Intelligence에 포함").foregroundColor(.secondary)
        } else {
            PackStatusControl(status: status, onDownload: { store.requestAppleDownload(kind, target, origin: .languagePacks) })
        }
    }

    private var footerText: String {
        let mlKitNote = "ML Kit 언어팩은 언어당 약 30MB이며 셀룰러 데이터로도 받습니다."
        return store.isAppleAvailable ? mlKitNote + " Apple 언어팩 삭제는 설정 앱에서 할 수 있습니다." : mlKitNote
    }
}

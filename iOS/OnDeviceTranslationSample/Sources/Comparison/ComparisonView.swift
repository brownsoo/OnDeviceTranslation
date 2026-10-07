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

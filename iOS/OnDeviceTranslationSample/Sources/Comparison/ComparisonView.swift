import SwiftUI

struct ComparisonView: View {
    @ObservedObject var viewModel: ComparisonViewModel
    @ObservedObject var packStore: LanguagePackStore
    @ObservedObject var sampleStore: SampleTextStore
    @State private var activeSheet: Sheet?

    private enum Sheet: String, Identifiable {
        case languagePacks
        case samples

        var id: String { rawValue }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("한국어 (원문)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        sampleMenu
                    }
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

                    Toggle(isOn: $viewModel.usesPreprocessing) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("전처리")
                            Text("목록 기호·요일을 바꾸고 알레르기 정보는 고정 번역을 씁니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

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
                    Button("언어팩") { activeSheet = .languagePacks }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .languagePacks: LanguagePacksView(store: packStore)
                case .samples: SampleTextsView(store: sampleStore)
                }
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
        .modifier(AppleDownloadHost(store: packStore, origin: .comparison))
    }

    private var sampleMenu: some View {
        Menu {
            ForEach(SampleCategory.allCases) { category in
                Section(category.displayName) {
                    ForEach(sampleStore.samples(in: category)) { sample in
                        Button(sample.title) { viewModel.loadSample(sample) }
                    }
                }
            }
            Divider()
            Button {
                activeSheet = .samples
            } label: {
                Label("예시글 편집…", systemImage: "pencil")
            }
        } label: {
            Label("예시글", systemImage: "text.badge.plus")
                .font(.caption)
        }
    }

    private var targetBinding: Binding<TargetLanguage> {
        Binding(get: { viewModel.target }, set: { viewModel.select($0) })
    }
}

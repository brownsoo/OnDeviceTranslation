import SwiftUI

/// Lists the example texts by category; each opens an editor for its body.
struct SampleTextsView: View {
    @ObservedObject var store: SampleTextStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(SampleCategory.allCases) { category in
                    Section(header: Text(category.displayName)) {
                        ForEach(store.samples(in: category)) { sample in
                            NavigationLink {
                                SampleEditView(store: store, sampleID: sample.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sample.title).lineLimit(2)
                                    if store.isEdited(sample.id) {
                                        Text("수정됨").font(.caption).foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("예시글 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct SampleEditView: View {
    @ObservedObject var store: SampleTextStore
    let sampleID: String
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $draft)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            Button("기본값으로 되돌리기", role: .destructive) {
                store.resetToDefault(sampleID)
                draft = store.sample(id: sampleID)?.body ?? ""
            }
            .disabled(!store.isEdited(sampleID))
        }
        .padding()
        .navigationTitle(store.sample(id: sampleID)?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("저장") {
                    store.save(body: draft, for: sampleID)
                    dismiss()
                }
                .disabled(draft == store.sample(id: sampleID)?.body)
            }
        }
        .onAppear { draft = store.sample(id: sampleID)?.body ?? "" }
    }
}

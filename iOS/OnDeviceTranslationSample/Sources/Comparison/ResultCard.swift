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

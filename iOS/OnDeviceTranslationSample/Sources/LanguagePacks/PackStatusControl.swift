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

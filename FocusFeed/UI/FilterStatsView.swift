import SwiftUI

struct FilterStatsView: View {
    let session: BrowserSession
    let onSaveSnapshot: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var savedSnapshot = false

    private func rows(_ counts: [String: Int]) -> [(name: String, count: Int)] {
        counts.sorted { $0.key < $1.key }.map { (name: $0.key, count: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Leaking on this page") {
                    ForEach(rows(session.stats.leaks), id: \.name) { row in
                        LabeledContent(row.name, value: label(for: row.count))
                            .foregroundStyle(row.count == 0 ? Color.primary : Color.red)
                    }
                }
                Section("Hidden on this page") {
                    ForEach(rows(session.stats.hidden), id: \.name) { row in
                        LabeledContent(row.name, value: label(for: row.count))
                    }
                }
                Section {
                    Button(savedSnapshot ? "Snapshot saved" : "Save DOM snapshot") {
                        Task {
                            await onSaveSnapshot()
                            savedSnapshot = true
                        }
                    }
                    .accessibilityIdentifier("saveSnapshot")
                } footer: {
                    Text(session.currentURL?.absoluteString ?? "")
                }
            }
            .navigationTitle("\(session.profile.title) filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func label(for count: Int) -> String {
        count < 0 ? "invalid selector" : String(count)
    }
}

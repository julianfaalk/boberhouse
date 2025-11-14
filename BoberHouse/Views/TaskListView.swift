import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var showingEditor = false
    @State private var editingTemplate: TaskTemplate?

    var body: some View {
        NavigationStack {
            List {
                Section("Active Templates") {
                    ForEach(store.templates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            templateRow(template)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.white.opacity(0.35))
                }
                .accessibilityLabel("Add Task")
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showingEditor) {
                TaskTemplateEditorView()
            }
            .sheet(item: $editingTemplate) { template in
                TaskTemplateEditorView(template: template)
            }
        }
    }

    private func templateRow(_ template: TaskTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.title)
                .font(.headline)

            if let details = template.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Every \(template.cadenceValue) \(template.cadenceUnit.localizedLabel.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)

            if template.leadTimeHours > 0 {
                Text("Remind \(template.leadTimeHours)h before")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TaskListPreview: View {
    @StateObject private var store = HouseholdStore()

    var body: some View {
        TaskListView()
            .environmentObject(store)
            .modelContainer(previewContainer)
            .task {
                await store.attachIfNeeded(modelContext: previewContainer.mainContext)
            }
    }
}

#Preview {
    TaskListPreview()
}

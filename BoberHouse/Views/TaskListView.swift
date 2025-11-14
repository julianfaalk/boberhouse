import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var showingEditor = false
    @State private var editingTemplate: TaskTemplate?
    @StateObject private var viewModel = TaskTemplateListViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Active Templates") {
                    ForEach(viewModel.rows) { row in
                        Button {
                            editingTemplate = store.templates.first(where: { $0.id == row.id })
                        } label: {
                            templateRow(row)
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
        .onAppear(perform: rebuildRows)
        .onChange(of: store.templates) { _ in rebuildRows() }
        .onDisappear(perform: viewModel.cancelWork)
    }

    private func templateRow(_ row: TaskTemplateListViewModel.Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
                .font(.headline)

            if let details = row.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(row.cadenceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lead = row.leadTimeDescription {
                Text(lead)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func rebuildRows() {
        viewModel.rebuild(templates: store.templates)
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

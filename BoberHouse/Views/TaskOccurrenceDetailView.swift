import SwiftData
import SwiftUI

struct TaskOccurrenceDetailView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss

    let occurrence: TaskOccurrence

    @State private var selectedMemberID: UUID?
    @State private var notes: String
    @State private var dueDate: Date

    init(occurrence: TaskOccurrence) {
        self.occurrence = occurrence
        _selectedMemberID = State(initialValue: occurrence.assignedMemberID)
        _notes = State(initialValue: occurrence.notes ?? "")
        _dueDate = State(initialValue: occurrence.dueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    if let template = store.templatesByID[occurrence.templateID] {
                        Text(template.title)
                            .font(.headline)
                    }

                    LabeledContent("Due") {
                        Text(dueDate, style: .date)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Assigned to", selection: $selectedMemberID) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(store.members) { member in
                            Text("\(member.emojiSymbol) \(member.displayName)").tag(UUID?.some(member.id))
                        }
                    }
                }

                Section("Schedule") {
                    DatePicker(
                        "Due date",
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }

                Section("Status") {
                    Button {
                        Task { await store.markOccurrence(occurrence, as: .completed, notes: notes.isEmpty ? nil : notes) }
                    } label: {
                        Label("Mark Complete", systemImage: "checkmark.circle.fill")
                    }

                    Button {
                        Task { await store.markOccurrence(occurrence, as: .skipped, notes: notes.isEmpty ? nil : notes) }
                    } label: {
                        Label("Skip", systemImage: "arrow.uturn.left.circle")
                    }

                    if occurrence.status != .pending {
                        Button {
                            Task { await store.markOccurrence(occurrence, as: .pending) }
                        } label: {
                            Label("Reset to Pending", systemImage: "clock.arrow.2.circlepath")
                        }
                    }
                }
            }
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Changes") {
                        Task {
                            await store.updateDueDate(for: occurrence, to: dueDate)
                            await store.updateNotes(for: occurrence, notes: notes.isEmpty ? nil : notes)
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: selectedMemberID) { newValue in
                Task {
                    let member = newValue.flatMap { store.membersByID[$0] }
                    await store.assign(occurrence, to: member)
                }
            }
            .onChange(of: occurrence.dueDate) { newValue in
                dueDate = newValue
            }
        }
    }
}

private struct TaskOccurrenceDetailPreview: View {
    @StateObject private var store = HouseholdStore()

    var body: some View {
        TaskOccurrenceDetailView(occurrence: store.occurrences.first ?? previewOccurrence())
            .environmentObject(store)
            .modelContainer(previewContainer)
            .task {
                await store.attachIfNeeded(modelContext: previewContainer.mainContext)
            }
    }

    private func previewOccurrence() -> TaskOccurrence {
        let descriptor = FetchDescriptor<TaskOccurrence>()
        if let existing = try? previewContainer.mainContext.fetch(descriptor).first {
            return existing
        }
        fatalError("Missing preview occurrence")
    }
}

#Preview {
    TaskOccurrenceDetailPreview()
}

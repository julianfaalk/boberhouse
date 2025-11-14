import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var showCompleted = false
    @State private var selectedOccurrence: TaskOccurrence?

    private var groupedOccurrences: [(Date, [TaskOccurrence])] {
        let calendar = Calendar.current
        let filtered = store.occurrences.filter { showCompleted || $0.status == .pending }
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.dueDate) }
        return groups
            .map { ($0.key, $0.value.sorted { $0.dueDate < $1.dueDate }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedOccurrences, id: \.0) { day, occurrences in
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(occurrences) { occurrence in
                            occurrenceRow(occurrence)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedOccurrence = occurrence
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $showCompleted) {
                        Text("Completed")
                    }
                    .toggleStyle(.switch)
                }
            }
        }
        .sheet(item: $selectedOccurrence) { occurrence in
            TaskOccurrenceDetailView(occurrence: occurrence)
        }
    }

    private func occurrenceRow(_ occurrence: TaskOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.templatesByID[occurrence.templateID]?.title ?? "Task")
                    .font(.headline)
                Spacer()
                Text(occurrence.dueDate, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let memberID = occurrence.assignedMemberID,
               let member = store.membersByID[memberID] {
                Label(member.displayName, systemImage: "person.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            statusBadge(for: occurrence.status)
        }
        .padding(.vertical, 6)
    }

    private func statusBadge(for status: TaskOccurrenceStatus) -> some View {
        let (label, color, icon): (String, Color, String) = {
            switch status {
            case .pending:
                return ("Pending", .yellow, "clock.badge.exclamationmark")
            case .completed:
                return ("Completed", .green, "checkmark.circle.fill")
            case .skipped:
                return ("Skipped", .orange, "arrow.uturn.backward")
            }
        }()

        return Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct TimelinePreview: View {
    @StateObject private var store = HouseholdStore()

    var body: some View {
        TimelineView()
            .environmentObject(store)
            .modelContainer(previewContainer)
            .task {
                await store.attachIfNeeded(modelContext: previewContainer.mainContext)
            }
    }
}

#Preview {
    TimelinePreview()
}

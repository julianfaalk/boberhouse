import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingTemplateSheet = false
    @State private var selectedOccurrence: TaskOccurrence?

    private var todayOccurrences: [TaskOccurrence] {
        let calendar = Calendar.current
        return store.occurrences
            .filter { occurrence in
                occurrence.status == .pending &&
                calendar.isDate(occurrence.dueDate, inSameDayAs: Date())
            }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var nextOccurrence: TaskOccurrence? {
        todayOccurrences.first
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20, pinnedViews: []) {
                    headerCard

                    if todayOccurrences.isEmpty {
                        emptyState
                    } else {
                        ForEach(todayOccurrences) { occurrence in
                            occurrenceCard(for: occurrence)
                                .onTapGesture {
                                    selectedOccurrence = occurrence
                                }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
            .refreshable {
                await store.refreshSnapshots()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {}
            }
            .safeAreaPadding(.horizontal, 0)
            .background(Color.clear)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingTemplateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                Color.accentColor,
                                Color.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.15)
                            )
                    }
                    .accessibilityLabel("Add Task")
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showingTemplateSheet) {
            TaskTemplateEditorView()
        }
        .sheet(item: $selectedOccurrence) { occurrence in
            TaskOccurrenceDetailView(occurrence: occurrence)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .cardHeaderStyle()
                Text(Date().formatted(.dateTime.weekday(.wide).day().month()))
                    .font(.caption)
                    .foregroundStyle(cardSecondary)
            }
            .padding(.bottom, 8)

            if let nextOccurrence,
               let template = store.templatesByID[nextOccurrence.templateID] {
                VStack(alignment: .leading, spacing: 8) {
                    Text(dueDescription(for: nextOccurrence.dueDate))
                        .font(.headline)
                        .foregroundStyle(cardSecondary)

                    Text(template.title)
                        .font(.title2.bold())
                        .foregroundStyle(cardPrimary)

                    if let assignedID = nextOccurrence.assignedMemberID,
                       let member = store.membersByID[assignedID] {
                        HStack {
                            Text(member.emojiSymbol)
                            Text(member.displayName)
                                .foregroundStyle(cardSecondary)
                        }
                    }

                    if isOverdue(nextOccurrence) {
                        Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else if let relative = relativeDescription(for: nextOccurrence.dueDate) {
                        Text(relative.capitalized)
                            .font(.caption)
                            .foregroundStyle(cardTertiary)
                    }
                }
            } else {
                Text("Nothing due today. Enjoy the calm!")
                    .foregroundStyle(cardSecondary)
            }
        }
        .glassCard()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func occurrenceCard(for occurrence: TaskOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.templatesByID[occurrence.templateID]?.title ?? "Task")
                .font(.headline)
                .foregroundStyle(cardPrimary)

            Text(dueDescription(for: occurrence.dueDate))
                .font(.subheadline)
                .foregroundStyle(cardSecondary)

            if let relative = relativeDescription(for: occurrence.dueDate) {
                Text(relative.capitalized)
                    .font(.caption)
                    .foregroundStyle(cardTertiary)
            }

            if let assignedID = occurrence.assignedMemberID,
               let member = store.membersByID[assignedID] {
                Label {
                    Text(member.displayName)
                        .foregroundStyle(cardPrimary)
                } icon: {
                    Text(member.emojiSymbol)
                }
                .font(.subheadline)
            }

            if isOverdue(occurrence) {
                Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await store.markOccurrence(occurrence, as: .completed)
                    }
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await store.markOccurrence(occurrence, as: .skipped)
                    }
                } label: {
                    Label("Skip", systemImage: "arrow.uturn.left.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .glassCard()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(cardSecondary)
                Text("No tasks due today")
                    .font(.headline)
                    .foregroundStyle(cardPrimary)
            Text("Add a template or adjust schedules to see upcoming tasks here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(cardSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassCard()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardPrimary: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var cardSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : .secondary
    }

    private var cardTertiary: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color.secondary.opacity(0.8)
    }

    private func dueDescription(for date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())

        if calendar.isDateInToday(date) {
            return "Today at \(time)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(time)"
        } else {
            return date.formatted(.dateTime.weekday(.wide).day().month().hour().minute())
        }
    }

    private func relativeDescription(for date: Date) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func isOverdue(_ occurrence: TaskOccurrence) -> Bool {
        occurrence.status == .pending && occurrence.dueDate < Date()
    }
}

private struct DashboardViewPreview: View {
    @StateObject private var store = HouseholdStore()

    var body: some View {
        DashboardView()
            .environmentObject(store)
            .modelContainer(previewContainer)
            .task {
                await store.attachIfNeeded(modelContext: previewContainer.mainContext)
            }
    }
}

#Preview {
    DashboardViewPreview()
}

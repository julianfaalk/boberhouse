import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var showCompleted = false
    @State private var selectedOccurrence: TaskOccurrence?
    @StateObject private var viewModel = TimelineViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 28) {
                    if viewModel.sections.isEmpty {
                        emptyTimelineState
                    } else {
                        ForEach(viewModel.sections) { section in
                            sectionView(for: section)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 32)
            }
            .refreshable {
                await store.refreshSnapshots()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {}
            }
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
        .onDisappear(perform: viewModel.cancelWork)
        .onAppear(perform: rebuildTimeline)
        .onChange(of: store.dataVersion) { _ in rebuildTimeline() }
        .onChange(of: showCompleted) { _ in rebuildTimeline() }
    }

    private var emptyTimelineState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Nothing scheduled yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Add tasks or toggle completed items to review your history.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sectionView(for section: TimelineViewModel.Section) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.headline)
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                timelineRow(row, isLast: index == section.rows.indices.last)
                    .onTapGesture {
                        if let occurrence = store.occurrences.first(where: { $0.id == row.id }) {
                            selectedOccurrence = occurrence
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineRow(_ row: TimelineViewModel.Row, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            timelineMarker(for: row.status, isLast: isLast)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let memberName = row.memberName,
                   let emoji = row.memberEmoji {
                    Label {
                        Text(memberName)
                    } icon: {
                        Text(emoji)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Text(row.statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                statusBadge(for: row.status)
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15))
            )
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
        }
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

    private func timelineMarker(for status: TaskOccurrenceStatus, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(markerColor(for: status))
                .frame(width: 12, height: 12)
            if !isLast {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 2, height: 42)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 20)
    }

    private func markerColor(for status: TaskOccurrenceStatus) -> Color {
        switch status {
        case .pending:
            return .yellow
        case .completed:
            return .green
        case .skipped:
            return .orange
        }
    }

    private func rebuildTimeline() {
        viewModel.rebuild(
            occurrences: store.occurrences,
            templates: store.templates,
            members: store.members,
            includeCompleted: showCompleted
        )
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

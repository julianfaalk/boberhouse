import SwiftUI

struct HouseholdSettingsView: View {
    @EnvironmentObject private var store: HouseholdStore
    @State private var showingAddMember = false
    @State private var editingMember: HouseholdMember?

    var body: some View {
        NavigationStack {
            List {
                Section("Household Members") {
                    ForEach(store.members) { member in
                        Button {
                            editingMember = member
                        } label: {
                            HStack(spacing: 12) {
                                Text(member.emojiSymbol)
                                    .font(.title2)
                                if let color = Color(hex: member.accentColorHex) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 16, height: 16)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(member.displayName)
                                        .font(.headline)
                                    Text(member.isSelf ? "This device" : "Shared member")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Sync Status") {
                    HStack {
                        Label("Last revision", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text("\(SyncStateStore.shared.revision)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Pending tasks", systemImage: "clock")
                        Spacer()
                        Text("\(store.occurrences.filter { $0.status == .pending }.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Household")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddMember = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        Task { await store.performManualSync() }
                    } label: {
                        if store.isSyncing {
                            ProgressView()
                        } else {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isSyncing)
                }
            }
            .sheet(isPresented: $showingAddMember) {
                MemberEditorView()
            }
            .sheet(item: $editingMember) { member in
                MemberEditorView(member: member)
            }
        }
    }
}

private struct HouseholdSettingsPreview: View {
    @StateObject private var store = HouseholdStore()

    var body: some View {
        HouseholdSettingsView()
            .environmentObject(store)
            .modelContainer(previewContainer)
            .task {
                await store.attachIfNeeded(modelContext: previewContainer.mainContext)
            }
    }
}

#Preview {
    HouseholdSettingsPreview()
}

import SwiftUI

struct MemberEditorView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss

    private let member: HouseholdMember?

    @State private var displayName: String
    @State private var emojiSymbol: String
    @State private var accentColorHex: String
    @State private var isSelf: Bool

    private var isNew: Bool { member == nil }
    private var canSave: Bool { !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !emojiSymbol.isEmpty }
    private var normalizedAccentHex: String {
        var value = accentColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.hasPrefix("#") {
            value = "#" + value
        }
        return value
    }

    init(member: HouseholdMember? = nil) {
        self.member = member
        _displayName = State(initialValue: member?.displayName ?? "")
        _emojiSymbol = State(initialValue: member?.emojiSymbol ?? "😀")
        _accentColorHex = State(initialValue: member?.accentColorHex ?? "#5B8DEF")
        _isSelf = State(initialValue: member?.isSelf ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $displayName)
                    TextField("Emoji", text: $emojiSymbol)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 80)
                }

                Section("Accent Color") {
                    TextField("Hex", text: $accentColorHex)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let previewColor = Color(hex: normalizedAccentHex) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(previewColor)
                            .frame(height: 44)
                    }
                }

                Section("Primary Device") {
                    Toggle("This is my device", isOn: $isSelf)
                }
            }
            .navigationTitle(isNew ? "Add Member" : "Edit Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let member {
                                await store.updateMember(
                                    member,
                                    displayName: displayName,
                                    emojiSymbol: emojiSymbol,
                                    accentColorHex: normalizedAccentHex,
                                    isSelf: isSelf
                                )
                            } else {
                                await store.addMember(
                                    displayName: displayName,
                                    emojiSymbol: emojiSymbol,
                                    accentColorHex: normalizedAccentHex,
                                    isSelf: isSelf
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
                if let member {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            Task {
                                await store.removeMember(member)
                                dismiss()
                            }
                        } label: {
                            Text("Remove Member")
                        }
                    }
                }
            }
        }
    }
}

private struct MemberEditorPreview: View {
    @StateObject private var store = HouseholdStore()

    var body: some View {
        MemberEditorView()
            .environmentObject(store)
            .modelContainer(previewContainer)
            .task {
                await store.attachIfNeeded(modelContext: previewContainer.mainContext)
            }
    }
}

#Preview {
    MemberEditorPreview()
}
